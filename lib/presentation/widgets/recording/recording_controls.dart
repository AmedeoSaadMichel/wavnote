// File: lib/presentation/widgets/recording/recording_controls.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Widget for recording playback controls
class RecordingControls extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onShowWaveform;
  final VoidCallback onSkipBackward;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipForward;
  final VoidCallback onDelete;

  const RecordingControls({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onShowWaveform,
    required this.onSkipBackward,
    required this.onPlayPause,
    required this.onSkipForward,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildControlButton(
            icon: const Icon(Icons.graphic_eq, color: Colors.blue, size: 24),
            onPressed: onShowWaveform,
          ),
        ),
        Expanded(
          flex: 2,
          child: _buildControlButton(
            icon: const Icon(Icons.replay_10, color: Colors.cyan, size: 28),
            onPressed: onSkipBackward,
          ),
        ),
        Expanded(
          flex: 3,
          child: Center(
            child: GestureDetector(
              onTap: isLoading ? null : onPlayPause,
              child: _buildCenterButton(),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: _buildControlButton(
            icon: const Icon(Icons.forward_10, color: Colors.cyan, size: 28),
            onPressed: onSkipForward,
          ),
        ),
        Expanded(
          flex: 2,
          child: _buildControlButton(
            icon: const FaIcon(
              FontAwesomeIcons.skull,
              color: Colors.cyan,
              size: 24,
            ),
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }

  Widget _buildCenterButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.35),
          radius: 0.82,
          colors: [
            Color(0xFFFFFDF5),
            Color(0xFFFFF5D6),
            Color(0xFFFFD84A),
            Color(0xFFF59E3B),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.85),
            blurRadius: 0,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: const Color(0xFFFFD84A).withValues(alpha: 0.7),
            blurRadius: 18,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: isLoading ? _buildLoadingIndicator() : _buildCenterGlyph(),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A0612)),
      ),
    );
  }

  Widget _buildCenterGlyph() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFF7BE0FF), Color(0xFF3EC9E8), Color(0xFF0A4A6B)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: const Color(0xFF0A0612),
          size: 28,
        ),
        Positioned(
          left: 17,
          top: 14,
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkipIcon(String text, IconData icon) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 32),
        Positioned(
          bottom: 8,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: FractionallySizedBox(
            widthFactor: 0.7,
            heightFactor: 0.7,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: FittedBox(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
