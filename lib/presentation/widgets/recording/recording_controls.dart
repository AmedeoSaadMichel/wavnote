// File: presentation/widgets/recording/recording_controls.dart
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
    Key? key,
    required this.isPlaying,
    required this.isLoading,
    required this.onShowWaveform,
    required this.onSkipBackward,
    required this.onPlayPause,
    required this.onSkipForward,
    required this.onDelete,
  }) : super(key: key);

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
            icon: _buildSkipIcon('10', Icons.fast_rewind),
            onPressed: onSkipBackward,
          ),
        ),
        Expanded(
          flex: 3,
          child: Center(
            child: GestureDetector(
              onTap: onPlayPause,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildPlayPauseIcon(),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: _buildControlButton(
            icon: _buildSkipIcon('10', Icons.fast_forward),
            onPressed: onSkipForward,
          ),
        ),
        Expanded(
          flex: 2,
          child: _buildControlButton(
            icon: const FaIcon(FontAwesomeIcons.skull, color: Colors.blue, size: 24),
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayPauseIcon() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    } else if (isPlaying) {
      return const Icon(
        Icons.pause,
        color: Colors.black,
        size: 32,
      );
    } else {
      return const Icon(
        Icons.play_arrow,
        color: Colors.black,
        size: 32,
      );
    }
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
              child: FittedBox(
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}