// File: presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart
import 'package:flutter/material.dart';
import 'recorder_wave_painter.dart';

/// Real-time waveform widget driven by amplitude data (0.0–1.0).
///
/// Receives amplitude values from [AudioRecorderService] and renders
/// a scrolling waveform using [CustomRecorderWavePainter].
/// Durante la pausa, supporta il drag orizzontale per scorrere la waveform
/// e notifica l'indice della barra di seek tramite [onSeekBarIndexChanged].
class RecordingWaveform extends StatefulWidget {
  final double amplitude; // Current amplitude (0.0-1.0) from AudioRecorderService
  final List<double> waveData; // Waveform data from parent
  final Size size;
  final Color waveColor;
  final double spacing;
  final double waveThickness;
  final double scaleFactor;
  final bool showMiddleLine;
  final Color middleLineColor;
  final double middleLineThickness;
  final bool showDurationLabel;
  final Duration currentDuration;
  final Shader? gradient;
  final bool isPaused;
  final bool showPlayhead;
  final Function(int seekBarIndex)? onSeekBarIndexChanged;
  /// Versione del seek: incrementata ogni volta che avviene un seek-and-resume.
  /// Quando cambia, la waveform riposiziona l'ultima barra sul playhead.
  final int seekVersion;
  /// Se true, le barre vengono disegnate al centro verticale del canvas
  /// (bottomPadding = size.height/2). Default false → barre in fondo (comportamento
  /// originale usato dalla fullscreen view con Clip.none).
  final bool centerBars;

  const RecordingWaveform({
    super.key,
    required this.amplitude,
    required this.waveData,
    required this.size,
    this.waveColor = Colors.cyan,
    this.spacing = 4.0,
    this.waveThickness = 3.5,
    this.scaleFactor = 80.0,
    this.showMiddleLine = false,
    this.middleLineColor = Colors.white,
    this.middleLineThickness = 1.0,
    this.showDurationLabel = false,
    required this.currentDuration,
    this.gradient,
    this.isPaused = false,
    this.showPlayhead = false,
    this.onSeekBarIndexChanged,
    this.seekVersion = 0,
    this.centerBars = false,
  });

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform> {
  Offset _totalBackDistance = Offset.zero;
  final Offset _dragOffset = Offset.zero;
  double _initialPosition = 0.0;

  @override
  void initState() {
    super.initState();
    // Se la widget viene creata con dati già presenti (es. widget ricreata dopo
    // seek-and-resume, o fullscreen aperta mentre era in pausa/registrazione),
    // posiziona subito l'ultima barra sul playhead invece di partire da sinistra.
    if (widget.waveData.isNotEmpty) {
      final halfWidth = widget.size.width / 2;
      final lastIndex = widget.waveData.length - 1;
      _totalBackDistance = Offset((lastIndex * widget.spacing) - halfWidth, 0);
    }
  }

  @override
  void didUpdateWidget(RecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset scroll position when waveData is cleared (new recording)
    if (widget.waveData.isEmpty && oldWidget.waveData.isNotEmpty) {
      setState(() {
        _totalBackDistance = Offset.zero;
        _initialPosition = 0.0;
      });
      return;
    }

    // Seek-and-resume: riposiziona in modo che l'ultima barra sia sul playhead.
    // seekVersion cambia solo una volta per ogni seek → scatta esattamente una volta.
    if (widget.seekVersion != oldWidget.seekVersion && widget.waveData.isNotEmpty) {
      final halfWidth = widget.size.width / 2;
      final lastIndex = widget.waveData.length - 1;
      setState(() {
        _totalBackDistance = Offset((lastIndex * widget.spacing) - halfWidth, 0);
        _initialPosition = 0.0;
      });
      return;
    }

    // Quando si entra in pausa: centra l'ultima barra sul playhead
    if (widget.isPaused && !oldWidget.isPaused && widget.waveData.isNotEmpty) {
      final halfWidth = widget.size.width / 2;
      final lastIndex = widget.waveData.length - 1;
      setState(() {
        _totalBackDistance = Offset((lastIndex * widget.spacing) - halfWidth, 0);
      });
    }
  }

  int get _currentSeekBarIndex {
    final halfWidth = widget.size.width / 2;
    final index = ((_totalBackDistance.dx + halfWidth) / widget.spacing).round();
    return index.clamp(0, widget.waveData.isEmpty ? 0 : widget.waveData.length - 1);
  }

  // ── Listener handlers (non partecipano alla gesture arena) ──────────────
  // Usare Listener invece di GestureDetector garantisce che i drag verticali
  // del parent (compact/expand sheet) non vengano mai bloccati.
  void _onPointerDown(PointerDownEvent event) {}

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.isPaused) return;
    // Processa solo il delta orizzontale; i movimenti verticali passano
    // al parent GestureDetector senza interferenza (Listener non è nel gesture arena)
    final dx = event.delta.dx;
    if (dx == 0) return;

