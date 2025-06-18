// File: presentation/screens/recording/recording_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../bloc/recording/recording_bloc.dart';
import '../../bloc/audio_player/audio_player_bloc.dart';
import '../../bloc/audio_player/audio_player_event.dart';
import '../../bloc/audio_player/audio_player_state.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/duration_extensions.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../../core/enums/audio_format.dart';
import '../../widgets/recording/recording_bottom_sheet.dart';
import '../../widgets/recording/recording_card.dart';

/// iPhone Voice Memos Style Recording List Screen with Cosmic Theme
///
/// Recreates the exact iPhone Voice Memos interface with:
/// - "All Recordings" header with Edit button
/// - Clean recording list with titles, dates, and durations
/// - Transcript icon for transcribed recordings
/// - Three-dot menu for actions
/// - Inline audio player with waveform and controls
/// - Cosmic theme overlay while maintaining iOS design language
/// - Fixed BLoC provider errors
class RecordingListScreen extends StatelessWidget {
  final FolderEntity folder;

  const RecordingListScreen({
    Key? key,
    required this.folder,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    // Load recordings on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🚀 Loading recordings for folder: ${folder.id}');
      context.read<RecordingBloc>().add(LoadRecordings(folderId: folder.id));
    });

    return BlocListener<RecordingBloc, RecordingState>(
      listener: (context, state) {
        // Refresh recordings list when recording is completed
        if (state is RecordingCompleted) {
          print('🔄 Recording completed, refreshing list for folder: ${folder.id}');
          context.read<RecordingBloc>().add(LoadRecordings(folderId: folder.id));
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0a0a0a), // Darker for iPhone style
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
                  _buildHeader(context),
                  Expanded(
                    child: _buildRecordingsList(context),
                  ),
                  // Add bottom padding to prevent overlap with bottom sheet
                  const SizedBox(height: 200),
                ],
              ),

              // Position the bottom sheet absolutely
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: BlocBuilder<RecordingBloc, RecordingState>(
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
                      onToggle: () => _toggleRecording(context),
                      elapsed: elapsed,
                      width: MediaQuery.of(context).size.width,
                      onTitleChanged: (newTitle) {
                        context.read<RecordingBloc>().add(
                          UpdateRecordingTitle(title: newTitle),
                        );
                      },
                      onPause: () => _pauseRecording(context),
                      onDone: () => _finishRecording(context),
                      onChat: () => _showTranscriptOptions(context),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  /// Build iPhone-style header with "All Recordings" title and Edit button
  Widget _buildHeader(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, recordingState) {
        final isEditMode = recordingState is RecordingLoaded ? recordingState.isEditMode : false;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Back button
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: AppConstants.accentCyan,
                  size: 20,
                ),
              ),

              const Spacer(),

