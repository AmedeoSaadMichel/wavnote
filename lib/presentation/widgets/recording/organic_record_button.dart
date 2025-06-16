// File: presentation/widgets/recording/organic_record_button.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Organic pulsing record button
class OrganicRecordButton extends StatelessWidget {
  const OrganicRecordButton({
    super.key,
    required this.onTap,
    required this.pulseController,
  });

  final VoidCallback onTap;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final scale = 1.0 + (math.sin(pulseController.value * 2 * math.pi) * 0.05);
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFFF4444),
                    Color(0xFFDD2222),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.fiber_manual_record,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        );
      },
    );
  }
}