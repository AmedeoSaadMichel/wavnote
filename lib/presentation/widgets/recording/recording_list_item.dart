// File: presentation/widgets/recording/recording_list_item.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Individual recording item widget
class RecordingListItem extends StatelessWidget {
  const RecordingListItem({
    super.key,
    required this.recording,
    required this.onTap,
  });

  final Map<String, dynamic> recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPlaying = recording['isPlaying'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4A1A5C).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recording name and date
                _buildRecordingHeader(),

                if (isPlaying) ...[
                  const SizedBox(height: 16),
                  // Waveform visualization
                  _buildWaveform(),
                  const SizedBox(height: 12),
                  // Time display
                  _buildTimeDisplay(),
                  const SizedBox(height: 16),
                  // Control buttons
                  _buildControlButtons(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build recording header with name and date
  Widget _buildRecordingHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recording['name'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          recording['date'],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Build waveform visualization
  Widget _buildWaveform() {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          // Play position indicator
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Waveform bars
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 60),
              painter: WaveformPainter(),
            ),
          ),
        ],
      ),
    );
  }

  /// Build time display
  Widget _buildTimeDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '00:00',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
        Text(
          recording['duration'],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Build control buttons
  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: Icons.graphic_eq,
          color: Colors.blueAccent,
        ),
        _buildControlButton(
          icon: Icons.replay_10,
          color: Colors.white,
        ),
        _buildControlButton(
          icon: Icons.play_arrow,
          color: Colors.white,
          isLarge: true,
        ),
        _buildControlButton(
          icon: Icons.forward_10,
          color: Colors.white,
        ),
        _buildControlButton(
          icon: Icons.delete_outline,
          color: Colors.blueAccent,
        ),
      ],
    );
  }

  /// Build individual control button
  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    bool isLarge = false,
  }) {
    final size = isLarge ? 50.0 : 40.0;
    final iconSize = isLarge ? 28.0 : 20.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isLarge ? Colors.white : Colors.transparent,
        shape: BoxShape.circle,
        border: isLarge ? null : Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: isLarge ? Colors.black : color,
        size: iconSize,
      ),
    );
  }
}

/// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final random = math.Random(42);
    final barWidth = 2.0;
    final spacing = 3.0;
    final barCount = (size.width / (barWidth + spacing)).floor();

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing);
      final height = random.nextDouble() * size.height * 0.8 + size.height * 0.1;
      final y = (size.height - height) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, height),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}