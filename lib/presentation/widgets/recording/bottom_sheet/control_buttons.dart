// File: presentation/widgets/recording/bottom_sheet/control_buttons.dart
import 'package:flutter/material.dart';

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
        // 15 second rewind
        Flexible(
          flex: 2,
          child: _buildFullscreenControlButton(
            icon: Icons.replay_10,
            onPressed: isRecording ? null : () {},
            enabled: !isRecording,
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
          ),
        ),

        // Spacing
        const Flexible(flex: 1, child: SizedBox(width: 40)),

        // 15 second forward
        Flexible(
          flex: 2,
          child: _buildFullscreenControlButton(
            icon: Icons.forward_10,
            onPressed: isRecording ? null : () {},
            enabled: !isRecording,
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
  }) {
    final size = isLarge ? 80.0 : 60.0;
    final iconSize = isLarge ? 40.0 : 28.0;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled
            ? Colors.grey[800]?.withValues(alpha: 0.6)
            : Colors.grey[800]?.withValues(alpha: 0.3),
        border: Border.all(
          color: enabled
              ? Colors.grey[400]?.withValues(alpha: 0.5) ?? Colors.grey
              : Colors.grey[600]?.withValues(alpha: 0.3) ?? Colors.grey,
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: enabled ? Colors.white : Colors.grey,
          size: iconSize,
        ),
      ),
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
        color: isRecording ? Colors.white : Colors.red,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isRecording ? (onPause ?? () {}) : (onDone ?? () {}),
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: isRecording ?
              // Pause button when recording
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause, color: Colors.black, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Pause',
                    style: TextStyle(
                      color: Colors.black,
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
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
          ),
        ),
      ),
    );
  }
}