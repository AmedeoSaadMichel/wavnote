// File: presentation/screens/recording/recording_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../bloc/recording/recording_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../widgets/recording/recording_bottom_sheet.dart';
import '../../widgets/recording/recording_card/recording_card.dart';
import '../../widgets/recording/recording_list_header.dart';
import '../../widgets/recording/recording_edit_toolbar.dart';
import '../../widgets/recording/pull_to_search_list.dart';
import 'audio_player_manager.dart';
import 'recording_list_logic.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../data/database/database_pool.dart';

/// Recording List Screen with Single AudioPlayer Architecture
///
/// Features:
/// - Single AudioPlayer instance at screen level
/// - Pure UI RecordingCards with callbacks
/// - One expanded card at a time
/// - Instant audio playback (like old project)
class RecordingListScreen extends StatefulWidget {
  final FolderEntity folder;

  const RecordingListScreen({
    Key? key,
    required this.folder,
  }) : super(key: key);

  @override
  State<RecordingListScreen> createState() => _RecordingListScreenState();
}

class _RecordingListScreenState extends State<RecordingListScreen> with RecordingListLogic {
  @override
  final AudioPlayerManager audioPlayerManager = AudioPlayerManager();
  
  @override
  FolderEntity get folder => widget.folder;

  @override
  void initState() {
    super.initState();
    initializeRecordingList();
  }

  @override
  void dispose() {
    audioPlayerManager.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<RecordingBloc, RecordingState>(
          listener: (context, state) => handleRecordingStateChange(state),
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0a0a0a),
                Color(0xFF1a1a1a),
                Color(0xFF000000),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    RecordingListHeader(
                      folderName: widget.folder.name,
                      onBack: () {
                        // Save "main" folder ID using ultra-fast database pool
                        print('📁 RecordingListScreen: User tapped back button - saving main folder state with pool');
                        DatabasePool.saveLastFolderId('main'); // Ultra-fast save
                        context.read<SettingsBloc>().add(const UpdateLastOpenedFolder('main')); // Also update BLoC
                        context.goToMain();
                        print('📁 RecordingListScreen: Navigation to main completed');
                      },
                    ),
                    RecordingEditToolbar(
                      onDeleteSelected: deleteSelectedRecordings,
                    ),
                    Expanded(
                      child: _buildRecordingsList(context),
                    ),
                    const SizedBox(height: 200),
                  ],
                ),
                if (widget.folder.id != 'recently_deleted') _buildRecordingBottomSheet(context),
              ],
            ),
          ),
        ),
      ),
    );
  }




  /// Build recordings list
  Widget _buildRecordingsList(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, state) {
        if (state is RecordingLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppConstants.accentYellow,
            ),
          );
        }

        if (state is RecordingLoaded) {
          final filteredRecordings = filterRecordings(state.recordings);
          
          if (state.recordings.isEmpty) {
            // Don't show "No recordings yet" when recording is active
            final recordingBloc = context.read<RecordingBloc>();
            final currentState = recordingBloc.state;
            if (currentState.isRecording) {
              return const SizedBox.shrink(); // Hide the message when recording
            }
            
            return const Center(
              child: Text(
                'No recordings yet',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
            );
          }

          return PullToSearchList(
            itemCount: filteredRecordings.length,
            searchQuery: searchQuery,
            onSearchChanged: updateSearchQuery,
            emptyState: searchQuery.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recordings found for "$searchQuery"',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : null,
            itemBuilder: (context, index) {
              final recording = filteredRecordings[index];
              final isExpanded = audioPlayerManager.expandedRecordingId == recording.id;
              return RecordingCard(
                recording: recording,
                isExpanded: isExpanded,
                onTap: () => expandRecording(recording),
                onShowWaveform: () {},
                onDelete: () => deleteRecording(recording),
                onMoveToFolder: () => moveRecordingToFolder(recording),
                onMoreActions: () => showMoreActions(recording),
                onRestore: () => restoreRecording(recording),
                onToggleFavorite: () => toggleFavoriteRecording(recording),
                isPlaying: isExpanded ? audioPlayerManager.isPlaying : false,
                isLoading: isExpanded ? audioPlayerManager.isLoading : false,
                currentPosition: isExpanded ? audioPlayerManager.position : Duration.zero,
                actualDuration: isExpanded ? audioPlayerManager.duration : null,
                onPlayPause: togglePlayback,
                onSeek: seekToPosition,
                onSkipBackward: skipBackward,
                onSkipForward: skipForward,
                currentFolderId: widget.folder.id,
                folderNames: folderNames,
                isEditMode: state.isEditMode,
                isSelected: state.selectedRecordings.contains(recording.id),
                onSelectionToggle: () => context.read<RecordingBloc>().add(
                  ToggleRecordingSelection(recordingId: recording.id),
                ),
              );
            },
          );
        }

        // Handle other states (RecordingInProgress, RecordingError, etc.)
        // Hide content while recording is in progress instead of showing "No recordings yet"
        if (state is RecordingInProgress || state is RecordingStarting) {
          return const SizedBox.shrink(); // Hide content when recording
        }
        
        if (state is RecordingError) {
          return Center(
            child: Text(
              'Error: ${state.message}',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }
        
        // Default fallback for any other states
        return const Center(
          child: CircularProgressIndicator(
            color: AppConstants.accentYellow,
          ),
        );
      },
    );
  }

  /// Build recording bottom sheet
  Widget _buildRecordingBottomSheet(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, recordingState) {
        final isRecording = recordingState.isRecording;
        final currentTitle = recordingState is RecordingInProgress
            ? recordingState.title ?? 'New Recording'
            : 'New Recording';
        final elapsed = recordingState.currentDuration ?? Duration.zero;

        return RecordingBottomSheet(
          title: currentTitle,
          filePath: isRecording ? '/temp/current_recording.m4a' : null,
          isRecording: isRecording,
          onToggle: toggleRecording,
          elapsed: elapsed,
          width: MediaQuery.of(context).size.width,
          onTitleChanged: (newTitle) {
            context.read<RecordingBloc>().add(
              UpdateRecordingTitle(title: newTitle),
            );
          },
          onPause: pauseRecording,
          onDone: finishRecording,
          onChat: showTranscriptOptions,
        );
      },
    );
  }


}