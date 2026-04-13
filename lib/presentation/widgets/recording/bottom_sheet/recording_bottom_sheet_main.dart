// File: presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart
import 'dart:async';
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
  final VoidCallback? onResume;

  /// Avvia il playback di anteprima dal seekBarIndex corrente (letto dallo stato BLoC).
  final VoidCallback? onPlayFromPosition;

  /// Ferma il playback di anteprima.
  final VoidCallback? onStopPreview;

  /// True quando il playback di anteprima è attivo.
  final bool isPlayingPreview;
  final VoidCallback? onRewind; // Callback for rewind action
  final VoidCallback? onForward; // Callback for forward action
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
    this.onRewind,
    this.onForward,
    this.onPrepareToOverwrite,
    this.onSeekAndResume,
    this.onSeekBarIndexChanged,
    this.truncatedWaveData,
    this.blocSeekBarIndex,
    this.fullWaveData,
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

  /// Offset in ms da aggiungere a widget.elapsed dopo seek-and-resume.
  /// Il native engine riparte da 0, ma la waveform ha già barre pre-seek.
  int _seekTimeOffsetMs = 0;

  /// True al primo tick del timer dopo ogni avvio/ripresa della registrazione.
  /// Al primo tick ricalibra _seekTimeOffsetMs per compensare il ritardo tra
  /// avvio engine nativo e ricezione dell'evento BLoC (tipicamente 200-300ms).
  bool _needsCalibration = false;

  // Timer locale per aggiungere barre alla waveform a intervalli fissi.
  // Disaccoppia la crescita della waveform dagli emit BLoC (che Equatable
  // può saltare durante il silenzio → gap visivi).
  Timer? _waveformTimer;
  double _currentAmplitude = 0.0;
  static const double _amplitudeFloor = 0.08;
  static const Duration _waveformTickInterval = Duration(milliseconds: 100);

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

  /// Avvia il timer locale che sincronizza la waveform al tempo reale.
  /// Ad ogni tick calcola quante barre dovrebbero esserci basandosi su
  /// widget.elapsed e recupera eventuali tick persi (jank).
  void _startWaveformTimer() {
    _waveformTimer?.cancel();
    _currentAmplitude = 0.0;
    print(
      '⏱️ [DART] _startWaveformTimer: START — waveData.length=${_waveData.length} ts=${DateTime.now().millisecondsSinceEpoch}',
    );
    _needsCalibration = true;
    _waveformTimer = Timer.periodic(_waveformTickInterval, (_) {
      _syncWaveformToElapsedTime();
    });
  }

  void _stopWaveformTimer() {
    print(
      '⏱️ [DART] _stopWaveformTimer: STOP — waveData.length=${_waveData.length} ts=${DateTime.now().millisecondsSinceEpoch}',
    );
    _waveformTimer?.cancel();
    _waveformTimer = null;
  }

  @override
  void didUpdateWidget(RecordingBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sincronizza _seekBarIndex locale con il BLoC durante il playback preview
    // o quando la seekbar è stata spostata manualmente in pausa
    if ((widget.isPlayingPreview || widget.isPaused) &&
        widget.blocSeekBarIndex != null &&
        widget.blocSeekBarIndex != _seekBarIndex) {
      _seekBarIndex = widget.blocSeekBarIndex!;
    }

    // Detecta seek-and-resume: truncatedWaveData passa da null → non-null
    // (il RecordingStarting intermedio mantiene null, RecordingInProgress post-seek ha i dati)
    final isSeekResume =
        widget.truncatedWaveData != null && oldWidget.truncatedWaveData == null;

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
      });
      _currentAmplitude = 0.0;
    }

    // Aggiorna l'ampiezza corrente — il timer la usa per le barre successive.
    if (widget.amplitude != oldWidget.amplitude) {
      _currentAmplitude = widget.amplitude;
    }

    // Avvia/ferma il timer waveform in base allo stato di registrazione.
    // Il timer è l'unico punto che chiama _addWavePoint: garantisce barre
    // a intervalli fissi (100ms) indipendentemente dagli emit BLoC.
    if (widget.isRecording && !oldWidget.isRecording) {
      // Resume semplice (da pausa, senza seek): l'engine nativo riparte da 0
      // ma la waveform ha già _waveData.length barre. Imposta l'offset
      // PRIMA di avviare il timer per evitare il freeze della waveform.
      // Il segmento corrente NON viene azzerato: la registrazione riprende
      // con lo stesso colore (segmento) del tratto precedente, come da specifiche.
      if (oldWidget.isPaused && !isSeekResume) {
        _seekTimeOffsetMs = _waveData.length * 100;
        // _currentSegment = 0; RIMOSSO: Deve mantenere il segmento corrente (Caso A)
      }
      _startWaveformTimer();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _stopWaveformTimer();
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
          for (int i = 0; i < barsToAdd; i++) {
            if (_futureBarsCount > 0) {
              final insertAt = _waveData.length - _futureBarsCount;
              _waveData[insertAt] = _amplitudeFloor;
              if (insertAt < _waveSegments.length) {
                _waveSegments[insertAt] = _currentSegment;
              }
              _futureBarsCount--;
            } else {
              _waveData.add(_amplitudeFloor);
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
        _sheetOffset = 1.0;
      });
      _seekTimeOffsetMs = 0;
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

  /// Sincronizza la waveform al tempo reale della registrazione.
  /// Calcola quante barre dovrebbero esserci in base a widget.elapsed
  /// e aggiunge/recupera eventuali barre perse per jank.
  void _syncWaveformToElapsedTime() {
    if (!mounted || !widget.isRecording) return;

    // Calibrazione al primo tick: ricalcola _seekTimeOffsetMs in modo che
    // expectedBars == _waveData.length. Compensa il gap tra avvio engine
    // nativo e primo evento BLoC (di solito 200–300 ms), che altrimenti
    // farebbe scattare 2–3 barre extra al primo sync.
    if (_needsCalibration) {
      _needsCalibration = false;
      // Il calcolo originale usava _waveData.length, che include anche le barre
      // future (ancora da registrare) dopo un seek-and-resume, causando un
      // offset errato enorme che sovrascriveva istantaneamente tutto il futuro.
      // Dobbiamo usare solo le barre attualmente registrate.
      final currentRecordedBars = _waveData.length - _futureBarsCount;
      _seekTimeOffsetMs =
          currentRecordedBars * 100 - widget.elapsed.inMilliseconds;
      print(
        '⏱️ [DART] _syncWaveform CALIBRATION: currentRecordedBars=$currentRecordedBars, future=$_futureBarsCount, elapsed=${widget.elapsed.inMilliseconds}ms → _seekTimeOffsetMs=$_seekTimeOffsetMs',
      );
    }

    // Dopo seek-and-resume il native engine riparte da 0, ma la waveform
    // ha già _seekTimeOffsetMs di barre pre-seek. Somma l'offset per
    // ottenere il numero totale di barre attese.
    final elapsedMs = widget.elapsed.inMilliseconds + _seekTimeOffsetMs;
    final expectedBars = (elapsedMs / 100).floor().clamp(0, _maxWavePoints);
    final amplitude = _currentAmplitude > _amplitudeFloor
        ? _currentAmplitude
        : _amplitudeFloor;

    setState(() {
      // Conta solo le barre effettivamente registrate (esclude le future)
      final currentBars = _waveData.length - _futureBarsCount;
      final barsToAdd = expectedBars - currentBars;

      if (barsToAdd > 0) {
        for (int i = 0; i < barsToAdd; i++) {
          if (_futureBarsCount > 0) {
            final insertAt = _waveData.length - _futureBarsCount;
            _waveData[insertAt] = amplitude;
            if (insertAt < _waveSegments.length) {
              _waveSegments[insertAt] = _currentSegment;
            }
            _futureBarsCount--;
          } else {
            _waveData.add(amplitude);
            _waveSegments.add(_currentSegment);
            if (_waveData.length > _maxWavePoints) {
              _waveData.removeAt(0);
              _waveSegments.removeAt(0);
            }
          }
        }
      } else if (barsToAdd == 0 && _waveData.isNotEmpty) {
        // Aggiorna solo l'ampiezza dell'ultima barra (il segmento non cambia)
        final lastRecordedIndex = _waveData.length - _futureBarsCount - 1;
        if (lastRecordedIndex >= 0) {
          _waveData[lastRecordedIndex] = amplitude;
          if (lastRecordedIndex < _waveSegments.length) {
            // Segmento immutato per le barre già acquisite o aggiornato se necessario
            _waveSegments[lastRecordedIndex] = _currentSegment;
          }
        }
      }

      // seekBarIndex = ultima barra registrata (esclude future)
      if (!widget.isPaused) {
        final recordedCount = _waveData.length - _futureBarsCount;
        _seekBarIndex = recordedCount > 0 ? recordedCount - 1 : 0;
      }

      if (_waveData.length % 5 == 0) {
        print(
          '⏱️ [${DateTime.now().millisecondsSinceEpoch}] _syncWaveform: expected=$expectedBars, actual=${_waveData.length}, future=$_futureBarsCount, amp=${amplitude.toStringAsFixed(3)}',
        );
      }
    });
  }

  @override
  void dispose() {
    _stopWaveformTimer();
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
                  elapsed: widget.elapsed,
                  isRecording: widget.isRecording,
                  isPaused: widget.isPaused,
                  amplitude: widget.amplitude,
                  waveData: _waveData,
                  waveSegments: _waveSegments,
                  seekVersion: _seekVersion,
                  futureBarsCount: _futureBarsCount,
                  pulseAnimation: _pulseAnimation,
                  onToggle: widget.onToggle,
                  onPause: widget.onPause,
                  onDone: widget.onDone,
                  onChat: widget.onChat,
                  // Pupil button: riprende la registrazione.
                  // Se la seekbar è stata spostata indietro → seek-and-resume (trim).
                  // Se è all'ultima barra → resume semplice.
                  onResume: () {
                    // Tolleranza di 1 barra (100ms) per la fine:
                    // Se siamo sull'ultima o penultima barra (o se waveData è vuoto),
                    // è considerata la fine della registrazione.
                    final isAtEnd =
                        _waveData.isEmpty ||
                        _seekBarIndex >= _waveData.length - 2;
                    if (isAtEnd) {
                      widget.onResume?.call();
                    } else {
                      widget.onPrepareToOverwrite?.call(
                        _seekBarIndex,
                        List<double>.from(_waveData),
                      );
                    }
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
                  onRewind: widget.onRewind,
                  onForward: widget.onForward,
                  onSeekBarIndexChanged: (index) {
                    setState(() => _seekBarIndex = index);
                    widget.onSeekBarIndexChanged?.call(index);
                  },
                  seekBarIndex: _seekBarIndex,
                  blocSeekBarIndex: widget.isPlayingPreview
                      ? widget.blocSeekBarIndex
                      : null,
                )
              : RecordingCompactView(
                  key: const ValueKey('compact'),
                  title: widget.title,
                  elapsed: widget.elapsed,
                  isRecording: widget.isRecording,
                  amplitude: widget.amplitude,
                  waveData: _waveData,
                  waveSegments: _waveSegments,
                  pulseAnimation: _pulseAnimation,
                  onToggle: widget.onToggle,
                ),
        ),
      ),
    );
  }
}
