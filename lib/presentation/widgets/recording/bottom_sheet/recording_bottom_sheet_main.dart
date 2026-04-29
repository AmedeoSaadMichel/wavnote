// File: lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart
import 'package:flutter/material.dart';

import 'recording_compact_view.dart';
import 'recording_fullscreen_view.dart';

/// Recording Bottom Sheet Main Container
///
/// This widget displays a draggable bottom sheet for recording audio.
/// Features include:
/// - Compact and fullscreen modes with smooth animated transitions
/// - Real-time waveform visualization during recording
/// - Clean UI with modern design
/// - Integration with BLoC pattern for state management
/// - Proper error handling and user feedback
class RecordingBottomSheet extends StatefulWidget {
  final String? title; // Recording title to display
  final bool isRecording; // Whether a recording is currently in progress
  final bool isPaused; // Whether the recording is paused
  final VoidCallback onToggle; // Callback to start/stop recording
  final Duration elapsed; // Time elapsed since the recording started
  final double
  amplitude; // Current amplitude from AudioRecorderService (0.0-1.0)
  final double width; // Available screen width
  final Function(String)? onTitleChanged; // Callback for title changes
  final VoidCallback? onPause; // Callback for pause action
  final VoidCallback? onDone; // Callback for done action
  final VoidCallback? onChat; // Callback for chat/transcript action
  /// Riprende la registrazione (bottone pupilla in pausa).
  /// Passa seekBarIndex e waveData per supportare auto-stop + seek-and-resume.
  final void Function({
    required int seekBarIndex,
    required List<double> waveData,
  })?
  onResume;

  /// Avvia il playback di anteprima dal seekBarIndex corrente (letto dallo stato BLoC).
  final VoidCallback? onPlayFromPosition;

  /// Ferma il playback di anteprima.
  final VoidCallback? onStopPreview;

  /// True quando il playback di anteprima è attivo.
  final bool isPlayingPreview;
  final Function(int seekBarIndex, List<double> waveData)? onPrepareToOverwrite;
  final Function(int seekBarIndex, List<double> waveData)? onSeekAndResume;

  /// Callback per aggiornare la posizione della seek bar nel BLoC.
  final Function(int seekBarIndex)? onSeekBarIndexChanged;

  /// Dati waveform troncati dopo un seek-and-resume; non-null solo al primo
  /// frame dopo la ripresa da un punto precedente.
  final List<double>? truncatedWaveData;

  /// True quando il BLoC è in stato RecordingStarting (transizione, non collassare).
  final bool isStarting;

  /// True se la registrazione corrente è una sovrascrittura.
  final bool isOverwrite;

  /// seekBarIndex dallo stato BLoC — usato durante il playback preview per
  /// far scorrere la waveform in sincrono con l'audio.
  final int? blocSeekBarIndex;

  /// Waveform completa, usata per inizializzare o ripristinare lo stato.
  final List<double>? fullWaveData;

  /// Campioni ampiezza accumulati dal BLoC per recuperare il pattern quando
  /// Flutter non ridisegna durante il background.
  final List<double> waveformAmplitudeSamples;
  final int waveformAmplitudeSampleCount;

  /// Identificatore univoco della sessione incrementato alla chiusura
  final int sessionCounter;

  const RecordingBottomSheet({
    super.key,
    required this.title,
    required this.isRecording,
    this.isPaused = false,
    this.isStarting = false,
    this.isOverwrite = false,
    required this.onToggle,
    required this.elapsed,
    required this.amplitude,
    required this.width,
    this.onTitleChanged,
    this.onPause,
    this.onDone,
    this.onChat,
    this.onResume,
    this.onPlayFromPosition,
    this.onStopPreview,
    this.isPlayingPreview = false,
    this.onPrepareToOverwrite,
    this.onSeekAndResume,
    this.onSeekBarIndexChanged,
    this.truncatedWaveData,
    this.blocSeekBarIndex,
    this.fullWaveData,
    this.waveformAmplitudeSamples = const [],
    this.waveformAmplitudeSampleCount = 0,
    this.sessionCounter = 0,
  });

