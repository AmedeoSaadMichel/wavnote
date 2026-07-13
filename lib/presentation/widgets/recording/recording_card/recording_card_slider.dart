// File: lib/presentation/widgets/recording/recording_card/recording_card_slider.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

class RecordingCardSlider extends StatefulWidget {
  final double value;
  final bool isPlaying;
  final bool enabled;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const RecordingCardSlider({
    super.key,
    required this.value,
    required this.isPlaying,
    required this.enabled,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  State<RecordingCardSlider> createState() => _RecordingCardSliderState();
}

class _RecordingCardSliderState extends State<RecordingCardSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  void _updateFromOffset(Offset localPosition, double width, bool isEnd) {
    final value = (localPosition.dx / width).clamp(0.0, 1.0);
    _dragValue = value;
    widget.onChanged(value);
    if (isEnd) widget.onChangeEnd(value);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: widget.enabled
                ? (details) {
                    _isDragging = true;
                    _dragValue = widget.value;
                    widget.onChangeStart(widget.value);
                    _updateFromOffset(
                      details.localPosition,
                      constraints.maxWidth,
                      false,
                    );
                  }
                : null,
            onHorizontalDragUpdate: widget.enabled
                ? (details) => _updateFromOffset(
                    details.localPosition,
                    constraints.maxWidth,
                    false,
                  )
                : null,
            onHorizontalDragEnd: widget.enabled
                ? (_) {
                    _isDragging = false;
                    widget.onChangeEnd(_dragValue);
                  }
                : null,
            onTapDown: widget.enabled
                ? (details) {
                    widget.onChangeStart(widget.value);
                    _updateFromOffset(
                      details.localPosition,
                      constraints.maxWidth,
                      true,
                    );
                  }
                : null,
            onTap: widget.enabled ? () {} : null,
            child: AnimatedBuilder(
              animation: _motionController,
              builder: (context, _) {
                return TweenAnimationBuilder<double>(
                  duration: _isDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 120),
                  curve: Curves.linear,
                  tween: Tween(end: widget.value.clamp(0.0, 1.0)),
                  builder: (context, progress, _) => CustomPaint(
                    painter: _RecordingCardSliderPainter(
                      progress: progress,
                      motion: _motionController.value,
                      isPlaying: widget.isPlaying || _isDragging,
                      enabled: widget.enabled,
                    ),
                    size: Size(constraints.maxWidth, 30),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RecordingCardSliderPainter extends CustomPainter {
  final double progress;
  final double motion;
  final bool isPlaying;
  final bool enabled;

  const _RecordingCardSliderPainter({
    required this.progress,
    required this.motion,
    required this.isPlaying,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final headX = (progress * size.width).clamp(0.0, size.width);
    final tailAmp = isPlaying ? 5.0 : 3.2;
    final opacity = enabled ? 1.0 : 0.45;
    final phase = motion * math.pi * 2;

    final trackPath = Path()..moveTo(0, centerY);
    for (double x = 0; x <= size.width; x += 4) {
      final y = centerY + math.sin(x * 0.045 + phase) * 2.6;
      trackPath.lineTo(x, y);
    }

    final tailPath = Path()..moveTo(0, centerY);
    for (double x = 0; x <= headX; x += 2) {
      final distToHead = math.max(0.0, headX - x);
      final envelope = math.min(1.0, distToHead / 18.0);
      final y = centerY + math.sin(x * 0.11 - phase) * tailAmp * envelope;
      tailPath.lineTo(x, y);
    }

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32 * opacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(trackPath, trackPaint);

    final tailPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFA3F3FF).withValues(alpha: 0),
          const Color(0xFFA3F3FF).withValues(alpha: 0.8 * opacity),
          const Color(0xFFA3F3FF).withValues(alpha: opacity),
          const Color(0xFFF5FF5E).withValues(alpha: opacity),
        ],
        stops: const [0.0, 0.15, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);
    canvas.drawPath(tailPath, tailPaint);

    final crispTailPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 * opacity)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(tailPath, crispTailPaint);

    final dx = 1.5;
    final y1 = centerY + math.sin((headX - dx) * 0.11 - phase) * tailAmp;
    final y2 = centerY + math.sin(headX * 0.11 - phase) * tailAmp;
    final angle = math.atan2(y2 - y1, dx);
    final headY = y2;

    canvas.save();
    canvas.translate(headX, headY);
    canvas.rotate(angle);

    final shadowPaint = Paint()
      ..color = const Color(0xFFF5FF5E).withValues(alpha: 0.55 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 19, height: 12),
      shadowPaint,
    );

    final headPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        radius: 0.75,
        colors: [Colors.white, Color(0xFFFFFBCF), Color(0xFFF5FF5E)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(const Rect.fromLTWH(-9, -6, 18, 12));
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 17, height: 10.4),
      headPaint,
    );

    final headStroke = Paint()
      ..color = const Color(0xFF1A0533).withValues(alpha: 0.55 * opacity)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 17, height: 10.4),
      headStroke,
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(3.2, 0), width: 10.4, height: 6.8),
      Paint()..color = const Color(0xFFFFFBCF).withValues(alpha: 0.9 * opacity),
    );
    canvas.drawCircle(
      const Offset(-0.5, -0.5),
      2.4,
      Paint()
        ..color = const Color(0xFF3EC9E8).withValues(alpha: 0.85 * opacity),
    );
    canvas.drawCircle(
      const Offset(-1.2, -1.2),
      1.1,
      Paint()..color = Colors.white.withValues(alpha: 0.95 * opacity),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RecordingCardSliderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.motion != motion ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.enabled != enabled;
  }
}
