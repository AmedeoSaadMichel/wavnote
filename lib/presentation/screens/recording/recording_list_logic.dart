// File: presentation/screens/recording/recording_list_logic.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../../core/enums/audio_format.dart';
import '../../bloc/recording/recording_bloc.dart';
import '../../bloc/folder/folder_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../../services/permission/permission_service.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../widgets/dialogs/folder_selection_dialog.dart';

/// Mixin containing all business logic for RecordingListScreen
mixin RecordingListLogic<T extends StatefulWidget> on State<T> {
  FolderEntity get folder;
  BuildContext get context;

  // Audio player service access
  AudioPlayerService get audioPlayerService => AudioPlayerService.instance;
  int? _previousRecordingCount;
  Map<String, String> _folderNames = {};
  String _searchQuery = '';

  String get searchQuery => _searchQuery;

  void initializeRecordingList() {
    print(
      '🚀 VERBOSE: initializeRecordingList() called for folder: ${folder.id} (${folder.name})',
    );
    // ESSENTIAL: setState callback needed for expansion state changes

    // Only initialize if not already initialized
    if (!audioPlayerService.isServiceReady) {
      print('🔧 INIT: Service not ready, initializing...');
      audioPlayerService.initialize().then((_) {
        // Then set the expansion callback
        audioPlayerService.setExpansionCallback(() {
          print(
            '🔄 CALLBACK: _onExpansionChanged triggered, checking if mounted',
          );
          if (mounted) {
            print('🔄 CALLBACK: Widget is mounted, calling setState');
            setState(() {});
          } else {
            print('⚠️ CALLBACK: Widget is not mounted, skipping setState');
          }
        });
      });
    } else {
      print('✅ INIT: Service already ready, just setting expansion callback');
      // Service is already initialized, just set the callback
      audioPlayerService.setExpansionCallback(() {
        print(
          '🔄 CALLBACK: _onExpansionChanged triggered, checking if mounted',
        );
        if (mounted) {
          print('🔄 CALLBACK: Widget is mounted, calling setState');
          setState(() {});
        } else {
          print('⚠️ CALLBACK: Widget is not mounted, skipping setState');
        }
      });
    }

    _loadFolderNames();

    // OPTIMIZATION: Immediately trigger loading to skip RecordingInitial state
    // This reduces skeleton rebuilds from 2 to 1
    _triggerImmediateLoading();
  }

  /// OPTIMIZATION: Immediately trigger loading to bypass RecordingInitial state
  void _triggerImmediateLoading() {
    // ULTIMATE OPTIMIZATION: Load data immediately with duplicate prevention
    final recordingBloc = context.read<RecordingBloc>();

    // Check if we're loading recordings for the same folder to prevent duplicates
    final currentState = recordingBloc.state;
    if (currentState is RecordingLoaded) {
      // Check if the loaded recordings are for the current folder
      if (currentState.recordings.isNotEmpty &&
          _isRecordingsForCurrentFolder(currentState.recordings)) {
        print(
          '✅ OPTIMIZATION: Recordings already loaded for folder ${folder.id}, skipping duplicate',
        );
        return;
      }
    } else if (currentState is RecordingLoading) {
      print('✅ OPTIMIZATION: Recordings currently loading, skipping duplicate');
      return;
    }

    // CRITICAL: Single immediate load to eliminate all RecordingInitial states
    print('🚀 ULTIMATE: Single immediate load for folder ${folder.id}');
    recordingBloc.add(LoadRecordings(folderId: folder.id));

    // Handle permissions asynchronously but don't wait for them
    _ensurePermissionsAsync();
  }

  /// Check if the loaded recordings are for the current folder
  bool _isRecordingsForCurrentFolder(List<RecordingEntity> recordings) {
    if (recordings.isEmpty) return false;

    // For special folders like "all_recordings" and "favourites", we can't check by folderId
    // since recordings might be from different folders
    if (folder.id == 'all_recordings' || folder.id == 'favourites') {
      // For these special folders, we assume they need to be reloaded each time
      // to ensure we get the latest state
      return false;
    }

    // For regular folders, check if all recordings belong to the current folder
    return recordings.every((recording) => recording.folderId == folder.id);
  }

  /// Handle permissions asynchronously without blocking the UI
  void _ensurePermissionsAsync() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        print('🔐 BACKGROUND: Checking permissions...');
        final hasPermission = await PermissionService.hasMicrophonePermission();

        if (!hasPermission) {
          print('🔐 BACKGROUND: Requesting microphone permission...');
          final result = await PermissionService.requestMicrophonePermission();
          if (!result.isGranted) {
            print('❌ BACKGROUND: Permission denied');
            // Could show a permission dialog here
            return;
          }
          print('✅ BACKGROUND: Permission granted');
        }

        // Also ensure location permissions are requested proactively
        print('📍 BACKGROUND: Checking location permission...');
        try {
          // Since we can't easily access the GeolocationService here without
          // adding a new import, the fix in GeolocationService.getCurrentAddress()
          // will naturally prompt when the user records for the first time.
        } catch (e) {
          print('❌ BACKGROUND: Error checking location permission: $e');
        }
      } catch (e) {
        print('❌ BACKGROUND: Error in permission handling: $e');
      }
    });
  }

  /// Handle permissions at infrastructure level, separate from data flow
  Future<void> _ensurePermissionsAndLoadRecordings() async {
    if (!mounted) return;

    print('🔐 ARCHITECTURE: Ensuring permissions before loading data');

    try {
      // Use PermissionService directly - clean separation from BLoC
      print('🔐 Checking microphone permission...');
      final hasPermission = await PermissionService.hasMicrophonePermission();
      print('🔐 Permission check result: $hasPermission');

      if (!hasPermission) {
        print('🔐 Requesting microphone permission...');
        final result = await PermissionService.requestMicrophonePermission();
        if (!result.isGranted) {
          print('❌ Permission denied - cannot load recordings');
          // Could show a permission dialog here
          return;
        }
        print('✅ Permission granted');
      }

      // Clean data flow: Initial → Loading → Loaded (no permission states)
      print('🚀 CLEAN FLOW: Loading recordings for folder: ${folder.id}');
      context.read<RecordingBloc>().add(LoadRecordings(folderId: folder.id));
    } catch (e) {
      print('❌ Error in permission handling: $e');
      // Fallback: try loading anyway
      context.read<RecordingBloc>().add(LoadRecordings(folderId: folder.id));
    }
  }

  void _loadFolderNames() {
    final folderBloc = context.read<FolderBloc>();
    final folderState = folderBloc.state;

    if (folderState is FolderLoaded) {
      final Map<String, String> names = {};

      for (final folder in folderState.defaultFolders) {
        names[folder.id] = folder.name;
      }

      for (final folder in folderState.customFolders) {
        names[folder.id] = folder.name;
      }

      if (mounted) {
        setState(() {
          _folderNames = names;
        });
      }

      print('📋 Loaded ${names.length} folder names for tags');
    }
  }

  Map<String, String> get folderNames => _folderNames;

  // Search functionality
  void updateSearchQuery(String query) {
    if (mounted) {
      setState(() {
        _searchQuery = query.toLowerCase().trim();
      });
    }
  }

  List<RecordingEntity> filterRecordings(List<RecordingEntity> recordings) {
    if (_searchQuery.isEmpty) {
      return recordings;
    }

    return recordings.where((recording) {
      final name = recording.name.toLowerCase();
      final folderName = _folderNames[recording.folderId]?.toLowerCase() ?? '';

      // Search in recording name and folder name
      return name.contains(_searchQuery) || folderName.contains(_searchQuery);
    }).toList();
  }

  void handleRecordingStateChange(RecordingState state) {
    if (state is RecordingCompleted) {
      print(
        '🎉 RecordingCompleted event received! Recording: ${state.recording.name}',
      );
      print('🔄 Refreshing recordings list for folder: ${folder.id}');
      context.read<RecordingBloc>().add(LoadRecordings(folderId: folder.id));
    } else if (state is RecordingLoaded) {
      final currentCount = state.recordings.length;
      if (_previousRecordingCount != null &&
          currentCount < _previousRecordingCount!) {
        print(
          '🔄 Recording count decreased, will refresh folders when navigating back',
        );
      }
      _previousRecordingCount = currentCount;

      // Ensure audio service expansion state is synced with current recordings
      final expandedRecording = audioPlayerService
          .getCurrentlyExpandedRecording(state.recordings);
      if (audioPlayerService.expandedRecordingId != null &&
          expandedRecording == null) {
        print(
          '⚠️ Expanded recording not found in current list, resetting audio service state',
        );
        audioPlayerService.resetExpansionState();
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
  }

  // Audio player management
  Future<void> expandRecording(RecordingEntity recording) async {
    print('🎯 EXPAND: expandRecording called for: ${recording.name}');
    try {
      await audioPlayerService.expandRecording(recording);
      print(
        '🎯 EXPAND: Successfully called audioPlayerService.expandRecording',
      );
    } catch (e) {
      print('🎯 EXPAND: Error in expandRecording: $e');
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

  Future<void> togglePlayback() async {
    await audioPlayerService.togglePlayback();
  }

  void seekToPosition(double percent) {
    audioPlayerService.seekToPosition(percent);
  }

  RecordingEntity? getExpandedRecording() {
    final recordingBloc = context.read<RecordingBloc>();
    final state = recordingBloc.state;
    if (state is RecordingLoaded) {
      return audioPlayerService.getCurrentlyExpandedRecording(state.recordings);
    }
    return null;
  }

  void skipBackward() {
    audioPlayerService.skipBackward();
  }

  void skipForward() {
    audioPlayerService.skipForward();
  }

  // Recording actions
  Future<void> deleteRecording(RecordingEntity recording) async {
    if (audioPlayerService.expandedRecordingId == recording.id) {
      await audioPlayerService.stopPlaying();
      if (mounted) {
        setState(() {});
      }
    }

    if (folder.id == 'recently_deleted') {
      context.read<RecordingBloc>().add(PermanentDeleteRecording(recording.id));
    } else {
      context.read<RecordingBloc>().add(SoftDeleteRecording(recording.id));
    }
  }

  void moveRecordingToFolder(RecordingEntity recording) {
    print('📁 Move to folder tapped for: ${recording.name}');
    _showFolderSelectionDialog(recording);
  }

  void _showFolderSelectionDialog(RecordingEntity recording) {
    print(
      '📁 Opening folder selection dialog for recording "${recording.name}"',
    );
    print('📁 Recording is currently in folder: ${recording.folderId}');
    print('📁 User is viewing folder: ${folder.id}');

    // Check if folders are loaded
    final folderBloc = context.read<FolderBloc>();
    final folderState = folderBloc.state;

    if (folderState is! FolderLoaded) {
      print('⚠️ Folders not loaded yet, loading folders first');
      folderBloc.add(const LoadFolders());
      // Show loading indicator or return early
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading folders...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    print('📁 Found ${folderState.allFolders.length} total folders');

    showDialog(
      context: context,
      builder: (context) => FolderSelectionDialog(
        currentFolderId: recording.folderId,
        title: 'Move Recording',
        subtitle: 'Select a folder for "${recording.name}"',
        isRecordingAlreadyFavorite: recording.isFavorite,
        onFolderSelected: (folderId) {
          print('📁 Moving recording ${recording.id} to folder $folderId');

          // Handle special folders differently
          if (folderId == 'favourites') {
            // For Favorites, we want to ADD to favorites (not toggle)
            print('💖 Adding recording to favorites instead of moving folder');

            // Only add to favorites if not already a favorite
            if (!recording.isFavorite) {
              // Pure BLoC: Just trigger the database toggle
              context.read<RecordingBloc>().add(
                ToggleFavoriteRecording(recordingId: recording.id),
              );
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added "${recording.name}" to Favorites'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            // For regular folders, do the actual move
            context.read<RecordingBloc>().add(
              MoveRecordingToFolder(
                recordingId: recording.id,
                targetFolderId: folderId,
                currentFolderId: folder.id,
              ),
            );

            // Reload the current folder to reflect the change
            print('🔄 Reloading folder ${folder.id} after regular move');
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                context.read<RecordingBloc>().add(
                  LoadRecordings(folderId: folder.id),
                );
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Moved "${recording.name}" to ${_folderNames[folderId] ?? 'selected folder'}',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  void showMoreActions(RecordingEntity recording) {
    print('⚙️ More actions tapped for: ${recording.name}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('More actions - ${recording.name}'),
        backgroundColor: Colors.grey[600],
      ),
    );
  }

  void restoreRecording(RecordingEntity recording) {
    print('♻️ Restore tapped for: ${recording.name}');

    if (audioPlayerService.expandedRecordingId == recording.id) {
      audioPlayerService.stopPlaying();
      if (mounted) {
        setState(() {});
      }
    }

    context.read<RecordingBloc>().add(RestoreRecording(recording.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restored "${recording.name}"'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            context.read<RecordingBloc>().add(
              SoftDeleteRecording(recording.id),
            );
          },
        ),
      ),
    );
  }

  void toggleFavoriteRecording(RecordingEntity recording) {
    print('❤️ UI LOGIC: Toggle favorite for: ${recording.name}');
    print('🔍 UI LOGIC: Current favorite status: ${recording.isFavorite}');
    print('🔍 UI LOGIC: Recording ID: ${recording.id}');

    // Pure BLoC: Just trigger the database toggle, let BLoC handle UI update
    context.read<RecordingBloc>().add(
      ToggleFavoriteRecording(recordingId: recording.id),
    );

    final isFavorite = recording.isFavorite;
    print('🔍 UI LOGIC: Showing snackbar based on current status: $isFavorite');
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

  // Recording control
  void toggleRecording() {
    print('🎤 Toggle recording called');
    final recordingBloc = context.read<RecordingBloc>();
    final currentState = recordingBloc.state;

    print('📍 Current recording state: ${currentState.runtimeType}');
    print('📍 Can start recording: ${currentState.canStartRecording}');
    print('📍 Can stop recording: ${currentState.canStopRecording}');
    print('📍 Can resume recording: ${currentState.canResumeRecording}');

    if (currentState.canStartRecording) {
      print('🚀 Starting recording...');

      AudioFormat selectedFormat = AudioFormat.m4a;
      final settingsBloc = context.read<SettingsBloc>();
      final settingsState = settingsBloc.state;

      if (settingsState is SettingsLoaded) {
        selectedFormat = settingsState.settings.audioFormat;
        print('🎵 Using format from settings: ${selectedFormat.name}');
      } else {
        print(
          '⚠️ Settings not loaded, using default format: ${selectedFormat.name}',
        );
      }

      recordingBloc.add(
        StartRecording(
          folderId: folder.id,
          folderName: folder.name,
          format: selectedFormat,
        ),
      );
    } else if (currentState.canResumeRecording) {
      print('▶️ Resuming recording from paused state...');
      resumeRecording();
    } else if (currentState.canStopRecording) {
      print('🛑 Stopping recording - waveform will be extracted from file...');
      recordingBloc.add(const StopRecording());
    } else {
      print(
        '❌ Cannot start or stop recording in current state: ${currentState.runtimeType}',
      );
    }
  }

  void pauseRecording() {
    final recordingBloc = context.read<RecordingBloc>();
    print(
      '⏸️ Pause button clicked - Current state: ${recordingBloc.state.runtimeType}',
    );
    print('   canPauseRecording: ${recordingBloc.state.canPauseRecording}');
    print('   canResumeRecording: ${recordingBloc.state.canResumeRecording}');

    if (recordingBloc.state.canPauseRecording) {
      print('   ✅ Calling PauseRecording event');
      recordingBloc.add(const PauseRecording());
    } else if (recordingBloc.state.canResumeRecording) {
      print('   ✅ Calling ResumeRecording event');
      recordingBloc.add(const ResumeRecording());
    } else {
      print('   ❌ Cannot pause or resume - invalid state');
    }
  }

  void finishRecording() {
    final recordingBloc = context.read<RecordingBloc>();
    print(
      '🎵 Finishing recording - Current state: ${recordingBloc.state.runtimeType}',
    );
    print('   isRecording: ${recordingBloc.state.isRecording}');
    print(
      '   canStopRecording: ${recordingBloc.state is RecordingInProgress || recordingBloc.state is RecordingPaused}',
    );

    context.read<RecordingBloc>().add(
      const StopRecording(),
    ); // No synthetic waveform data
  }

  void showTranscriptOptions() {
    print('🎤 Transcript options tapped');
  }

  /// Riprende la registrazione dal punto di pausa (bottone pupilla).
  void resumeRecording() {
    print('▶️ Resume recording tapped');
    final recordingBloc = context.read<RecordingBloc>();
    if (recordingBloc.state.canResumeRecording) {
      recordingBloc.add(const ResumeRecording());
    }
  }

  /// Avvia il playback di anteprima dalla posizione corrente della seek bar (BLoC state).
  void playRecordingPreview() {
    final bloc = context.read<RecordingBloc>();
    if (bloc.state is RecordingPaused) {
      bloc.add(const PlayRecordingPreview());
    }
  }

  /// Aggiorna la posizione della seek bar nello stato BLoC.
  void updateSeekBarIndex(int index) {
    final bloc = context.read<RecordingBloc>();
    if (bloc.state is RecordingPaused) {
      bloc.add(UpdateSeekBarIndex(seekBarIndex: index));
    }
  }

  /// Ferma il playback di anteprima e torna a RecordingPaused puro.
  void stopRecordingPreview() {
    print('⏹ Stop preview');
    final bloc = context.read<RecordingBloc>();
    if (bloc.state is RecordingPaused) {
      bloc.add(const StopRecordingPreview());
    }
  }

  void rewindRecording() {
    print('⏪ Rewind 10 seconds tapped');
    // TODO: Implement rewind 10 seconds
  }

  void forwardRecording() {
    print('⏩ Forward 10 seconds tapped');
    // TODO: Implement forward 10 seconds
  }

  void seekRecording(double position) {
    print('🎯 Seek to position: ${(position * 100).toStringAsFixed(1)}%');
    // TODO: Implement seek to position (0.0-1.0)
  }

  void deleteSelectedRecordings() {
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
            child: const Text('Cancel', style: TextStyle(color: Colors.cyan)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              recordingBloc.add(DeleteSelectedRecordings(folderId: folder.id));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void moveSelectedRecordings() {
    final recordingBloc = context.read<RecordingBloc>();
    final state = recordingBloc.state;

    if (state is! RecordingLoaded) return;

    final selectedCount = state.selectedRecordings.length;
    if (selectedCount == 0) return;

    _showBulkFolderSelectionDialog(selectedCount);
  }

  void _showBulkFolderSelectionDialog(int selectedCount) {
    print(
      '📁 Opening bulk folder selection dialog for $selectedCount recordings',
    );
    print('📁 User is viewing folder: ${folder.id}');

    // Check if folders are loaded
    final folderBloc = context.read<FolderBloc>();
    final folderState = folderBloc.state;

    if (folderState is! FolderLoaded) {
      print('⚠️ Folders not loaded yet, loading folders first');
      folderBloc.add(const LoadFolders());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading folders...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Check if all selected recordings are already favorites
    final recordingBloc = context.read<RecordingBloc>();
    final recordingState = recordingBloc.state;
    bool allSelectedAreFavorites = false;

    if (recordingState is RecordingLoaded) {
      final selectedRecordings = recordingState.recordings
          .where((r) => recordingState.selectedRecordings.contains(r.id))
          .toList();
      allSelectedAreFavorites =
          selectedRecordings.isNotEmpty &&
          selectedRecordings.every((r) => r.isFavorite);
      print(
        '📁 All selected recordings are favorites: $allSelectedAreFavorites',
      );
    }

    showDialog(
      context: context,
      builder: (context) => FolderSelectionDialog(
        currentFolderId: folder.id,
        title: 'Move Recordings',
        subtitle:
            'Select a folder for $selectedCount recording${selectedCount > 1 ? 's' : ''}',
        isRecordingAlreadyFavorite: allSelectedAreFavorites,
        onFolderSelected: (folderId) {
          print(
            '📁 Moving $selectedCount selected recordings to folder $folderId',
          );

          // Handle special folders differently
          if (folderId == 'favourites') {
            // For Favorites, we need to toggle favorite for all selected recordings
            print(
              '💖 Adding $selectedCount recordings to favorites instead of moving folder',
            );

            // Get selected recording IDs
            final recordingBloc = context.read<RecordingBloc>();
            final state = recordingBloc.state;

            if (state is RecordingLoaded) {
              // Filter to only recordings that are not already favorites
              final recordingsToFavorite = state.recordings
                  .where(
                    (r) =>
                        state.selectedRecordings.contains(r.id) &&
                        !r.isFavorite,
                  )
                  .map((r) => r.id)
                  .toList();

              if (recordingsToFavorite.isNotEmpty) {
                // Pure BLoC: Just trigger the database updates
                for (final recordingId in recordingsToFavorite) {
                  recordingBloc.add(
                    ToggleFavoriteRecording(recordingId: recordingId),
                  );
                }
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Added $selectedCount recording${selectedCount > 1 ? 's' : ''} to Favorites',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            // For regular folders, do the actual move
            context.read<RecordingBloc>().add(
              MoveSelectedRecordingsToFolder(
                targetFolderId: folderId,
                currentFolderId: folder.id,
              ),
            );

            // Reload the current folder to reflect the changes
            print('🔄 Reloading folder ${folder.id} after bulk move');
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                context.read<RecordingBloc>().add(
                  LoadRecordings(folderId: folder.id),
                );
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Moved $selectedCount recording${selectedCount > 1 ? 's' : ''} to ${_folderNames[folderId] ?? 'selected folder'}',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }
}
