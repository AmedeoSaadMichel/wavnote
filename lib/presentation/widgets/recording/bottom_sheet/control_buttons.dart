// File: presentation/widgets/recording/bottom_sheet/control_buttons.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Fullscreen playback controls (iOS style)
class FullscreenPlaybackControls extends StatelessWidget {
  final bool isRecording;

  const FullscreenPlaybackControls({
    super.key,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 10 second rewind
        Flexible(
          flex: 2,
          child: _buildFullscreenControlButton(
            icon: Icons.replay_10,
            onPressed: isRecording ? null : () {},
            enabled: !isRecording,
            title: 'Rewind',
          ),
        ),

        // Spacing
        const Flexible(flex: 1, child: SizedBox(width: 40)),

        // Play/Pause button (larger)
        Flexible(
          flex: 3,
          child: _buildFullscreenControlButton(
            icon: Icons.play_arrow,
            onPressed: isRecording ? null : () {},
            enabled: !isRecording,
            isLarge: true,
            title: 'Play',
          ),
        ),

        // Spacing
        const Flexible(flex: 1, child: SizedBox(width: 40)),

        // 10 second forward
        Flexible(
          flex: 2,
          child: _buildFullscreenControlButton(
            icon: Icons.forward_10,
            onPressed: isRecording ? null : () {},
            enabled: !isRecording,
            title: 'Forward',
          ),
        ),
      ],
    );
  }

  /// Build fullscreen control button
  Widget _buildFullscreenControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool enabled,
    bool isLarge = false,
    String? title,
  }) {
    final size = isLarge ? 80.0 : 60.0;
    final iconSize = isLarge ? 40.0 : 28.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? const LinearGradient(
                    colors: [
                      Color(0xFF2E1065), // Deep midnight purple
                      Color(0xFF4C1D95), // Cosmic purple
                      Color(0xFF8B5CF6), // Ethereal purple
                    ],
                  )
                : const LinearGradient(
                    colors: [
                      Color(0xFF1E1B4B), // Dark mystical blue
                      Color(0xFF2E1065), // Deep midnight purple
                    ],
                  ),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFA855F7).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              width: 2,
            ),
            boxShadow: enabled ? [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] : [],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: enabled 
                  ? const Color(0xFFF3E8FF) // Light cosmic purple
                  : Colors.grey.withValues(alpha: 0.5),
              size: iconSize,
            ),
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: enabled 
                  ? const Color(0xFFF3E8FF) // Light cosmic purple
                  : Colors.grey.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Fullscreen action button (Pause/Replace/Done)
class FullscreenActionButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback? onPause;
  final VoidCallback? onDone;

  const FullscreenActionButton({
    super.key,
    required this.isRecording,
    this.onPause,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 56,
      decoration: BoxDecoration(
        gradient: isRecording 
            ? const LinearGradient(
                colors: [
                  Color(0xFFF3E8FF), // Light cosmic purple
                  Color(0xFFE9D5FF), // Ethereal lavender
                ],
              )
            : const LinearGradient(
                colors: [
                  Color(0xFF8B5CF6), // Cosmic purple
                  Color(0xFF7C3AED), // Deep mystical purple
                ],
              ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFA855F7).withValues(alpha: 0.5), // Ethereal purple border
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isRecording ? (onPause ?? () {}) : (onDone ?? () {}),
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: isRecording ?
              // Eye-inspired pause button when recording
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    child: CustomPaint(
                      painter: EyePausePainter(),
                      size: const Size(32, 32),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Pause',
                    style: TextStyle(
                      color: Color(0xFF2E1065), // Midnight purple
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ) :
              // Replace button when not recording
              const Text(
                'REPLACE',
                style: TextStyle(
                  color: Color(0xFFF3E8FF), // Light cosmic purple
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  shadows: [
                    Shadow(
                      color: Color(0xFF8B5CF6),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for eye-inspired pause button
class EyePausePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer eye border (blue ring)
    final outerPaint = Paint()
      ..color = const Color(0xFF4ECDC4) // Cyan blue border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 1, outerPaint);

    // Eye background (sclera) - off-white
    final scleraPaint = Paint()
      ..color = const Color(0xFFF8F8F6);
    canvas.drawCircle(center, radius - 3, scleraPaint);

    // Iris gradient (frog eye - red tones)
    final irisRadius = (radius - 5) * 0.75;
    final irisGradient = RadialGradient(
      colors: const [
        Color(0xFFFF6B6B), // Light red center
        Color(0xFFE74C3C), // Red
        Color(0xFFDC143C), // Crimson
        Color(0xFFB22222), // Fire brick
        Color(0xFF8B0000), // Dark red edge
      ],
      stops: const [0.0, 0.3, 0.6, 0.8, 1.0],
    );
    
    final irisPaint = Paint()
      ..shader = irisGradient.createShader(
        Rect.fromCircle(center: center, radius: irisRadius),
      );
    canvas.drawCircle(center, irisRadius, irisPaint);

    // Iris fiber lines (radial pattern like in eye image)
    final fiberPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 0.3;
    
    for (int i = 0; i < 40; i++) {
      final angle = (i * 9) * (3.14159 / 180); // Convert to radians
      final startRadius = irisRadius * 0.25;
      final endRadius = irisRadius * 0.95;
      
      final startX = center.dx + startRadius * math.cos(angle);
      final startY = center.dy + startRadius * math.sin(angle);
      final endX = center.dx + endRadius * math.cos(angle);
      final endY = center.dy + endRadius * math.sin(angle);
      
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        fiberPaint,
      );
    }

    // Pupil (black center)
    final pupilRadius = irisRadius * 0.3;
    final pupilPaint = Paint()
      ..color = Colors.black;
    canvas.drawCircle(center, pupilRadius, pupilPaint);

    // Pupil highlight (white reflection)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9);
    final highlightOffset = Offset(
      center.dx - pupilRadius * 0.4,
      center.dy - pupilRadius * 0.4,
    );
    canvas.drawCircle(highlightOffset, pupilRadius * 0.25, highlightPaint);

    // Stop icon overlay in the pupil (frog eye style)
    final stopPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    
    final stopSize = pupilRadius * 0.6;
    
    // Draw stop square (rounded corners for frog-like appearance)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: stopSize,
          height: stopSize,
        ),
        const Radius.circular(2),
      ),
      stopPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}