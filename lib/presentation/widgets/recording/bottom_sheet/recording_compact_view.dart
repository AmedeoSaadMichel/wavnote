// File: presentation/widgets/recording/bottom_sheet/recording_compact_view.dart
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'dart:math' as math;
import '../../../../core/extensions/duration_extensions.dart';
import 'waveform_components.dart';

/// Compact view for collapsed recording bottom sheet
class RecordingCompactView extends StatelessWidget {
  final String? title;
  final Duration elapsed;
  final bool isRecording;
  final String? filePath;
  final RecorderController recorderController;
  final Animation<double> pulseAnimation;
  final VoidCallback onToggle;

  const RecordingCompactView({
    super.key,
    required this.title,
    required this.elapsed,
    required this.isRecording,
    required this.filePath,
    required this.recorderController,
    required this.pulseAnimation,
    required this.onToggle,
  });

  /// Converts the elapsed recording time into formatted string
  String get _formattedTime {
    return elapsed.formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top spacer
        const Spacer(),
        
        // Handle at top
        Flexible(
          flex: 1,
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Compact animated content
        Flexible(
          flex: 8,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 100),
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1.0,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: isRecording
                ? _buildRecordingContent()
                : const SizedBox(key: ValueKey(false)),
          ),
        ),

        // Main record toggle button - centered
        Flexible(
          flex: 8,
          child: Center(
            child: _buildRecordButton(),
          ),
        ),

        // Bottom spacer
        const Spacer(),
      ],
    );
  }

  /// Build recording content when recording is active
  Widget _buildRecordingContent() {
    return Column(
      key: const ValueKey(true),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (title != null)
          Flexible(
            flex: 4,
            child: Text(
              title!, 
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 22, 
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const Spacer(flex: 1),
        Flexible(
          flex: 4,
          child: Text(
            _formattedTime, 
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7), 
              fontSize: 18,
            ),
          ),
        ),
        const Spacer(flex: 2),
        if (filePath != null) 
          Flexible(
            flex: 10,
            child: Center(
              child: Container(
                height: 120,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: CompactAudioWaveform(
                  recorderController: recorderController,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build record button with pulse animation
  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isRecording 
                  ? const LinearGradient(
                      colors: [
                        Color(0xFFDC143C), // Crimson red
                        Color(0xFFB22222), // Fire brick red
                        Color(0xFF8B0000), // Dark red
                      ],
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFFFFA500), // Orange
                        Color(0xFFFFC107), // Amber/Golden yellow
                      ],
                    ),
              border: Border.all(
                color: isRecording 
                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.8)
                    : Colors.cyan,
                width: isRecording ? 3 : 2, // Smaller cyan border when not recording
              ),
              boxShadow: [
                BoxShadow(
                  color: isRecording 
                      ? const Color(0xFFDC143C).withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.2),
                  blurRadius: isRecording ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 1000),
                child: isRecording
                    ? const Icon(
                        Icons.stop, 
                        key: ValueKey('stop'), 
                        color: Colors.white, // White stop icon
                        size: 32,
                      )
                    : const Icon(
                        Icons.fiber_manual_record, 
                        key: ValueKey('rec'), 
                        color: Color(0xFF2E1065), // Deep midnight purple for contrast
                        size: 30,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for compact frog eye pause button
class CompactEyePausePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer eye border (cyan blue ring)
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
    final irisRadius = (radius - 5) * 0.7;
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

    // Iris fiber lines (radial pattern like frog eye)
    final fiberPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..strokeWidth = 0.2;
    
    for (int i = 0; i < 32; i++) {
      final angle = (i * 11.25) * (3.14159 / 180); // Convert to radians
      final startRadius = irisRadius * 0.3;
      final endRadius = irisRadius * 0.9;
      
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

    // Stop icon in center (instead of pupil)
    final stopPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final stopSize = irisRadius * 0.4; // Larger stop icon
    
    // Draw stop square 
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