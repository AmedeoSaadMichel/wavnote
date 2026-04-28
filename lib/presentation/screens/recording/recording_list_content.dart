// File: lib/presentation/screens/recording/recording_list_content.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/recording_entity.dart';
import '../../bloc/recording/recording_bloc.dart';
import '../../widgets/recording/recording_card/recording_card.dart';
import '../../widgets/recording/pull_to_search_list.dart';
import '../playback/playback_screen.dart';
import 'controllers/recording_playback_view_state.dart';

/// Lista delle registrazioni con card espandibili e supporto al playback.
///
/// Widget puro: riceve tutti i dati e callback via parametri espliciti,
/// senza accedere direttamente a BLoC o coordinator (tranne per il
/// controllo isRecording nello stato vuoto).
class RecordingListCardList extends StatelessWidget {
  final List<RecordingEntity> recordings;
  final bool hasAnyRecordings;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueListenable<(String?, String?)> cardIdsNotifier;
  final ValueListenable<RecordingPlaybackViewState> playbackStateNotifier;
  final String currentFolderId;
  final Map<String, String> folderNames;
  final bool isEditMode;
  final Iterable<String> selectedRecordings;
  final void Function(RecordingEntity) onTap;
  final void Function(RecordingEntity) onDelete;
  final void Function(RecordingEntity) onMoveToFolder;
  final void Function(RecordingEntity) onMoreActions;
  final void Function(RecordingEntity) onRestore;
  final void Function(RecordingEntity) onToggleFavorite;
  final Future<void> Function() onTogglePlayback;
  final void Function(double) onSeek;
  final VoidCallback onSkipBackward;
  final VoidCallback onSkipForward;
  final void Function(String recordingId) onSelectionToggle;

  const RecordingListCardList({
    super.key,
    required this.recordings,
    required this.hasAnyRecordings,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.cardIdsNotifier,
    required this.playbackStateNotifier,
    required this.currentFolderId,
    required this.folderNames,
    required this.isEditMode,
    required this.selectedRecordings,
    required this.onTap,
    required this.onDelete,
    required this.onMoveToFolder,
    required this.onMoreActions,
    required this.onRestore,
    required this.onToggleFavorite,
    required this.onTogglePlayback,
    required this.onSeek,
    required this.onSkipBackward,
    required this.onSkipForward,
    required this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasAnyRecordings) {
      if (context.read<RecordingBloc>().state.isRecording) {
        return const SizedBox.shrink();
      }
      return const Center(
        child: Text(
          'No recordings yet',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    return PullToSearchList(
      itemCount: recordings.length,
      searchQuery: searchQuery,
      onSearchChanged: onSearchChanged,
      emptyState: searchQuery.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'No recordings found for "$searchQuery"',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : null,
      itemBuilder: (context, index) {
        final recording = recordings[index];
        return ValueListenableBuilder<(String?, String?)>(
          valueListenable: cardIdsNotifier,
          builder: (context, ids, _) {
            final isExpanded = ids.$1 == recording.id;
            final isActiveRecording = ids.$2 == recording.id;
            if (!isExpanded && !isActiveRecording) {
              return _buildCard(
                context: context,
                recording: recording,
                isExpanded: false,
                isPlaying: false,
                isLoading: false,
                currentPosition: Duration.zero,
                actualDuration: null,
              );
            }
            return ValueListenableBuilder<RecordingPlaybackViewState>(
              valueListenable: playbackStateNotifier,
              builder: (context, playbackState, _) {
                return _buildCard(
                  context: context,
                  recording: recording,
                  isExpanded: isExpanded,
                  isPlaying: isActiveRecording ? playbackState.isPlaying : false,
                  isLoading: isActiveRecording ? playbackState.isLoading : false,
                  currentPosition: isActiveRecording ? playbackState.position : Duration.zero,
                  actualDuration: isActiveRecording ? playbackState.duration : null,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required RecordingEntity recording,
    required bool isExpanded,
    required bool isPlaying,
    required bool isLoading,
    required Duration currentPosition,
    required Duration? actualDuration,
  }) {
    return RecordingCard(
      recording: recording,
      isExpanded: isExpanded,
      onTap: () => onTap(recording),
      onShowWaveform: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlaybackScreen(recording: recording)),
      ),
      onDelete: () => onDelete(recording),
      onMoveToFolder: () => onMoveToFolder(recording),
      onMoreActions: () => onMoreActions(recording),
      onRestore: () => onRestore(recording),
      onToggleFavorite: () => onToggleFavorite(recording),
      isPlaying: isPlaying,
      isLoading: isLoading,
      currentPosition: currentPosition,
      actualDuration: actualDuration,
      onPlayPause: onTogglePlayback,
      onSeek: onSeek,
      onSkipBackward: onSkipBackward,
      onSkipForward: onSkipForward,
      currentFolderId: currentFolderId,
      folderNames: folderNames,
      isEditMode: isEditMode,
      isSelected: selectedRecordings.contains(recording.id),
      onSelectionToggle: () => onSelectionToggle(recording.id),
    );
  }
}
