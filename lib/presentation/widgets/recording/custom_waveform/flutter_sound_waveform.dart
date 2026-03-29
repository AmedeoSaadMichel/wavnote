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
  // ── NEW ──
  final bool isPaused;
  final Function(int seekBarIndex)? onSeekBarIndexChanged;

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
    // ── NEW ──
    this.isPaused = false,
    this.onSeekBarIndexChanged,
  });

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform> {
  Offset _totalBackDistance = Offset.zero;
  final Offset _dragOffset = Offset.zero;
  double _initialPosition = 0.0;

  @override
  void didUpdateWidget(RecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset scroll position when waveData is cleared (new recording)
    if (widget.waveData.isEmpty && oldWidget.waveData.isNotEmpty) {
      setState(() {
        _totalBackDistance = Offset.zero;
        _initialPosition = 0.0;
      });
    }
  }

  int get _currentSeekBarIndex {
    final halfWidth = widget.size.width / 2;
    final index = ((_totalBackDistance.dx + halfWidth) / widget.spacing).round();
    return index.clamp(0, widget.waveData.isEmpty ? 0 : widget.waveData.length - 1);
  }

  double get _maxScrollDx {
    if (widget.waveData.isEmpty) return 0.0;
    return ((widget.waveData.length - 1) * widget.spacing).toDouble();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.isPaused) return;
    final newDx = (_totalBackDistance.dx - details.delta.dx).clamp(0.0, _maxScrollDx);
    setState(() {
      _totalBackDistance = Offset(newDx, 0);
    });
    widget.onSeekBarIndexChanged?.call(_currentSeekBarIndex);
  }

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

    return GestureDetector(
      onHorizontalDragUpdate: widget.isPaused ? _onHorizontalDragUpdate : null,
      child: Container(
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
              bottomPadding: 0,
              waveCap: StrokeCap.round,
              middleLineColor: widget.middleLineColor,
              middleLineThickness: widget.middleLineThickness,
              totalBackDistance: _totalBackDistance,
              dragOffset: _dragOffset,
              waveThickness: widget.waveThickness,
              pushBack: _onPushBack,
              callPushback: !widget.isPaused,
              extendWaveform: true,
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
            ),
          ),
        ),
      ),
    );
  }
}
