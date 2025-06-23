// File: presentation/screens/recording/recording_list_screen.dart

// Dart packages
import 'dart:async';

// Flutter packages
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Domain
import '../../../domain/entities/folder_entity.dart';
import '../../../domain/entities/recording_entity.dart';

// Presentation
import '../../bloc/recording/recording_bloc.dart';
import '../../bloc/folder/folder_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../widgets/recording/recording_bottom_sheet.dart';
import '../../widgets/recording/recording_card.dart';
import 'audio_player_manager.dart';

// Core
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/audio_format.dart';

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

class _RecordingListScreenState extends State<RecordingListScreen> {
  // ============================================================================
  // PROPERTIES
  // ============================================================================
  
  // Audio player manager - handles all audio playback logic
  final AudioPlayerManager _audioPlayerManager = AudioPlayerManager();
  
  // Track recording count for folder refresh detection
  int? _previousRecordingCount;
  
  // Folder names for tag display
  Map<String, String> _folderNames = {};

  // ============================================================================
  // LIFECYCLE METHODS
  // ============================================================================

  @override
  void initState() {
    super.initState();
    _audioPlayerManager.initialize(() => setState(() {}));
    _loadFolderNames();
    
    // Load recordings and check permissions on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🚀 Loading recordings for folder: ${widget.folder.id}');
      context.read<RecordingBloc>().add(LoadRecordings(folderId: widget.folder.id));
      
      // Check recording permissions
      print('🔍 Checking recording permissions');
      context.read<RecordingBloc>().add(const CheckRecordingPermissions());
    });
  }

  /// Load folder names for tag display
  void _loadFolderNames() {
    final folderBloc = context.read<FolderBloc>();
    final folderState = folderBloc.state;
    
    if (folderState is FolderLoaded) {
      final Map<String, String> names = {};
      
      // Add default folders
      for (final folder in folderState.defaultFolders) {
        names[folder.id] = folder.name;
      }
      
      // Add custom folders
      for (final folder in folderState.customFolders) {
        names[folder.id] = folder.name;
      }
      
      setState(() {
        _folderNames = names;
      });
      
      print('📋 Loaded ${names.length} folder names for tags');
    }
  }

  @override
  void dispose() {
    _audioPlayerManager.dispose();
    super.dispose();
  }

  // ============================================================================
  // AUDIO PLAYER MANAGEMENT (Delegated to AudioPlayerManager)
  // ============================================================================

  /// Expand/collapse recording - delegated to AudioPlayerManager
  Future<void> _expandRecording(RecordingEntity recording) async {
    try {
      await _audioPlayerManager.expandRecording(recording);
    } catch (e) {
      // Show user-friendly error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play recording: ${recording.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Toggle playback - delegated to AudioPlayerManager
  Future<void> _togglePlayback() async {
    await _audioPlayerManager.togglePlayback();
  }

  /// Seek to position - delegated to AudioPlayerManager
  void _seekToPosition(double percent) {
    _audioPlayerManager.seekToPosition(percent);
  }

  /// Get the currently expanded recording - delegated to AudioPlayerManager
  RecordingEntity? _getExpandedRecording() {
    final recordingBloc = context.read<RecordingBloc>();
    final state = recordingBloc.state;
    if (state is RecordingLoaded) {
      return _audioPlayerManager.getCurrentlyExpandedRecording(state.recordings);
    }
    return null;
  }

  /// Skip backward - delegated to AudioPlayerManager
  void _skipBackward() {
    _audioPlayerManager.skipBackward();
  }

  /// Skip forward - delegated to AudioPlayerManager
  void _skipForward() {
    _audioPlayerManager.skipForward();
  }

  /// Delete recording (soft delete or permanent delete based on folder)
  Future<void> _deleteRecording(RecordingEntity recording) async {
    // Stop playback if deleting current recording
    if (_audioPlayerManager.expandedRecordingId == recording.id) {
      await _audioPlayerManager.audioPlayer.stop();
      setState(() {});
    }

    // Use different delete logic based on current folder
    if (widget.folder.id == 'recently_deleted') {
      // Permanent delete from Recently Deleted folder
      context.read<RecordingBloc>().add(PermanentDeleteRecording(recording.id));
    } else {
      // Soft delete from any other folder (moves to Recently Deleted)
      context.read<RecordingBloc>().add(SoftDeleteRecording(recording.id));
    }
  }

  // ============================================================================
  // BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<RecordingBloc, RecordingState>(
          listener: (context, state) {
            if (state is RecordingCompleted) {
              print('🎉 RecordingCompleted event received! Recording: ${state.recording.name}');
              print('🔄 Refreshing recordings list for folder: ${widget.folder.id}');
              // Refresh recordings list
              context.read<RecordingBloc>().add(LoadRecordings(folderId: widget.folder.id));
            } else if (state is RecordingLoaded) {
              // Check if recording count decreased (recording deleted)
              final currentCount = state.recordings.length;
              if (_previousRecordingCount != null && currentCount < _previousRecordingCount!) {
                print('🔄 Recording count decreased, will refresh folders when navigating back');
                // We'll refresh folders when we navigate back to main screen
              }
              _previousRecordingCount = currentCount;
            } else if (state is RecordingPermissionStatus) {
              print('🔐 Permission status: canRecord=${state.canRecord}');
              if (!state.canRecord) {
                print('🔐 Requesting microphone permission...');
                context.read<RecordingBloc>().add(const RequestRecordingPermissions());
              }
            } else if (state is RecordingError) {
              print('❌ Recording error: ${state.message}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Recording error: ${state.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
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
                    _buildHeader(context),
                    _buildEditModeToolbar(context),
                    Expanded(
                      child: _buildRecordingsList(context),
                    ),
                    const SizedBox(height: 200),
                  ],
                ),
                // Only show recording bottom sheet if NOT in Recently Deleted folder
                if (widget.folder.id != 'recently_deleted') _buildRecordingBottomSheet(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build header
  Widget _buildHeader(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, recordingState) {
        final isEditMode = recordingState is RecordingLoaded ? recordingState.isEditMode : false;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: AppConstants.accentCyan,
                  size: 24,
                ),
              ),
              Expanded(
                child: Text(
                  widget.folder.name,
                  style: const TextStyle(
                    color: AppConstants.accentYellow,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.read<RecordingBloc>().add(const ToggleEditMode());
                },
                child: Text(
                  isEditMode ? 'Done' : 'Edit',
                  style: const TextStyle(
                    color: AppConstants.accentCyan,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build edit mode toolbar
  Widget _buildEditModeToolbar(BuildContext context) {
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, state) {
        if (state is! RecordingLoaded || !state.isEditMode) {
          return const SizedBox.shrink();
        }

        final selectedCount = state.selectedRecordings.length;
        final totalCount = state.recordings.length;
        final allSelected = selectedCount == totalCount && totalCount > 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(
              bottom: BorderSide(color: Colors.grey[700]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Select All / Deselect All button
              TextButton(
                onPressed: () {
                  if (allSelected) {
                    context.read<RecordingBloc>().add(const DeselectAllRecordings());
                  } else {
                    context.read<RecordingBloc>().add(const SelectAllRecordings());
                  }
                },
                child: Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: const TextStyle(
                    color: AppConstants.accentCyan,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              // Selection count
              Text(
                '$selectedCount selected',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 16),
              // Delete selected button
              IconButton(
                onPressed: selectedCount > 0 ? () => _deleteSelectedRecordings(context) : null,
                icon: Icon(
                  Icons.delete,
                  color: selectedCount > 0 ? Colors.red : Colors.grey[600],
                  size: 24,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Delete selected recordings with confirmation
  void _deleteSelectedRecordings(BuildContext context) {
    final recordingBloc = context.read<RecordingBloc>();
    final state = recordingBloc.state;
    
    if (state is! RecordingLoaded) return;
    
    final selectedCount = state.selectedRecordings.length;
    if (selectedCount == 0) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Delete Recordings',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete $selectedCount recording${selectedCount > 1 ? 's' : ''}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppConstants.accentCyan),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              recordingBloc.add(DeleteSelectedRecordings(folderId: widget.folder.id));
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
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

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: state.recordings.length,
            itemBuilder: (context, index) {
              final recording = state.recordings[index];
              final isExpanded = _audioPlayerManager.expandedRecordingId == recording.id;
              print('📦 Building card for: ${recording.name}');
              print('⏱ Duration: ${recording.duration.inMilliseconds}ms');
              print('▶️ Current position: ${_audioPlayerManager.position.inMilliseconds}ms');
              return RecordingCard(
                recording: recording,
                isExpanded: isExpanded,
                onTap: () => _expandRecording(recording),
                onShowWaveform: () {}, // TODO: Implement if needed
                onDelete: () => _deleteRecording(recording),
                onMoveToFolder: () => _moveRecordingToFolder(recording),
                onMoreActions: () => _showMoreActions(recording),
                onRestore: () => _restoreRecording(recording),
                onToggleFavorite: () => _toggleFavoriteRecording(recording),
                // Audio state passed from screen
                isPlaying: isExpanded ? _audioPlayerManager.isPlaying : false,
                isLoading: isExpanded ? _audioPlayerManager.isLoading : false,
                currentPosition: isExpanded ? _audioPlayerManager.position : Duration.zero,
                // Audio control callbacks
                onPlayPause: _togglePlayback,
                onSeek: _seekToPosition,
                onSkipBackward: _skipBackward,
                onSkipForward: _skipForward,
                // Tag display context
                currentFolderId: widget.folder.id,
                folderNames: _folderNames,
                // Selection state
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
          onToggle: () {
            print('🔘 Bottom sheet toggle button pressed');
            _toggleRecording(context);
          },
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
    );
  }

  // ============================================================================
  // RECORDING CONTROL METHODS
  // ============================================================================

  void _toggleRecording(BuildContext context) {
    print('🎤 Toggle recording called');
    final recordingBloc = context.read<RecordingBloc>();
    final currentState = recordingBloc.state;
    
    print('📍 Current recording state: ${currentState.runtimeType}');
    print('📍 Can start recording: ${currentState.canStartRecording}');
    print('📍 Can stop recording: ${currentState.canStopRecording}');

    if (currentState.canStartRecording) {
      print('🚀 Starting recording...');
      
      // Get format from settings
      AudioFormat selectedFormat = AudioFormat.m4a; // Default fallback
      final settingsBloc = context.read<SettingsBloc>();
      final settingsState = settingsBloc.state;
      
      if (settingsState is SettingsLoaded) {
        selectedFormat = settingsState.settings.audioFormat;
        print('🎵 Using format from settings: ${selectedFormat.name}');
      } else {
        print('⚠️ Settings not loaded, using default format: ${selectedFormat.name}');
      }
      
      recordingBloc.add(StartRecording(
        folderId: widget.folder.id,
        folderName: widget.folder.name,
        format: selectedFormat,
      ));
    } else if (currentState.canStopRecording) {
      print('🛑 Stopping recording...');
      recordingBloc.add(const StopRecording());
    } else {
      print('❌ Cannot start or stop recording in current state: ${currentState.runtimeType}');
    }
  }

  void _pauseRecording(BuildContext context) {
    final recordingBloc = context.read<RecordingBloc>();
    if (recordingBloc.state.canPauseRecording) {
      recordingBloc.add(const PauseRecording());
    } else if (recordingBloc.state.canResumeRecording) {
      recordingBloc.add(const ResumeRecording());
    }
  }

  void _finishRecording(BuildContext context) {
    context.read<RecordingBloc>().add(const StopRecording());
  }

  void _showTranscriptOptions(BuildContext context) {
    // TODO: Implement transcript options
    print('🎤 Transcript options tapped');
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Move recording to another folder
  void _moveRecordingToFolder(RecordingEntity recording) {
    print('📁 Move to folder tapped for: ${recording.name}');
    // TODO: Show folder selection dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Move to folder - ${recording.name}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  /// Show more actions for recording
  void _showMoreActions(RecordingEntity recording) {
    print('⚙️ More actions tapped for: ${recording.name}');
    // TODO: Show more actions dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('More actions - ${recording.name}'),
        backgroundColor: Colors.grey[600],
      ),
    );
  }

  /// Restore recording from Recently Deleted folder
  void _restoreRecording(RecordingEntity recording) {
    print('♻️ Restore tapped for: ${recording.name}');
    
    // Stop playback if restoring current recording
    if (_audioPlayerManager.expandedRecordingId == recording.id) {
      _audioPlayerManager.audioPlayer.stop();
      setState(() {});
    }

    // Restore the recording
    context.read<RecordingBloc>().add(RestoreRecording(recording.id));
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restored "${recording.name}"'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            // Re-soft delete the recording
            context.read<RecordingBloc>().add(SoftDeleteRecording(recording.id));
          },
        ),
      ),
    );
  }

  /// Toggle favorite status of recording
  void _toggleFavoriteRecording(RecordingEntity recording) {
    print('❤️ Toggle favorite for: ${recording.name}');
    
    // Toggle favorite status
    context.read<RecordingBloc>().add(ToggleFavoriteRecording(recordingId: recording.id));
    
    // Show feedback
    final isFavorite = recording.isFavorite;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite 
              ? 'Removed "${recording.name}" from favorites'
              : 'Added "${recording.name}" to favorites',
        ),
        backgroundColor: isFavorite ? Colors.grey[600] : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

}