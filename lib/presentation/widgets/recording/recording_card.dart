// File: presentation/widgets/recording/recording_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/duration_extensions.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../bloc/audio_player/audio_player_bloc.dart';
import '../../bloc/audio_player/audio_player_event.dart';
import '../../bloc/audio_player/audio_player_state.dart';

/// Expandable recording card with player controls
///
/// Contains the expanded layout for recording items with playback controls,
/// progress slider, and action buttons in a clean, customizable layout.
class RecordingCard extends StatelessWidget {
  final RecordingEntity recording;
  final AudioPlayerState? playerState;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSkipBackward;
  final VoidCallback onSkipForward;
  final VoidCallback onShowWaveform;
  final VoidCallback onDelete;
  final Function(Duration) onSeekToPosition;

  const RecordingCard({
    Key? key,
    required this.recording,
    this.playerState,
    required this.onTogglePlayback,
    required this.onSkipBackward,
    required this.onSkipForward,
    required this.onShowWaveform,
    required this.onDelete,
    required this.onSeekToPosition,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isPlaying = playerState is AudioPlayerPlaying &&
        (playerState as AudioPlayerPlaying).currentFilePath.contains(recording.id);
    final isPaused = playerState is AudioPlayerPaused &&
        (playerState as AudioPlayerPaused).currentFilePath.contains(recording.id);
    final currentPosition = (playerState is AudioPlayerPlaying)
        ? (playerState as AudioPlayerPlaying).position
        : (playerState is AudioPlayerPaused)
        ? (playerState as AudioPlayerPaused).position
        : Duration.zero;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: MediaQuery.of(context).size.height * 0.2, // 20% of screen height
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          // Recording info section
          Expanded(
            flex: 2,
            child: _buildRecordingInfo(),
          ),

          const SizedBox(height: 16),

          // Progress slider with time labels
          Expanded(
            flex: 2,
            child: _buildProgressSlider(currentPosition),
          ),

          const SizedBox(height: 16),

          // Controls row
          Expanded(
            flex: 2,
            child: _buildControlsRow(isPlaying),
          ),
        ],
      ),
    );
  }

  /// Build recording information section
  Widget _buildRecordingInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          recording.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 4),
        
        // Date
        Text(
          recording.createdAt.userFriendlyFormat,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Build progress slider section
  Widget _buildProgressSlider(Duration currentPosition) {
    return Column(
      children: [
        // Time labels and slider
        Row(
          children: [
            // Current time
            Text(
              currentPosition.formatted,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            // Slider
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  activeTrackColor: AppConstants.accentCyan,
                  inactiveTrackColor: Colors.grey[600],
                  thumbColor: AppConstants.accentCyan,
                  overlayColor: AppConstants.accentCyan.withOpacity(0.2),
                ),
                child: Slider(
                  value: recording.duration.inMilliseconds > 0
                      ? (currentPosition.inMilliseconds / recording.duration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  onChanged: (value) {
                    final position = Duration(
                      milliseconds: (value * recording.duration.inMilliseconds).round(),
                    );
                    onSeekToPosition(position);
                  },
                ),
              ),
            ),
            
            // Remaining time
            Text(
              '-${(recording.duration - currentPosition).formatted}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build controls row section
  Widget _buildControlsRow(bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Volume/Waveform button
        _buildControlButton(
          icon: const Icon(Icons.volume_up, color: Colors.white, size: 24),
          onPressed: onShowWaveform,
        ),

        // Skip backward 15s
        _buildControlButton(
          icon: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.replay, color: Colors.white, size: 32),
              Positioned(
                bottom: 8,
                child: Text(
                  '15',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          onPressed: onSkipBackward,
        ),

        // Play/Pause button (larger)
        GestureDetector(
          onTap: onTogglePlayback,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppConstants.accentCyan,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppConstants.accentCyan.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.black,
              size: 32,
            ),
          ),
        ),

        // Skip forward 15s
        _buildControlButton(
          icon: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.fast_forward, color: Colors.white, size: 32),
              Positioned(
                bottom: 8,
                child: Text(
                  '15',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          onPressed: onSkipForward,
        ),

        // Delete button
        _buildControlButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
          onPressed: onDelete,
        ),
      ],
    );
  }

  /// Build control button helper
  Widget _buildControlButton({
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: icon,
      ),
    );
  }
}