  @override
  State<RecordingBottomSheet> createState() => _RecordingBottomSheetState();
}

class _RecordingBottomSheetState extends State<RecordingBottomSheet>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _sheetAnimationController;

  late Animation<double> _pulseAnimation;

  // Bottom sheet drag state
  late double maxHeight; // Max expanded height (set in build)
  late double minHeight; // Compact sheet height — set in build (50% screen)
  double _sheetOffset = 0; // 0 = collapsed, 1 = fully expanded
  double _dragStartY = 0; // Initial Y drag position
  double _startHeight = 0; // Height when drag started

  // Waveform data shared between compact and fullscreen views
  final List<double> _waveData = [];

  /// Indice di segmento per ogni barra (parallelo a _waveData).
  /// 0 = registrazione base, 1..N = overwrite successivi.
  final List<int> _waveSegments = [];

  /// Segmento corrente usato quando si aggiungono nuove barre.
  int _currentSegment = 0;

  /// Contatore monotono di overwrite: non si azzera mai al resume semplice,
  /// così ogni overwrite ottiene un colore unico nel tempo.
  int _overwriteCount = 0;
  static const int _maxWavePoints = 1000;
  int _seekBarIndex = 0;

  /// Incrementato ad ogni seek-and-resume per segnalare a RecordingWaveform
  /// di riposizionare la waveform sulla bacchetta gialla.
  int _seekVersion = 0;

  /// Numero di barre future ancora da sovrascrivere (erosione progressiva).
  /// > 0 dopo un seek-and-resume finché tutte le barre future non sono state
  /// rimpiazzate dalla nuova registrazione, una per ogni tick da 100ms.
  int _futureBarsCount = 0;

  /// Offset in ms da aggiungere a widget.elapsed dopo seek-and-resume (overdub).
  /// Il native engine riparte da 0 per il nuovo segmento, ma la waveform
  /// ha già barre pre-seek. Vale 0 per la registrazione normale e il resume semplice
  /// (il clock nativo emette posizioni cumulative che già includono i segmenti
  /// precedenti — ADR-001).
  int _seekTimeOffsetMs = 0;

  double _currentAmplitude = 0.0;
  final List<double> _pendingAmplitudeSamples = [];
  int _lastConsumedBlocAmplitudeSampleCount = 0;
  static const double _amplitudeFloor = 0.08;
  static const int _catchUpBatchThreshold = 3;
  static const int _maxPendingAmplitudeSamples = 3000;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Pulse animation for record button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Sheet transition animation
    _sheetAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start pulse animation when recording
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RecordingBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset completo dello stato interno quando inizia una nuova sessione (es. dopo aver premuto Done)
    if (widget.sessionCounter != oldWidget.sessionCounter) {
      setState(() {
        _waveData.clear();
        _waveSegments.clear();
        _currentSegment = 0;
        _overwriteCount = 0;
        _futureBarsCount = 0;
        _seekVersion = 0;
        _seekBarIndex = 0;
        _seekTimeOffsetMs = 0;
        _currentAmplitude = 0.0;
        _pendingAmplitudeSamples.clear();
        _lastConsumedBlocAmplitudeSampleCount = 0;
      });
    }

    _queueBlocAmplitudeSamples();

    // Sincronizza _seekBarIndex locale con il BLoC durante il playback preview
    // o quando la seekbar è stata spostata manualmente in pausa
    if ((widget.isPlayingPreview || widget.isPaused) &&
        widget.blocSeekBarIndex != null &&
        widget.blocSeekBarIndex != _seekBarIndex) {
      debugPrint(
        '🎚️ BOTTOM SHEET sync local seek from $_seekBarIndex to bloc=${widget.blocSeekBarIndex} paused=${widget.isPaused} playingPreview=${widget.isPlayingPreview}',
      );
      _seekBarIndex = widget.blocSeekBarIndex!;
    }

    // Detecta seek-and-resume: truncatedWaveData è una reference diversa (NUOVA lista)
    // !identical cattura sia il primo overdub (null→non-null) che i successivi (lista vecchia→lista nuova)
    final isSeekResume =
        widget.truncatedWaveData != null &&
        !identical(widget.truncatedWaveData, oldWidget.truncatedWaveData);

    // Pre-imposta futureBarsCount appena inizia la transizione (isStarting true),
    // PRIMA che truncatedWaveData arrivi. Questo impedisce al painter di considerare
    // le barre future come "registrate" durante RecordingStarting e scatenare
    // pushback multipli che spostano il waveform in avanti.
    if (widget.isStarting && !oldWidget.isStarting) {
      final preCount = _waveData.length - _seekBarIndex - 1;
      if (preCount > 0) {
        setState(() => _futureBarsCount = preCount);
      }
    }

    if (isSeekResume) {
      // Invece di troncare i dati, usiamo la lista _waveData originale.
      // Il BLoC non taglia più i dati d'onda, l'erosione avviene solo visivamente.
      // Usiamo fullWaveData per inizializzare _waveData se disponibile.

      _overwriteCount++;
      _currentSegment = _overwriteCount;

      final targetLength = widget.truncatedWaveData!.length;
      _seekTimeOffsetMs = targetLength * 100;

      setState(() {
        // Se abbiamo fullWaveData, usiamo quella come base
        final fullData = widget.fullWaveData;
        if (fullData != null && fullData.isNotEmpty) {
          _waveData.clear();
          _waveData.addAll(fullData);
          _waveSegments.clear();
          _waveSegments.addAll(List.filled(fullData.length, _currentSegment));
        }

        _futureBarsCount = _waveData.length - targetLength;
        if (_futureBarsCount < 0) _futureBarsCount = 0;
        _seekBarIndex = targetLength > 0 ? targetLength - 1 : 0;

        // Continuazione dalla fine: futureBarsCount==0 significa che il seek era
        // alla fine della waveform, non nel mezzo. Manteniamo il colore corrente.
        if (_futureBarsCount == 0) {
          _overwriteCount--; // Annulla l'incremento fatto prima del setState
          _currentSegment = _waveSegments.isNotEmpty ? _waveSegments.last : 0;
        }
      });
      _currentAmplitude = 0.0;
    }

    // Aggiorna l'ampiezza corrente prima di aggiungere barre.
    if (widget.amplitude != oldWidget.amplitude) {
      _currentAmplitude = widget.amplitude;
    }

    // Crescita waveform push-based (ADR-001): nessun timer Dart.
    // Ad ogni tick del clock nativo, widget.elapsed cambia → aggiungiamo una barra.
    // Il clock nativo emette posizioni cumulative (framesInPreviousSegments inclusi),
    // quindi per il resume semplice _seekTimeOffsetMs rimane 0.
    if (widget.isRecording && widget.elapsed != oldWidget.elapsed) {
      _addWaveformBar();
    }

    // Quando si entra in pausa: le barre future rimanenti diventano barre normali.
    // Esegue una sincronizzazione finale per colmare eventuali tick mancanti
    // tra l'ultimo timer tick e la durata esatta finale restituita dal nativo.
    // Reset seekBarIndex sull'ultima barra registrata + auto-espandi a fullscreen.
    if (widget.isPaused && !oldWidget.isPaused) {
      final finalElapsedMs = widget.elapsed.inMilliseconds + _seekTimeOffsetMs;
      final finalExpectedBars = (finalElapsedMs / 100).floor().clamp(
        0,
        _maxWavePoints,
      );
      final recordedBars = _waveData.length - _futureBarsCount;
      final barsToAdd = finalExpectedBars - recordedBars;

      setState(() {
        if (barsToAdd > 0) {
          final amplitudeSamples = _consumeAmplitudeSamples(
            barsToAdd,
            fallback: _currentAmplitude,
          );
          for (int i = 0; i < barsToAdd; i++) {
            final barAmplitude = amplitudeSamples[i];
            if (_futureBarsCount > 0) {
              final insertAt = _waveData.length - _futureBarsCount;
              _waveData[insertAt] = barAmplitude;
              if (insertAt < _waveSegments.length) {
                _waveSegments[insertAt] = _currentSegment;
              }
              _futureBarsCount--;
            } else {
              _waveData.add(barAmplitude);
              _waveSegments.add(_currentSegment);
            }
          }
        }

        final int remainingFutureBars = _futureBarsCount;
        _futureBarsCount =
            0; // Trasformiamo le barre future in barre registrate definitive

        final int totalExpectedLength = finalExpectedBars + remainingFutureBars;
        if (_waveData.length > totalExpectedLength && totalExpectedLength > 0) {
          _waveData.removeRange(totalExpectedLength, _waveData.length);
          if (_waveSegments.length > totalExpectedLength) {
            _waveSegments.removeRange(
              totalExpectedLength,
              _waveSegments.length,
            );
          }
        }

        // Il playhead deve rimanere alla fine della parte registrata (prima della coda rimanente)
        if (remainingFutureBars > 0) {
          _seekBarIndex = finalExpectedBars > 0 ? finalExpectedBars - 1 : 0;
        } else {
          _seekBarIndex = _waveData.isNotEmpty ? _waveData.length - 1 : 0;
        }
        debugPrint(
          '⏸️ BOTTOM SHEET pause finalize elapsedMs=$finalElapsedMs finalExpectedBars=$finalExpectedBars recordedBars=$recordedBars remainingFutureBars=$remainingFutureBars localSeekBarIndex=$_seekBarIndex waveDataLength=${_waveData.length}',
        );
        _sheetOffset = 1.0;
      });
      _seekTimeOffsetMs = 0;
      _pendingAmplitudeSamples.clear();
      _lastConsumedBlocAmplitudeSampleCount =
          widget.waveformAmplitudeSampleCount;
      _sheetAnimationController.animateTo(1.0);
    }

    // Control pulse animation based on recording state
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();

        // AUTO-COLLAPSE: solo se non in pausa e non in transizione seek-and-resume
        if (!widget.isPaused && !widget.isStarting) {
          setState(() {
            _sheetOffset = 0;
          });
          _sheetAnimationController.animateTo(0);
        }
      }
    }

    // AUTO-COLLAPSE: quando la pausa finisce senza riprendere a registrare
    // Escludi il caso di seek-and-resume (isStarting = true)
    if (widget.isPaused != oldWidget.isPaused &&
        !widget.isPaused &&
        !widget.isRecording &&
        !widget.isStarting) {
      setState(() {
        _sheetOffset = 0;
      });
      _sheetAnimationController.animateTo(0);
    }
  }

  /// Aggiunge/aggiorna barre waveform in risposta a un tick del clock nativo.
  /// Chiamato da didUpdateWidget ogni volta che widget.elapsed cambia durante
  /// la registrazione (ADR-001: push-based, nessun Timer Dart).
  void _addWaveformBar() {
    if (!mounted || !widget.isRecording) return;

    // Dopo seek-and-resume il segmento nativo ricomincia da 0: somma l'offset
    // delle barre pre-seek per ottenere la posizione totale nella timeline.
    // Per registrazione normale e resume semplice _seekTimeOffsetMs == 0
    // (il clock nativo emette posizioni cumulative già corrette).
    final elapsedMs = widget.elapsed.inMilliseconds + _seekTimeOffsetMs;
    final expectedBars = (elapsedMs / 100).floor().clamp(0, _maxWavePoints);
    final amplitude = _currentAmplitude > _amplitudeFloor
        ? _currentAmplitude
        : _amplitudeFloor;
    final waveLengthBefore = _waveData.length;
    final futureBarsBefore = _futureBarsCount;
    final recordedBarsBefore = waveLengthBefore - futureBarsBefore;
    final barsToAddBefore = expectedBars - recordedBarsBefore;
    final isCatchUpBatch = barsToAddBefore >= _catchUpBatchThreshold;
    final pendingSamplesBefore = _pendingAmplitudeSamples.length;
    final shouldTraceWaveData =
        barsToAddBefore.abs() > 2 ||
        futureBarsBefore > 0 ||
        waveLengthBefore % 50 == 0;

    if (shouldTraceWaveData) {
      debugPrint(
        '🌊 WAVEFORM-DATA before elapsedMs=$elapsedMs expectedBars=$expectedBars recordedBars=$recordedBarsBefore barsToAdd=$barsToAddBefore catchUp=$isCatchUpBatch pendingAmp=$pendingSamplesBefore amp=${amplitude.toStringAsFixed(3)} len=$waveLengthBefore future=$futureBarsBefore seekOffset=$_seekTimeOffsetMs segment=$_currentSegment seekBar=$_seekBarIndex paused=${widget.isPaused}',
      );
    }

    setState(() {
      final currentBars = _waveData.length - _futureBarsCount;
      final barsToAdd = expectedBars - currentBars;

      if (barsToAdd > 0) {
        final amplitudeSamples = _consumeAmplitudeSamples(
          barsToAdd,
          fallback: amplitude,
        );
        for (int i = 0; i < barsToAdd; i++) {
          final barAmplitude = amplitudeSamples[i];

          if (_futureBarsCount > 0) {
            final insertAt = _waveData.length - _futureBarsCount;
            _waveData[insertAt] = barAmplitude;
            if (insertAt < _waveSegments.length) {
              _waveSegments[insertAt] = _currentSegment;
            }
            _futureBarsCount--;
          } else {
            _waveData.add(barAmplitude);
            _waveSegments.add(_currentSegment);
            if (_waveData.length > _maxWavePoints) {
              _waveData.removeAt(0);
              _waveSegments.removeAt(0);
            }
          }
        }
      } else if (barsToAdd == 0 && _waveData.isNotEmpty) {
        // Stesso tick, ampiezza aggiornata → aggiorna solo l'ultima barra
        final lastRecordedIndex = _waveData.length - _futureBarsCount - 1;
        if (lastRecordedIndex >= 0) {
          _waveData[lastRecordedIndex] = amplitude;
          if (lastRecordedIndex < _waveSegments.length) {
            _waveSegments[lastRecordedIndex] = _currentSegment;
          }
        }
      }

      if (!widget.isPaused) {
        final recordedCount = _waveData.length - _futureBarsCount;
        _seekBarIndex = recordedCount > 0 ? recordedCount - 1 : 0;
      }
    });

    if (shouldTraceWaveData) {
      debugPrint(
        '🌊 WAVEFORM-DATA after len=${_waveData.length} future=$_futureBarsCount recorded=${_waveData.length - _futureBarsCount} catchUp=$isCatchUpBatch pendingAmp=${_pendingAmplitudeSamples.length} seekBar=$_seekBarIndex lastAmp=${_waveData.isNotEmpty ? _waveData.last.toStringAsFixed(3) : 'n/a'} lastSegment=${_waveSegments.isNotEmpty ? _waveSegments.last : 'n/a'}',
      );
    }
  }

  double _normalizedAmplitude(double rawAmplitude) {
    return rawAmplitude > _amplitudeFloor ? rawAmplitude : _amplitudeFloor;
  }

  void _queuePendingAmplitudeSample(double rawAmplitude) {
    _pendingAmplitudeSamples.add(_normalizedAmplitude(rawAmplitude));
    if (_pendingAmplitudeSamples.length > _maxPendingAmplitudeSamples) {
      final overflow =
          _pendingAmplitudeSamples.length - _maxPendingAmplitudeSamples;
      _pendingAmplitudeSamples.removeRange(0, overflow);
    }
  }

  void _queueBlocAmplitudeSamples() {
    final newSampleCount = widget.waveformAmplitudeSampleCount;
    if (newSampleCount <= _lastConsumedBlocAmplitudeSampleCount) return;

    final samples = widget.waveformAmplitudeSamples;
    if (samples.isEmpty) {
      _lastConsumedBlocAmplitudeSampleCount = newSampleCount;
      return;
    }

    final firstAvailableSampleCount = newSampleCount - samples.length;
    final firstNewIndex =
        (_lastConsumedBlocAmplitudeSampleCount - firstAvailableSampleCount)
            .clamp(0, samples.length);
    final queuedSamples = samples.length - firstNewIndex;
    final pendingSamplesBefore = _pendingAmplitudeSamples.length;

    for (int i = firstNewIndex; i < samples.length; i++) {
      _queuePendingAmplitudeSample(samples[i]);
    }
    if (queuedSamples > 2 || newSampleCount % 25 == 0) {
      debugPrint(
        '🌊 BOTTOM SHEET bloc amp sync '
        'old=$_lastConsumedBlocAmplitudeSampleCount new=$newSampleCount '
        'stored=${samples.length} queued=$queuedSamples '
        'pendingBefore=$pendingSamplesBefore '
        'pendingAfter=${_pendingAmplitudeSamples.length}',
      );
    }
    _lastConsumedBlocAmplitudeSampleCount = newSampleCount;
  }

  List<double> _consumeAmplitudeSamples(int count, {required double fallback}) {
    if (count <= 0) return const [];

    final normalizedFallback = _normalizedAmplitude(fallback);
    if (_pendingAmplitudeSamples.isEmpty) {
      return List<double>.filled(count, normalizedFallback);
    }

    final available = List<double>.of(_pendingAmplitudeSamples);
    _pendingAmplitudeSamples.clear();

    if (available.length == count) {
      return available;
    }

    final samples = <double>[];
    for (int i = 0; i < count; i++) {
      final sourceIndex = (((i + 1) * available.length) / count).ceil() - 1;
      samples.add(available[sourceIndex.clamp(0, available.length - 1)]);
    }
    return samples;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheetAnimationController.dispose();
    super.dispose();
  }

  // Called when drag starts
  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _startHeight = minHeight + (maxHeight - minHeight) * _sheetOffset;
  }

  // Called when user drags vertically; calculates new height and updates offset
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    double delta = _dragStartY - details.globalPosition.dy;
    double newHeight = (_startHeight + delta).clamp(minHeight, maxHeight);
    setState(() {
      _sheetOffset = (newHeight - minHeight) / (maxHeight - minHeight);
    });
  }

  // Called when drag ends; snaps to open or closed based on current position
  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _sheetOffset = _sheetOffset > 0.5 ? 1 : 0;
    });

    // Animate sheet to final position
    _sheetAnimationController.animateTo(_sheetOffset);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    minHeight = screenHeight * 0.5;
    maxHeight = screenHeight * 0.9;

    // Sheet espandibile durante registrazione, pausa o transizione seek-and-resume
    final bool canExpand =
        widget.isRecording || widget.isPaused || widget.isStarting;

    final double currentHeight = canExpand
        ? minHeight +
              (maxHeight - minHeight) * _sheetOffset +
              MediaQuery.of(context).padding.bottom
        : 180 + MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        height: currentHeight,
        child: GestureDetector(
          // In pausa il drag è disabilitato: la sheet resta in fullscreen
          // e non può essere compattata manualmente.
          onVerticalDragStart: (canExpand && !widget.isPaused)
              ? _onVerticalDragStart
              : null,
          onVerticalDragUpdate: (canExpand && !widget.isPaused)
              ? _onVerticalDragUpdate
              : null,
          onVerticalDragEnd: (canExpand && !widget.isPaused)
              ? _onVerticalDragEnd
              : null,
          child: _buildContainer(),
        ),
      ),
    );
  }

  /// Build container with clean design
  Widget _buildContainer() {
    final displayElapsed = widget.isRecording && _seekTimeOffsetMs > 0
        ? Duration(
            milliseconds: widget.elapsed.inMilliseconds + _seekTimeOffsetMs,
          )
        : widget.elapsed;

    // ClipRRect invece di Container con gradient: il bottom sheet condivide
    // lo stesso gradient dello schermo (recording_list_screen). Un gradient
    // separato creava un seam visibile (origini diverse → colori diversi
    // alla giunzione = doppio bordo). ClipRRect ritaglia solo gli angoli.
    // ClipRRect gestisce i bordi arrotondati.
    // Container interno porta il gradient originale (stessi colori dello schermo).
    // Senza shadow il seam tra i due gradient è invisibile → nessun doppio bordo.
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8E2DE2), Color(0xFFDA22FF), Color(0xFFFF4E50)],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: _sheetOffset > 0.7
              ? RecordingFullscreenView(
                  key: const ValueKey('fullscreen'),
                  title: widget.title,
                  elapsed: displayElapsed,
                  isRecording: widget.isRecording,
                  isPaused: widget.isPaused,
                  amplitude: widget.amplitude,
                  waveData: _waveData,
                  waveSegments: _waveSegments,
                  seekVersion: _seekVersion,
                  futureBarsCount: _futureBarsCount,
                  pulseAnimation: _pulseAnimation,
                  onToggle: () {
                    if (widget.isPaused) {
                      widget.onResume?.call(
                        seekBarIndex: _seekBarIndex,
                        waveData: _waveData,
                      );
                    } else {
                      widget.onToggle();
                    }
                  },
                  onPause: widget.onPause,
                  onDone: widget.onDone,
                  onChat: widget.onChat,
                  // Pupil button: riprende la registrazione.
                  // Se il preview è attivo → auto-stop + resume/seek-and-resume.
                  // Se la seekbar è stata spostata indietro → seek-and-resume (trim).
                  // Se è all'ultima barra → resume semplice.
                  onResume:
                      ({
                        required int seekBarIndex,
                        required List<double> waveData,
                      }) {
                        // Usiamo sempre ResumeWithAutoStop che gestisce:
                        // 1. Auto-stop del preview se attivo
                        // 2. Decisone tra resume semplice e seek-and-resume
                        widget.onResume?.call(
                          seekBarIndex: seekBarIndex,
                          waveData: waveData,
                        );
                      },
                  // Play nei controlli: avvia/ferma playback dal playhead
                  onPlay: () {
                    if (widget.isPlayingPreview) {
                      widget.onStopPreview?.call();
                    } else {
                      widget.onPlayFromPosition?.call();
                    }
                  },
                  isPlayingPreview: widget.isPlayingPreview,
                  onSeekBarIndexChanged: (index) {
                    debugPrint(
                      '🎚️ BOTTOM SHEET onSeekBarIndexChanged local=$_seekBarIndex -> $index paused=${widget.isPaused} playingPreview=${widget.isPlayingPreview}',
                    );
                    setState(() => _seekBarIndex = index);
                    widget.onSeekBarIndexChanged?.call(index);
                  },
                  seekBarIndex: _seekBarIndex,
                  blocSeekBarIndex: widget.isPlayingPreview
                      ? widget.blocSeekBarIndex
                      : null,
                  sessionCounter: widget.sessionCounter,
                )
              : RecordingCompactView(
                  key: ValueKey(widget.sessionCounter),
                  title: widget.title,
                  elapsed: displayElapsed,
                  isRecording: widget.isRecording,
                  amplitude: widget.amplitude,
                  waveData: _waveData,
                  waveSegments: _waveSegments,
                  pulseAnimation: _pulseAnimation,
                  sessionCounter: widget.sessionCounter,
                  onToggle: () {
                    if (widget.isPaused) {
                      widget.onResume?.call(
                        seekBarIndex: _seekBarIndex,
                        waveData: _waveData,
                      );
                    } else {
                      widget.onToggle();
                    }
                  },
                ),
        ),
      ),
    );
  }
}
