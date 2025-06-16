// File: presentation/widgets/recording/organic_background.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Organic background with flowing clouds and twinkling stars
class OrganicBackground extends StatefulWidget {
  const OrganicBackground({super.key});

  @override
  State<OrganicBackground> createState() => _OrganicBackgroundState();
}

class _OrganicBackgroundState extends State<OrganicBackground>
    with TickerProviderStateMixin {

  late AnimationController _cloudController;
  late AnimationController _starController;
  late Animation<double> _cloudAnimation;
  late Animation<double> _starAnimation;

  @override
  void initState() {
    super.initState();

    // Slow cloud drift animation
    _cloudController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Twinkling stars animation
    _starController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _cloudAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_cloudController);

    _starAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _starController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _cloudController.dispose();
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Organic flowing cloud background
        AnimatedBuilder(
          animation: _cloudAnimation,
          builder: (context, child) {
            return CustomPaint(
              size: Size(
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height,
              ),
              painter: OrganicCloudPainter(_cloudAnimation.value),
            );
          },
        ),

        // Scattered twinkling stars
        AnimatedBuilder(
          animation: _starAnimation,
          builder: (context, child) {
            return Stack(
              children: _generateStars(context),
            );
          },
        ),
      ],
    );
  }

  /// Generate random stars with twinkling effect
  List<Widget> _generateStars(BuildContext context) {
    final stars = <Widget>[];
    final random = math.Random(42); // Fixed seed for consistent positions

    for (int i = 0; i < 25; i++) {
      final left = random.nextDouble() * MediaQuery.of(context).size.width;
      final top = random.nextDouble() * MediaQuery.of(context).size.height;
      final starType = random.nextInt(3);
      final size = random.nextDouble() * 8 + 4;
      final twinkleOffset = random.nextDouble() * math.pi * 2;

      stars.add(
        Positioned(
          left: left,
          top: top,
          child: AnimatedBuilder(
            animation: _starController,
            builder: (context, child) {
              final opacity = 0.4 + (math.sin(_starController.value * 2 * math.pi + twinkleOffset) * 0.4);
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: _buildStar(starType, size),
              );
            },
          ),
        ),
      );
    }

    return stars;
  }

  /// Build individual star based on type
  Widget _buildStar(int type, double size) {
    switch (type) {
      case 0: // Four-pointed star
        return Icon(
          Icons.add,
          size: size,
          color: Colors.yellowAccent,
        );
      case 1: // Diamond star
        return Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Colors.pinkAccent,
              shape: BoxShape.rectangle,
            ),
          ),
        );
      case 2: // Circle star
        return Container(
          width: size * 0.6,
          height: size * 0.6,
          decoration: const BoxDecoration(
            color: Colors.cyanAccent,
            shape: BoxShape.circle,
          ),
        );
      default:
        return const SizedBox();
    }
  }
}

/// Custom painter for organic flowing clouds
class OrganicCloudPainter extends CustomPainter {
  final double animation;

  OrganicCloudPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Background base
    paint.color = const Color(0xFF6B2D8E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw flowing organic shapes
    _drawOrganicShape(canvas, size, const Color(0xFFE85A9B), 0.0, 0.1);
    _drawOrganicShape(canvas, size, const Color(0xFF8B5FBF), 0.2, 0.3);
    _drawOrganicShape(canvas, size, const Color(0xFF4A9EE8), 0.4, 0.6);
    _drawOrganicShape(canvas, size, const Color(0xFF6BCF7F), 0.6, 0.8);
    _drawOrganicShape(canvas, size, const Color(0xFFFFB347), 0.8, 1.0);
  }

  void _drawOrganicShape(Canvas canvas, Size size, Color color, double startY, double endY) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Create flowing organic shapes
    final baseY = size.height * startY;
    final amplitude = size.height * 0.15;
    final frequency = 0.01;

    path.moveTo(0, baseY);

    for (double x = 0; x <= size.width; x += 5) {
      // Multiple sine wave layers for organic feel
      final wave1 = math.sin((x * frequency) + (animation * 2 * math.pi)) * amplitude * 0.5;
      final wave2 = math.sin((x * frequency * 2.3) + (animation * 1.5 * math.pi)) * amplitude * 0.3;
      final wave3 = math.sin((x * frequency * 0.7) + (animation * 0.8 * math.pi)) * amplitude * 0.2;

      final y = baseY + wave1 + wave2 + wave3;
      path.lineTo(x, y);
    }

    // Close the shape to create cloud-like forms
    path.lineTo(size.width, size.height * endY);
    path.lineTo(0, size.height * endY);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}