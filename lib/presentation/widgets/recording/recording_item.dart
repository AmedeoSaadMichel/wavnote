// File: presentation/widgets/recording/recording_item.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../core/enums/audio_format.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/audio_player/audio_player_bloc.dart';

/// Widget to display a single recording item in lists
///
/// Shows recording metadata, playback controls, and handles user interactions.
/// Integrates with AudioPlayerBloc for playback functionality.
class RecordingItem extends StatelessWidget {
  final RecordingEntity recording;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onRename;
  final bool showPlayButton;
  final bool isCompact;

  const RecordingItem({
    super.key,
    required this.recording,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.onShare,
    this.onRename,
    this.showPlayButton = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioPlayerBloc, AudioPlayerState>(
      builder: (context, playerState) {
        final isCurrentlyPlaying = playerState is AudioPlayerPlaying &&
            playerState.currentRecording.id == recording.id;

        return GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: AppConstants.defaultAnimationDuration,
            margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
            padding: EdgeInsets.all(isCompact ? 12 : AppConstants.defaultPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCurrentlyPlaying
                    ? [
                  AppConstants.primaryPurple.withValues(alpha: 0.8),
                  AppConstants.primaryPink.withValues(alpha: 0.6),
                ]
                    : [
                  AppConstants.surfacePurple.withValues(alpha: 0.7),
                  AppConstants.backgroundDark.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
              border: Border.all(
                color: isCurrentlyPlaying
                    ? AppConstants.accentCyan.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
                width: isCurrentlyPlaying ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: isCurrentlyPlaying ? 8 : 4,
                  offset: Offset(0, isCurrentlyPlaying ? 4 : 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with title and metadata
                _buildHeaderRow(playerState),

                if (!isCompact) ...[
                  const SizedBox(height: 8),
                  // Waveform or progress indicator
                  _buildWaveformArea(playerState),
                  const SizedBox(height: 12),
                  // Controls row
                  _buildControlsRow(context, playerState),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Get format color based on audio format
  Color _getFormatColor(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return Colors.cyan;
      case AudioFormat.m4a:
        return Colors.green;
      case AudioFormat.flac:
        return Colors.orange;
    }
  }

  /// Get format icon based on audio format
  IconData _getFormatIcon(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return Icons.graphic_eq;
      case AudioFormat.m4a:
        return Icons.apple;
      case AudioFormat.flac:
        return Icons.music_note;
    }
  }

  /// Get format name based on audio format
  String _getFormatName(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return 'WAV';
      case AudioFormat.m4a:
        return 'M4A';
      case AudioFormat.flac:
        return 'FLAC';
    }
  }

  /// Build header row with recording name and metadata
  Widget _buildHeaderRow(AudioPlayerState playerState) {
    final isPlaying = playerState is AudioPlayerPlaying &&
        playerState.currentRecording.id == recording.id;

    return Row(
      children: [
        // Recording icon/status
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getFormatColor(recording.format).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getFormatColor(recording.format).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            isPlaying ? Icons.graphic_eq : _getFormatIcon(recording.format),
            color: _getFormatColor(recording.format),
            size: isCompact ? 16 : 20,
          ),
        ),

        const SizedBox(width: 12),

        // Recording details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recording name
              Text(
                recording.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Metadata row
              Row(
                children: [
                  // Duration
                  Text(
                    recording.durationFormatted,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: isCompact ? 11 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // File size
                  Text(
                    recording.fileSizeFormatted,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: isCompact ? 10 : 11,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Format badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getFormatColor(recording.format).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getFormatName(recording.format),
                      style: TextStyle(
                        color: _getFormatColor(recording.format),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Favorite indicator
        if (recording.isFavorite)
          Icon(
            Icons.favorite,
            color: Colors.red,
            size: isCompact ? 16 : 20,
          ),

        const SizedBox(width: 8),

        // Date
        Text(
          recording.ageDescription,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: isCompact ? 10 : 11,
          ),
        ),
      ],
    );
  }

  /// Build waveform visualization area
  Widget _buildWaveformArea(AudioPlayerState playerState) {
    if (playerState is AudioPlayerWithRecording &&
        playerState.currentRecording.id == recording.id) {
      return _buildPlaybackProgress(playerState);
    }

    return _buildStaticWaveform();
  }

  /// Build playback progress indicator
  Widget _buildPlaybackProgress(AudioPlayerWithRecording playerState) {
    return Column(
      children: [
        // Progress bar
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: playerState.progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppConstants.accentCyan,
                    AppConstants.primaryPink,
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Time indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              playerState.positionFormatted,
              style: TextStyle(
                color: AppConstants.accentCyan,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              playerState.durationFormatted,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build static waveform representation
  Widget _buildStaticWaveform() {
    return SizedBox(
      height: 30,
      child: Row(
        children: List.generate(50, (index) {
          final height = (index % 7 + 1) * 3.0; // Simulated waveform
          return Container(
            width: 2,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
  }

  /// Build controls row with play/pause and action buttons
  Widget _buildControlsRow(BuildContext context, AudioPlayerState playerState) {
    final isCurrentRecording = playerState is AudioPlayerWithRecording &&
        playerState.currentRecording.id == recording.id;
    final isPlaying = playerState is AudioPlayerPlaying && isCurrentRecording;
    final isPaused = playerState is AudioPlayerPaused && isCurrentRecording;

    return Row(
      children: [
        // Play/Pause button
        if (showPlayButton)
          _buildPlayPauseButton(context, isPlaying, isPaused),

        const SizedBox(width: 12),

        // Speed control (when playing)
        if (isCurrentRecording && playerState is AudioPlayerWithRecording)
          _buildSpeedButton(context, playerState),

        const Spacer(),

        // Action buttons
        _buildActionButtons(context),
      ],
    );
  }

  /// Build play/pause button
  Widget _buildPlayPauseButton(BuildContext context, bool isPlaying, bool isPaused) {
    return GestureDetector(
      onTap: () {
        final audioBloc = context.read<AudioPlayerBloc>();

        if (isPlaying) {
          audioBloc.add(const PausePlayback());
        } else if (isPaused) {
          audioBloc.add(const ResumePlayback());
        } else {
          audioBloc.add(PlayRecording(recording));
        }
      },
      child: Container(
        width: AppConstants.playButtonSize,
        height: AppConstants.playButtonSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPlaying
                ? [Colors.orange, Colors.red]
                : [AppConstants.accentCyan, AppConstants.primaryPink],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isPlaying ? Colors.orange : AppConstants.accentCyan)
                  .withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  /// Build speed control button
  Widget _buildSpeedButton(BuildContext context, AudioPlayerWithRecording playerState) {
    return GestureDetector(
      onTap: () => _showSpeedDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppConstants.accentCyan.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppConstants.accentCyan.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          playerState.speedFormatted,
          style: TextStyle(
            color: AppConstants.accentCyan,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Build action buttons (share, rename, delete)
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Share button
        if (onShare != null)
          _buildActionButton(
            icon: Icons.share,
            color: Colors.blue,
            onPressed: onShare!,
          ),

        // Rename button
        if (onRename != null) ...[
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.edit,
            color: Colors.green,
            onPressed: onRename!,
          ),
        ],

        // Delete button
        if (onDelete != null) ...[
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.delete_outline,
            color: Colors.red,
            onPressed: onDelete!,
          ),
        ],
      ],
    );
  }

  /// Build individual action button
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 16,
        ),
      ),
    );
  }

  /// Show speed selection dialog
  void _showSpeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppConstants.backgroundDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
        title: const Text(
          'Playback Speed',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
            return ListTile(
              title: Text(
                '${speed}x',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                context.read<AudioPlayerBloc>().add(SetPlaybackSpeed(speed));
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Compact version for smaller displays
class CompactRecordingItem extends StatelessWidget {
  final RecordingEntity recording;
  final VoidCallback? onTap;

  const CompactRecordingItem({
    super.key,
    required this.recording,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RecordingItem(
      recording: recording,
      onTap: onTap,
      isCompact: true,
      showPlayButton: false,
    );
  }
}