              // Edit button
              TextButton(
                onPressed: () {
                  context.read<RecordingBloc>().add(const ToggleEditMode());
                },
                child: Text(
                  isEditMode ? 'Done' : 'Edit',
                  style: const TextStyle(
                    color: AppConstants.accentCyan,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build recordings list with proper error handling
  Widget _buildRecordingsList(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, recordingState) {
        if (recordingState is RecordingLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppConstants.accentCyan,
            ),
          );
        }

        if (recordingState is RecordingError) {
          return _buildErrorState(context, recordingState.message);
        }

        if (recordingState is RecordingLoaded) {
          print('📋 All recordings loaded: ${recordingState.recordings.length}');
          for (var rec in recordingState.recordings) {
            print('  - ${rec.name} (folder: ${rec.folderId})');
          }
          
          final recordings = recordingState.recordings
              .where((r) => r.folderId == folder.id)
              .toList();
          
          print('🎯 Filtered recordings for folder ${folder.id}: ${recordings.length}');

          if (recordings.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Folder title
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  folder.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              // Recordings list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  itemCount: recordings.length,
                  itemBuilder: (context, index) {
                    final recording = recordings[index];
                    final isExpanded = recordingState.expandedRecordingId == recording.id;

                    return _buildRecordingItem(context, recording, isExpanded, recordingState);
                  },
                ),
              ),
            ],
          );
        }

        // Default state
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mic_none,
                color: Colors.white54,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Loading recordings...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build individual recording item in iPhone style
  Widget _buildRecordingItem(BuildContext context, RecordingEntity recording, bool isExpanded, RecordingLoaded recordingState) {
    final hasTranscript = recording.name.contains('transcript') ||
        recording.name.toLowerCase().contains('gelat'); // Mock transcript detection

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(0), // iPhone style has sharp corners
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Main recording row
          InkWell(
            onTap: () => context.read<RecordingBloc>().add(
              ExpandRecording(recordingId: recording.id),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Selection circle (edit mode)
                  if (recordingState.isEditMode) ...[
                    GestureDetector(
                      onTap: () => context.read<RecordingBloc>().add(
                        ToggleRecordingSelection(recordingId: recording.id),
                      ),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: recordingState.selectedRecordings.contains(recording.id)
                                ? AppConstants.accentCyan
                                : Colors.grey[600]!,
                            width: 2,
                          ),
                          color: recordingState.selectedRecordings.contains(recording.id)
                              ? AppConstants.accentCyan
                              : Colors.transparent,
                        ),
                        child: recordingState.selectedRecordings.contains(recording.id)
                            ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Recording info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Recording title
                            Expanded(
                              child: Text(
                                recording.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Transcript icon
                            if (hasTranscript) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.text_snippet_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Date and duration
                        Row(
                          children: [
                            Text(
                              recording.createdAt.userFriendlyFormat,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Duration
                  Text(
                    recording.duration.recordingFormat,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Three-dot menu or expand indicator
                  if (!recordingState.isEditMode)
                    IconButton(
                      onPressed: () => _showRecordingMenu(context, recording),
                      icon: const Icon(
                        Icons.more_horiz,
                        color: AppConstants.accentCyan,
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Expanded audio player
          if (isExpanded)
            _buildExpandedPlayer(context, recording),
        ],
      ),
    );
  }

  /// Build expanded audio player section with safe BLoC access
  Widget _buildExpandedPlayer(BuildContext context, RecordingEntity recording) {
    // Try to get the AudioPlayerBloc, fallback to manual state if not available
    try {
      return BlocBuilder<AudioPlayerBloc, AudioPlayerState>(
        builder: (context, playerState) {
          return RecordingCard(
            recording: recording,
            playerState: playerState,
            onTogglePlayback: () => _togglePlayback(context, recording),
            onSkipBackward: () => _skipBackward(context, recording),
            onSkipForward: () => _skipForward(context, recording),
            onShowWaveform: () => _showWaveform(context, recording),
            onDelete: () => _deleteRecording(context, recording),
            onSeekToPosition: (position) => _seekToPosition(context, position),
          );
        },
      );
    } catch (e) {
      // Fallback to manual player controls if BLoC is not available
      debugPrint('AudioPlayerBloc not available: $e');
      return RecordingCard(
        recording: recording,
        playerState: null,
        onTogglePlayback: () => _togglePlayback(context, recording),
        onSkipBackward: () => _skipBackward(context, recording),
        onSkipForward: () => _skipForward(context, recording),
        onShowWaveform: () => _showWaveform(context, recording),
        onDelete: () => _deleteRecording(context, recording),
        onSeekToPosition: (position) => _seekToPosition(context, position),
      );
    }
  }


  /// Build error state
  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.read<RecordingBloc>().add(
              LoadRecordings(folderId: folder.id),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(color: AppConstants.accentCyan),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // Debug: Load ALL recordings to see what's in database
              print('🔍 DEBUG: Requesting all recordings...');
              context.read<RecordingBloc>().add(const DebugLoadAllRecordings());
            },
            child: const Text(
              'Debug: Show ALL',
              style: TextStyle(color: Colors.orange),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // Debug: Create a test recording
              print('🧪 DEBUG: Requesting test recording creation...');
              context.read<RecordingBloc>().add(DebugCreateTestRecording(folderId: folder.id));
            },
            child: const Text(
              'Debug: Add Test',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none,
            color: Colors.white54,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'No recordings yet',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the record button to create your first cosmic transmission',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  /// Show recording menu
  void _showRecordingMenu(BuildContext context, RecordingEntity recording) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Rename', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _renameRecording(context, recording);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Share', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _shareRecording(context, recording);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteRecording(context, recording);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Recording controls for bottom sheet
  void _toggleRecording(BuildContext context) {
    final recordingBloc = context.read<RecordingBloc>();
    if (recordingBloc.state.isRecording) {
      print('🛑 Stopping recording...');
      recordingBloc.add(const StopRecording());
    } else {
      print('🎤 Starting recording for folder: ${folder.id}');
      recordingBloc.add(StartRecording(
        folderId: folder.id,
        format: AudioFormat.m4a,
        sampleRate: 44100,
        bitRate: 128000,
      ));
    }
  }

  void _pauseRecording(BuildContext context) {
    context.read<RecordingBloc>().add(const PauseRecording());
  }

  void _finishRecording(BuildContext context) {
    context.read<RecordingBloc>().add(const StopRecording());
  }

  void _showTranscriptOptions(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transcript options coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }


  /// Audio control methods with safe BLoC access
  void _togglePlayback(BuildContext context, RecordingEntity recording) {
    try {
      final audioBloc = context.read<AudioPlayerBloc>();
      audioBloc.add(LoadAudioEvent(filePath: recording.filePath));
      audioBloc.add(const StartPlaybackEvent());
    } catch (e) {
      debugPrint('AudioPlayerBloc not available: $e');
      _showMessage(context, 'Audio playback not available');
    }
  }

  void _skipBackward(BuildContext context, RecordingEntity recording) {
    try {
      context.read<AudioPlayerBloc>().add(
        const SkipBackwardEvent(),
      );
    } catch (e) {
      debugPrint('AudioPlayerBloc not available: $e');
    }
  }

  void _skipForward(BuildContext context, RecordingEntity recording) {
    try {
      context.read<AudioPlayerBloc>().add(
        const SkipForwardEvent(),
      );
    } catch (e) {
      debugPrint('AudioPlayerBloc not available: $e');
    }
  }

  void _seekToPosition(BuildContext context, Duration position) {
    try {
      context.read<AudioPlayerBloc>().add(
        SeekToPositionEvent(position: position),
      );
    } catch (e) {
      debugPrint('AudioPlayerBloc not available: $e');
    }
  }

  /// Action methods
  void _showWaveform(BuildContext context, RecordingEntity recording) {
    debugPrint('Show waveform for: ${recording.name}');
  }

  void _renameRecording(BuildContext context, RecordingEntity recording) {
    debugPrint('Rename recording: ${recording.name}');
  }

  void _shareRecording(BuildContext context, RecordingEntity recording) {
    debugPrint('Share recording: ${recording.name}');
  }

  void _deleteRecording(BuildContext context, RecordingEntity recording) {
    try {
      context.read<RecordingBloc>().add(
        LoadRecordings(folderId: folder.id), // Refresh after delete
      );
    } catch (e) {
      debugPrint('RecordingBloc not available: $e');
      _showMessage(context, 'Delete functionality not available');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }
}