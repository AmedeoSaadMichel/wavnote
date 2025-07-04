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
    print('🚀 VERBOSE: initializeRecordingList() called for folder: ${folder.id} (${folder.name})');
    // ESSENTIAL: setState callback needed for expansion state changes
    
    // Only initialize if not already initialized
    if (!audioPlayerService.isServiceReady) {
      print('🔧 INIT: Service not ready, initializing...');
      audioPlayerService.initialize().then((_) {
        // Then set the expansion callback
        audioPlayerService.setExpansionCallback(() {
          print('🔄 CALLBACK: _onExpansionChanged triggered, calling setState');
          setState(() {});
        });
      });
    } else {
      print('✅ INIT: Service already ready, just setting expansion callback');
      // Service is already initialized, just set the callback
      audioPlayerService.setExpansionCallback(() {
        print('🔄 CALLBACK: _onExpansionChanged triggered, calling setState');
        setState(() {});
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
    
    // Check if already loaded or loading to prevent duplicates
    if (recordingBloc.state is RecordingLoaded || recordingBloc.state is RecordingLoading) {
      print('✅ OPTIMIZATION: Data already loaded/loading, skipping duplicate');
      return;
    }
    
    // CRITICAL: Single immediate load to eliminate all RecordingInitial states
    print('🚀 ULTIMATE: Single immediate load for folder ${folder.id}');
    recordingBloc.add(LoadRecordings(folderId: folder.id));
    
    // Handle permissions asynchronously but don't wait for them
    _ensurePermissionsAsync();
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
      
      setState(() {
        _folderNames = names;
      });
      
      print('📋 Loaded ${names.length} folder names for tags');
    }
  }

  Map<String, String> get folderNames => _folderNames;

  // Search functionality
  void updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
    });
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
      print('🎉 RecordingCompleted event received! Recording: ${state.recording.name}');
      print('🔄 Refreshing recordings list for folder: ${folder.id}');
      context.read<RecordingBloc>().add(LoadRecordings(folderId: folder.id));
    } else if (state is RecordingLoaded) {
      final currentCount = state.recordings.length;
      if (_previousRecordingCount != null && currentCount < _previousRecordingCount!) {
        print('🔄 Recording count decreased, will refresh folders when navigating back');
      }
      _previousRecordingCount = currentCount;
      
      // Ensure audio service expansion state is synced with current recordings
      final expandedRecording = audioPlayerService.getCurrentlyExpandedRecording(state.recordings);
      if (audioPlayerService.expandedRecordingId != null && expandedRecording == null) {
        print('⚠️ Expanded recording not found in current list, resetting audio service state');
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
      print('🎯 EXPAND: Successfully called audioPlayerService.expandRecording');
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
      setState(() {});
    }

    if (folder.id == 'recently_deleted') {
      context.read<RecordingBloc>().add(PermanentDeleteRecording(recording.id));
    } else {
      context.read<RecordingBloc>().add(SoftDeleteRecording(recording.id));
    }
  }

  void moveRecordingToFolder(RecordingEntity recording) {
    print('📁 Move to folder tapped for: ${recording.name}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Move to folder - ${recording.name}'),
        backgroundColor: Colors.blue,
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
      setState(() {});
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
            context.read<RecordingBloc>().add(SoftDeleteRecording(recording.id));
          },
        ),
      ),
    );
  }

  void toggleFavoriteRecording(RecordingEntity recording) {
    print('❤️ Toggle favorite for: ${recording.name}');
    
    context.read<RecordingBloc>().add(ToggleFavoriteRecording(recordingId: recording.id));
    
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

  // Recording control
  void toggleRecording() {
    print('🎤 Toggle recording called');
    final recordingBloc = context.read<RecordingBloc>();
    final currentState = recordingBloc.state;
    
    print('📍 Current recording state: ${currentState.runtimeType}');
    print('📍 Can start recording: ${currentState.canStartRecording}');
    print('📍 Can stop recording: ${currentState.canStopRecording}');

    if (currentState.canStartRecording) {
      print('🚀 Starting recording...');
      
      AudioFormat selectedFormat = AudioFormat.m4a;
      final settingsBloc = context.read<SettingsBloc>();
      final settingsState = settingsBloc.state;
      
      if (settingsState is SettingsLoaded) {
        selectedFormat = settingsState.settings.audioFormat;
        print('🎵 Using format from settings: ${selectedFormat.name}');
      } else {
        print('⚠️ Settings not loaded, using default format: ${selectedFormat.name}');
      }
      
      recordingBloc.add(StartRecording(
        folderId: folder.id,
        folderName: folder.name,
        format: selectedFormat,
      ));
    } else if (currentState.canStopRecording) {
      print('🛑 Stopping recording - waveform will be extracted from file...');
      recordingBloc.add(const StopRecording()); // No synthetic waveform data
    } else {
      print('❌ Cannot start or stop recording in current state: ${currentState.runtimeType}');
    }
  }

  void pauseRecording() {
    final recordingBloc = context.read<RecordingBloc>();
    if (recordingBloc.state.canPauseRecording) {
      recordingBloc.add(const PauseRecording());
    } else if (recordingBloc.state.canResumeRecording) {
      recordingBloc.add(const ResumeRecording());
    }
  }

  void finishRecording() {
    print('🎵 Finishing recording - waveform will be extracted from file...');
    context.read<RecordingBloc>().add(const StopRecording()); // No synthetic waveform data
  }

  void showTranscriptOptions() {
    print('🎤 Transcript options tapped');
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.cyan),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              recordingBloc.add(DeleteSelectedRecordings(folderId: folder.id));
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
}