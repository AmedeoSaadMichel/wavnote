// File: presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart
import 'package:flutter/material.dart';
import 'recorder_wave_painter.dart';

/// Real-time waveform widget driven by amplitude data (0.0–1.0).
///
/// Receives amplitude values from [AudioRecorderService] and renders
/// a scrolling waveform using [CustomRecorderWavePainter].
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
  });

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform> {
  // Scrolling offset for waveform (same as audio_waveforms library)
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

  @override
  Widget build(BuildContext context) {
    final buildTimestamp = DateTime.now().millisecondsSinceEpoch;
    print('⏱️ [$buildTimestamp] RecordingWaveform.build START: waveData.length = ${widget.waveData.length}, amplitude = ${widget.amplitude.toStringAsFixed(3)}');

    return Container(
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
            callPushback: true,
            extendWaveform: true,
            updateFrequecy: 10.0, // Update every 10 samples (0.5 second at 50ms intervals)
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
    );
  }

  /// Called when waveform needs to scroll back (same as audio_waveforms library)
  /// IMPORTANT: Does NOT call setState - the parent widget's setState handles repainting
  void _onPushBack() {
    print('🔄 _onPushBack called: incrementing _totalBackDistance by ${widget.spacing}');

    // Just update values without setState (same as original audio_waveforms library)
    // The parent's setState (from _addWavePoint) will trigger the repaint
    _initialPosition = 0.0;
    _totalBackDistance = _totalBackDistance + Offset(widget.spacing, 0.0);

    print('🔄 New _totalBackDistance = $_totalBackDistance');
  }
}
