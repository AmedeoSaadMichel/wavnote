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
  final String? filePath; // Path to the file being recorded
  final bool isRecording; // Whether a recording is currently in progress
  final bool isPaused; // Whether the recording is paused
  final VoidCallback onToggle; // Callback to start/stop recording
  final Duration elapsed; // Time elapsed since the recording started
  final double amplitude; // Current amplitude from AudioRecorderService (0.0-1.0)
  final double width; // Available screen width
  final Function(String)? onTitleChanged; // Callback for title changes
  final VoidCallback? onPause; // Callback for pause action
  final VoidCallback? onDone; // Callback for done action
  final VoidCallback? onChat; // Callback for chat/transcript action
  final VoidCallback? onPlay; // Callback for play action
  final VoidCallback? onRewind; // Callback for rewind action
  final VoidCallback? onForward; // Callback for forward action
  final Function(int seekBarIndex, List<double> waveData)? onSeekAndResume;
  /// Dati waveform troncati dopo un seek-and-resume; non-null solo al primo
  /// frame dopo la ripresa da un punto precedente.
  final List<double>? truncatedWaveData;
  /// True quando il BLoC è in stato RecordingStarting (transizione, non collassare).
  final bool isStarting;

  const RecordingBottomSheet({
    super.key,
    required this.title,
    required this.filePath,
    required this.isRecording,
    this.isPaused = false,
    this.isStarting = false,
    required this.onToggle,
    required this.elapsed,
    required this.amplitude,
    required this.width,
    this.onTitleChanged,
    this.onPause,
    this.onDone,
    this.onChat,
    this.onPlay,
    this.onRewind,
    this.onForward,
    this.onSeekAndResume,
    this.truncatedWaveData,
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
  final double minHeight = 400; // Compact sheet height
  double _sheetOffset = 0; // 0 = collapsed, 1 = fully expanded
  double _dragStartY = 0; // Initial Y drag position
  double _startHeight = 0; // Height when drag started

  // Waveform data shared between compact and fullscreen views
  final List<double> _waveData = [];
  static const int _maxWavePoints = 1000;
  int _seekBarIndex = 0;
  /// Incrementato ad ogni seek-and-resume per segnalare a RecordingWaveform
  /// di riposizionare la waveform sulla bacchetta gialla.
  int _seekVersion = 0;

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
      duration: const Duration(milliseconds: 300),
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

  /// Avvia il timer locale che aggiunge barre alla waveform ogni 100ms.
  /// Usa _currentAmplitude (aggiornata dai props) con un floor minimo per
  /// garantire barre visibili anche durante il silenzio.
  void _startWaveformTimer() {
    _waveformTimer?.cancel();
    _currentAmplitude = 0.0;
    _waveformTimer = Timer.periodic(_waveformTickInterval, (_) {
      if (!mounted || !widget.isRecording) return;
      final amplitude = _currentAmplitude > _amplitudeFloor
          ? _currentAmplitude
          : _amplitudeFloor;
      _addWavePoint(amplitude, DateTime.now().millisecondsSinceEpoch);
    });
  }

  void _stopWaveformTimer() {
    _waveformTimer?.cancel();
    _waveformTimer = null;
  }

  @override
  void didUpdateWidget(RecordingBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detecta seek-and-resume: truncatedWaveData passa da null → non-null
    // (il RecordingStarting intermedio mantiene null, RecordingInProgress post-seek ha i dati)
    final isSeekResume = widget.truncatedWaveData != null &&
        oldWidget.truncatedWaveData == null;

    if (isSeekResume) {
      // Seek-and-resume: rimpiazza _waveData con i dati troncati e segnala
      // a RecordingWaveform di riposizionare la waveform sulla bacchetta.
      // Applica floor su tutte le barre troncate per eliminare i gap visivi.
      setState(() {
        _waveData
          ..clear()
          ..addAll(widget.truncatedWaveData!
              .map((a) => a > _amplitudeFloor ? a : _amplitudeFloor));
        _seekBarIndex = 0;
        _seekVersion++;
      });
      _currentAmplitude = 0.0; // reset per il nuovo segmento
    }

    // Aggiorna l'ampiezza corrente — il timer la usa per le barre successive.
    if (widget.amplitude != oldWidget.amplitude) {
      _currentAmplitude = widget.amplitude;
    }

    // Avvia/ferma il timer waveform in base allo stato di registrazione.
    // Il timer è l'unico punto che chiama _addWavePoint: garantisce barre
    // a intervalli fissi (100ms) indipendentemente dagli emit BLoC.
    if (widget.isRecording && !oldWidget.isRecording) {
      _startWaveformTimer();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _stopWaveformTimer();
    }

    // Clear waveform data when starting a NEW recording from scratch (non seek-and-resume)
    if (widget.isRecording && !oldWidget.isRecording && !oldWidget.isPaused && !isSeekResume) {
      setState(() {
        _waveData.clear();
        _seekBarIndex = 0;
      });
    }

    // Quando si entra in pausa: reset seekBarIndex + auto-espandi a fullscreen
    // così l'utente vede subito la waveform per il seek.
    if (widget.isPaused && !oldWidget.isPaused) {
      setState(() {
        _seekBarIndex = _waveData.isEmpty ? 0 : _waveData.length - 1;
        _sheetOffset = 1.0;
      });
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

  /// Add waveform data point
  void _addWavePoint(double amplitude, int receiveTimestamp) {
    final setStateTimestamp = DateTime.now().millisecondsSinceEpoch;
    final delay = setStateTimestamp - receiveTimestamp;

    setState(() {
      _waveData.add(amplitude);

      // Limit memory usage
      if (_waveData.length > _maxWavePoints) {
        _waveData.removeAt(0);
      }

      // Debug log with timing
      if (_waveData.length % 5 == 0) {
        final afterSetStateTimestamp = DateTime.now().millisecondsSinceEpoch;
        final setStateDelay = afterSetStateTimestamp - setStateTimestamp;
        print('⏱️ [$afterSetStateTimestamp] _addWavePoint: length=${_waveData.length}, amplitude=${amplitude.toStringAsFixed(3)}, delay=${delay}ms, setState=${setStateDelay}ms');
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
    maxHeight = MediaQuery.of(context).size.height * 0.9;

    // Sheet espandibile durante registrazione, pausa o transizione seek-and-resume
    final bool canExpand = widget.isRecording || widget.isPaused || widget.isStarting;

    final double currentHeight = canExpand
        ? minHeight + (maxHeight - minHeight) * _sheetOffset + MediaQuery.of(context).padding.bottom
        : 180 + MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: currentHeight,
        child: GestureDetector(
          // In pausa il drag è disabilitato: la sheet resta in fullscreen
          // e non può essere compattata manualmente.
          onVerticalDragStart: (canExpand && !widget.isPaused) ? _onVerticalDragStart : null,
          onVerticalDragUpdate: (canExpand && !widget.isPaused) ? _onVerticalDragUpdate : null,
          onVerticalDragEnd: (canExpand && !widget.isPaused) ? _onVerticalDragEnd : null,
          child: _buildContainer(),
        ),
      ),
    );
  }

  /// Build container with clean design
  Widget _buildContainer() {
    return Container(
      width: double.infinity,
      // Add bottom padding to extend beyond safe area
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8E2DE2), // Main screen purple
            Color(0xFFDA22FF), // Main screen magenta
            Color(0xFFFF4E50), // Main screen coral
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
        ),
        child: _sheetOffset > 0.7
            ? RecordingFullscreenView(
                key: const ValueKey('fullscreen'),
                title: widget.title,
                elapsed: widget.elapsed,
                isRecording: widget.isRecording,
                isPaused: widget.isPaused,
                filePath: widget.filePath,
                amplitude: widget.amplitude,
                waveData: _waveData,
                seekVersion: _seekVersion,
                onToggle: widget.onToggle,
                onPause: widget.onPause,
                onDone: widget.onDone,
                onChat: widget.onChat,
                onPlay: () {
                  final lastBarIndex = _waveData.isEmpty ? 0 : _waveData.length - 1;
                  if (widget.isPaused && _seekBarIndex < lastBarIndex) {
                    widget.onSeekAndResume?.call(_seekBarIndex, List<double>.from(_waveData));
                  } else {
                    widget.onPlay?.call();
                  }
                },
                onRewind: widget.onRewind,
                onForward: widget.onForward,
                onSeekBarIndexChanged: (index) {
                  setState(() => _seekBarIndex = index);
                },
                seekBarIndex: _seekBarIndex,
              )
            : RecordingCompactView(
                key: const ValueKey('compact'),
                title: widget.title,
                elapsed: widget.elapsed,
                isRecording: widget.isRecording,
                filePath: widget.filePath,
                amplitude: widget.amplitude,
                waveData: _waveData,
                pulseAnimation: _pulseAnimation,
                onToggle: widget.onToggle,
              ),
      ),
    );
  }
}