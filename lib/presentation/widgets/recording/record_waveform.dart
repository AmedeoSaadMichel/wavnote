// File: presentation/widgets/recording/record_waveform.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Compact waveform widget for recording visualization
///
/// Shows real-time amplitude visualization during recording
/// with the same visual theme as the rest of the app.
class RecordWaveform extends StatefulWidget {
  final String filePath;
  final double amplitude;
  final bool isRecording;

  const RecordWaveform({
    super.key,
    required this.filePath,
    this.amplitude = 0.0,
    this.isRecording = true, // Default to true when widget is used
  });

  @override
  State<RecordWaveform> createState() => _RecordWaveformState();
}

class _RecordWaveformState extends State<RecordWaveform>
    with TickerProviderStateMixin {

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<double> _amplitudeHistory = [];
  final int _maxBars = 50;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Always start animation since this widget is shown when recording
    _pulseController.repeat(reverse: true);
    _generateRandomAmplitudes(); // Generate some demo amplitude data
  }

  @override
  void didUpdateWidget(RecordWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update amplitude history
    if (widget.amplitude != oldWidget.amplitude) {
      setState(() {
        _amplitudeHistory.add(widget.amplitude);
        if (_amplitudeHistory.length > _maxBars) {
          _amplitudeHistory.removeAt(0);
        }
      });
    }

    // Control pulse animation
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Generate random amplitudes for demo (replace with real audio data)
  void _generateRandomAmplitudes() {
    if (!mounted) return;

    // Generate random amplitude data for visualization
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && widget.isRecording) {
        setState(() {
          final randomAmplitude = math.Random().nextDouble() * 0.8 + 0.2;
          _amplitudeHistory.add(randomAmplitude);
          if (_amplitudeHistory.length > _maxBars) {
            _amplitudeHistory.removeAt(0);
          }
        });
        _generateRandomAmplitudes(); // Continue generating
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _buildWaveformBars(),
      ),
    );
  }

  /// Build animated waveform bars
  List<Widget> _buildWaveformBars() {
    if (_amplitudeHistory.isEmpty) {
      // Show animated bars even when no real data
      return List.generate(30, (index) {
        final amplitude = 0.3 + (math.sin(index * 0.5) * 0.4).abs();
        return _buildWaveformBar(amplitude, index, true);
      });
    }

    return _amplitudeHistory.asMap().entries.map((entry) {
      final int index = entry.key;
      final double amplitude = entry.value;
      final bool isActive = index >= _amplitudeHistory.length - 5;

      return _buildWaveformBar(amplitude, index, isActive);
    }).toList();
  }

  /// Build individual waveform bar
  Widget _buildWaveformBar(double amplitude, int index, bool isActive) {
    final height = math.max(4.0, amplitude * 50.0);
    final random = math.Random(index);
    final baseColor = isActive && widget.isRecording
        ? Colors.red
        : Colors.grey.withValues(alpha: 0.6);

    // Add some randomness for visual appeal
    final randomHeight = height + (random.nextDouble() - 0.5) * 10;
    final finalHeight = math.max(4.0, randomHeight);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = isActive && widget.isRecording
            ? _pulseAnimation.value
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 3,
            height: finalHeight,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(1.5),
              gradient: isActive && widget.isRecording
                  ? LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.red,
                  Colors.red.withValues(alpha: 0.7),
                  Colors.pink.withValues(alpha: 0.5),
                ],
              )
                  : null,
            ),
          ),
        );
      },
    );
  }
}