    final halfWidth = widget.size.width / 2;
    final minDx = -halfWidth;
    final maxDx = widget.waveData.isEmpty
        ? 0.0
        : ((widget.waveData.length - 1) * widget.spacing) - halfWidth;
    final newDx = (_totalBackDistance.dx - dx).clamp(minDx, maxDx);
    setState(() {
      _totalBackDistance = Offset(newDx, 0);
    });
    widget.onSeekBarIndexChanged?.call(_currentSeekBarIndex);
  }

  void _onPointerUp(PointerUpEvent event) {}
  // ─────────────────────────────────────────────────────────────────────────

  /// Called when waveform needs to scroll back (same as audio_waveforms library)
  /// IMPORTANT: Does NOT call setState - the parent widget's setState handles repainting
  void _onPushBack() {
    _initialPosition = 0.0;
    _totalBackDistance = _totalBackDistance + Offset(widget.spacing, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final buildTimestamp = DateTime.now().millisecondsSinceEpoch;
    print('⏱️ [$buildTimestamp] RecordingWaveform.build START: waveData.length = ${widget.waveData.length}, amplitude = ${widget.amplitude.toStringAsFixed(3)}');

    const double playheadExtension = 110.0; // px di estensione sotto la waveform (copre seek label)
    // centerBars=true → barre al centro verticale del canvas (compact view).
    // centerBars=false → barre in fondo (comportamento originale fullscreen).
    final double bottomPadding = widget.centerBars ? widget.size.height / 2 : 0;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
        width: widget.size.width,
        height: widget.size.height,
        color: Colors.transparent,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: CustomRecorderWavePainter(
              waveData: widget.waveData.isEmpty ? [0.0] : widget.waveData,
              waveColor: widget.waveColor,
              showMiddleLine: widget.showMiddleLine,
              spacing: widget.spacing,
              initialPosition: _initialPosition,
              showTop: true,
              showBottom: true,
              bottomPadding: bottomPadding,
              waveCap: StrokeCap.round,
              middleLineColor: widget.middleLineColor,
              middleLineThickness: widget.middleLineThickness,
              totalBackDistance: _totalBackDistance,
              dragOffset: _dragOffset,
              waveThickness: widget.waveThickness,
              pushBack: _onPushBack,
              callPushback: !widget.isPaused,
              extendWaveform: false,
              updateFrequecy: 10.0,
              showHourInDuration: false,
              showDurationLabel: widget.showDurationLabel,
              durationStyle: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              durationLinesColor: Colors.white30,
              durationTextPadding: 10,
              durationLinesHeight: 8,
              labelSpacing: 12,
              gradient: widget.gradient,
              shouldClearLabels: false,
              revertClearLabelCall: () {},
              setCurrentPositionDuration: (int ms) {},
              shouldCalculateScrolledPosition: false,
              scaleFactor: widget.scaleFactor,
              currentlyRecordedDuration: widget.currentDuration,
              isPaused: widget.isPaused,
            ),
          ),
        ),
          ),
          // Linea playhead: visibile solo in fullscreen (showPlayhead: true)
          if (widget.showPlayhead)
          Positioned(
              left: widget.size.width / 2 - 1,
              top: 0,
              child: Container(
                width: 2,
                height: widget.size.height + playheadExtension,
                color: const Color(0xFFFFC107),
              ),
            ),
        ],
      ),
    );
  }
}
