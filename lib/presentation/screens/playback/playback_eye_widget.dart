// File: lib/presentation/screens/playback/playback_eye_widget.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum EyeDir { back, fwd }

class PlaybackEyeWidget extends StatefulWidget {
  final EyeDir dir;
  final Color color;
  final bool playing;
  final VoidCallback onTap;

  const PlaybackEyeWidget({
    super.key,
    required this.dir,
    required this.color,
    required this.playing,
    required this.onTap,
  });

  @override
  State<PlaybackEyeWidget> createState() => _PlaybackEyeWidgetState();
}

class _PlaybackEyeWidgetState extends State<PlaybackEyeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pupilCtrl;
  double _pupilOffset = 0;

  @override
  void initState() {
    super.initState();
    _pupilCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        setState(() {
          _pupilOffset = math.sin(_pupilCtrl.value * math.pi * 2 * 1.8) * 2;
        });
      });
  }

  @override
  void didUpdateWidget(PlaybackEyeWidget old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_pupilCtrl.isAnimating) {
      _pupilCtrl.repeat();
    } else if (!widget.playing && _pupilCtrl.isAnimating) {
      _pupilCtrl.stop();
      setState(() => _pupilOffset = 0);
    }
  }

  @override
  void dispose() {
    _pupilCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: CustomPaint(
        size: const Size(76, 56),
        painter: _EyePainter(
          dir: widget.dir,
          color: widget.color,
          pupilOffset: _pupilOffset,
        ),
      ),
    );
  }
}

class _EyePainter extends CustomPainter {
  final EyeDir dir;
  final Color color;
  final double pupilOffset;

  const _EyePainter({
    required this.dir,
    required this.color,
    required this.pupilOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final eyePath = Path()
      ..moveTo(cx - 34, cy)
      ..quadraticBezierTo(cx - 24, cy - 20, cx, cy - 20)
      ..quadraticBezierTo(cx + 24, cy - 20, cx + 34, cy)
      ..quadraticBezierTo(cx + 24, cy + 20, cx, cy + 20)
      ..quadraticBezierTo(cx - 24, cy + 20, cx - 34, cy)
      ..close();

    // glow
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // fill gradiente
    canvas.drawPath(
      eyePath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          radius: 0.8,
          colors: [
            const Color(0xFFFFF3C0),
            color,
            Color.lerp(color, const Color(0xFF8B6000), 0.4)!,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 34)),
    );

    // bordo
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = const Color(0xFF6B3A00).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // iris
    final bias = dir == EyeDir.back ? -6.0 : 6.0;
    final px = cx + bias + pupilOffset;
    final py = cy;

    canvas.drawCircle(
      Offset(px, py), 11,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFF8B5A2B),
            Color(0xFF6B3A15),
            Color(0xFF2A0F05),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(px, py), radius: 11)),
    );

    // pupilla triangolare gialla ◀ / ▶
    final pupilPath = Path();
    if (dir == EyeDir.back) {
      pupilPath
        ..moveTo(px + 5, py - 6)
        ..lineTo(px + 5, py + 6)
        ..lineTo(px - 5, py)
        ..close();
    } else {
      pupilPath
        ..moveTo(px - 5, py - 6)
        ..lineTo(px - 5, py + 6)
        ..lineTo(px + 5, py)
        ..close();
    }
    canvas.drawPath(pupilPath, Paint()..color = const Color(0xFFE8D04A));

    // riflessi
    canvas.drawCircle(Offset(px - 2, py - 3), 1.6,
        Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.drawCircle(Offset(px + 3, py + 2), 1.0,
        Paint()..color = Colors.white.withValues(alpha: 0.5));

    // ciglia
    final lashPaint = Paint()
      ..color = const Color(0xFF6B3A00).withValues(alpha: 0.8)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final l in [
      [cx - 28, cy - 14, cx - 30, cy - 19],
      [cx - 14, cy - 20, cx - 14, cy - 25],
      [cx + 14, cy - 20, cx + 14, cy - 25],
      [cx + 28, cy - 14, cx + 30, cy - 19],
    ]) {
      canvas.drawLine(Offset(l[0], l[1]), Offset(l[2], l[3]), lashPaint);
    }
  }

  @override
  bool shouldRepaint(_EyePainter old) =>
      old.pupilOffset != pupilOffset || old.dir != dir;
}
