// File: presentation/widgets/recording/fullscreen_waveform.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Fullscreen waveform widget for expanded recording view
///
/// Shows a larger, more detailed real-time amplitude visualization
/// with the same visual theme as the rest of the app.
class FullScreenWaveform extends StatefulWidget {
  final String? filePath;
  final double amplitude;
  final bool isRecording;

  const FullScreenWaveform({
    super.key,
    this.filePath,
    this.amplitude = 0.0,
    this.isRecording = false,
  });

  @override
  State<FullScreenWaveform> createState() => _FullScreenWaveformState();
}

class _FullScreenWaveformState extends State<FullScreenWaveform>
    with TickerProviderStateMixin {

  late AnimationController _pulseController;
  late AnimationController _flowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _flowAnimation;

  final List<double> _amplitudeHistory = [];
  final int _maxBars = 100;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _flowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _flowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flowController,
      curve: Curves.linear,
    ));

    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
      _flowController.repeat();
    }
  }

  @override
  void didUpdateWidget(FullScreenWaveform oldWidget) {
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

    // Control animations
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
        _flowController.repeat();
      } else {
        _pulseController.stop();
        _flowController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Main waveform display
          Expanded(
            flex: 3,
            child: _buildMainWaveform(),
          ),

          const SizedBox(height: 16),

          // Secondary amplitude bars
          Expanded(
            flex: 1,
            child: _buildSecondaryWaveform(),
          ),
        ],
      ),
    );
  }

  /// Build main large waveform display
  Widget _buildMainWaveform() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _flowAnimation]),
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: MainWaveformPainter(
            amplitudeHistory: _amplitudeHistory,
            currentAmplitude: widget.amplitude,
            isRecording: widget.isRecording,
            pulseValue: _pulseAnimation.value,
            flowValue: _flowAnimation.value,
          ),
        );
      },
    );
  }

  /// Build secondary smaller waveform bars
  Widget _buildSecondaryWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _buildSecondaryBars(),
    );
  }

  /// Build secondary waveform bars
  List<Widget> _buildSecondaryBars() {
    const int barCount = 40;
    final List<Widget> bars = [];

    for (int i = 0; i < barCount; i++) {
      final amplitude = i < _amplitudeHistory.length
          ? _amplitudeHistory[_amplitudeHistory.length - barCount + i]
          : 0.0;

      bars.add(_buildSecondaryBar(amplitude, i));
    }

    return bars;
  }

  /// Build individual secondary bar
  Widget _buildSecondaryBar(double amplitude, int index) {
    final height = math.max(2.0, amplitude * 30.0);
    final isActive = widget.isRecording && amplitude > 0.1;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = isActive ? _pulseAnimation.value : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 2,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.cyan.withValues( alpha: 0.8)
                  : Colors.white.withValues( alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for main waveform display
class MainWaveformPainter extends CustomPainter {
  final List<double> amplitudeHistory;
  final double currentAmplitude;
  final bool isRecording;
  final double pulseValue;
  final double flowValue;

  MainWaveformPainter({
    required this.amplitudeHistory,
    required this.currentAmplitude,
    required this.isRecording,
    required this.pulseValue,
    required this.flowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudeHistory.isEmpty) {
      _drawStaticWave(canvas, size);
      return;
    }

    _drawAmplitudeWave(canvas, size);

    if (isRecording) {
      _drawRecordingEffects(canvas, size);
    }
  }

  /// Draw static wave when no recording data
  void _drawStaticWave(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues( alpha: 0.2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final centerY = size.height / 2;

    path.moveTo(0, centerY);

    for (double x = 0; x < size.width; x += 5) {
      final y = centerY + math.sin(x * 0.02) * 20;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  /// Draw actual amplitude-based waveform
  void _drawAmplitudeWave(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    final path = Path();

    // Create gradient effect
    final gradient = LinearGradient(
      colors: isRecording
          ? [Colors.red, Colors.pink, Colors.cyan]
          : [Colors.white.withValues( alpha: 0.7), Colors.white.withValues( alpha: 0.3)],
      stops: const [0.0, 0.5, 1.0],
    );

    paint.shader = gradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    // Draw waveform based on amplitude history
    if (amplitudeHistory.isNotEmpty) {
      final stepX = size.width / amplitudeHistory.length;

      path.moveTo(0, centerY);

      for (int i = 0; i < amplitudeHistory.length; i++) {
        final x = i * stepX;
        final amplitude = amplitudeHistory[i];
        final scaledAmplitude = amplitude * size.height * 0.4 * pulseValue;

        // Create wave effect
        final y1 = centerY - scaledAmplitude;
        final y2 = centerY + scaledAmplitude;

        if (i == 0) {
          path.moveTo(x, y1);
        } else {
          path.lineTo(x, y1);
        }
      }

      // Draw mirrored bottom part
      for (int i = amplitudeHistory.length - 1; i >= 0; i--) {
        final x = i * stepX;
        final amplitude = amplitudeHistory[i];
        final scaledAmplitude = amplitude * size.height * 0.4 * pulseValue;
        final y2 = centerY + scaledAmplitude;

        path.lineTo(x, y2);
      }

      path.close();
    }

    canvas.drawPath(path, paint);
  }

  /// Draw recording visual effects
  void _drawRecordingEffects(Canvas canvas, Size size) {
    // Draw pulsing center line
    final centerPaint = Paint()
      ..color = Colors.red.withValues( alpha: 0.3 * pulseValue)
      ..strokeWidth = 1;

    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerPaint,
    );

    // Draw flowing particles effect
    final particlePaint = Paint()
      ..color = Colors.cyan.withValues( alpha: 0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      final x = (size.width * flowValue + i * size.width / 5) % size.width;
      final y = centerY + math.sin(flowValue * 2 * math.pi + i) * 20;

      canvas.drawCircle(
        Offset(x, y),
        2 * pulseValue,
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}