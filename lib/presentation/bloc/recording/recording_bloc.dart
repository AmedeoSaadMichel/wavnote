// File: presentation/bloc/recording/recording_bloc.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import '../../../domain/repositories/i_recording_repository.dart';
import '../../../core/enums/audio_format.dart';
import '../../../services/location/geolocation_service.dart';
import '../../../services/audio/waveform_processing_service.dart';

part 'recording_event.dart';
part 'recording_state.dart';

/// Bloc responsible for managing audio recording state and operations
///
/// Handles recording start/stop/pause, real-time updates, and error states.
/// Provides clean separation between UI and audio service logic.
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  final IAudioServiceRepository _audioService;
  final IRecordingRepository _recordingRepository;
  final GeolocationService _geolocationService;
  final WaveformProcessingService _waveformProcessingService;

  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  Timer? _durationTimer;

  RecordingBloc({
    required IAudioServiceRepository audioService,
    required IRecordingRepository recordingRepository,
    GeolocationService? geolocationService,
    WaveformProcessingService? waveformProcessingService,
  }) : _audioService = audioService,
        _recordingRepository = recordingRepository,
        _geolocationService = geolocationService ?? GeolocationService(),
        _waveformProcessingService = waveformProcessingService ?? WaveformProcessingService(),
        super(const RecordingInitial()) {

    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<PauseRecording>(_onPauseRecording);
    on<ResumeRecording>(_onResumeRecording);
    on<CancelRecording>(_onCancelRecording);
    on<UpdateRecordingAmplitude>(_onUpdateRecordingAmplitude);
    on<UpdateRecordingDuration>(_onUpdateRecordingDuration);
    on<CheckRecordingPermissions>(_onCheckRecordingPermissions);
    on<RequestRecordingPermissions>(_onRequestRecordingPermissions);
    on<LoadRecordings>(_onLoadRecordings);
    on<ToggleEditMode>(_onToggleEditMode);
    on<ToggleRecordingSelection>(_onToggleRecordingSelection);
    on<ClearRecordingSelection>(_onClearRecordingSelection);
    // Removed ExpandRecording handler - expansion managed at screen level
    on<UpdateRecordingTitle>(_onUpdateRecordingTitle);
    on<DeleteRecording>(_onDeleteRecording);
    on<SoftDeleteRecording>(_onSoftDeleteRecording);
    on<PermanentDeleteRecording>(_onPermanentDeleteRecording);
    on<RestoreRecording>(_onRestoreRecording);
    on<CleanupExpiredRecordings>(_onCleanupExpiredRecordings);
    on<SelectAllRecordings>(_onSelectAllRecordings);
    on<DeselectAllRecordings>(_onDeselectAllRecordings);
    on<DeleteSelectedRecordings>(_onDeleteSelectedRecordings);
    on<ToggleFavoriteRecording>(_onToggleFavoriteRecording);
    on<DebugLoadAllRecordings>(_onDebugLoadAllRecordings);
    on<DebugCreateTestRecording>(_onDebugCreateTestRecording);

    // CRITICAL: Initialize the audio service when the bloc is created
    _initializeAudioService();
  }

  /// Initialize the audio service - CRITICAL FIX
  Future<void> _initializeAudioService() async {
    try {
      print('🔧 Initializing audio service...');
      final success = await _audioService.initialize();
      if (success) {
        print('✅ Audio service initialized successfully');
      } else {
        print('❌ Audio service initialization failed');
        // Handle initialization failure silently
      }
    } catch (e) {
      print('❌ Error initializing audio service: $e');
      // Handle initialization error silently
    }
  }

  @override
  Future<void> close() async {
    await _amplitudeSubscription?.cancel();
    await _durationSubscription?.cancel();
    _durationTimer?.cancel();

    // Dispose audio service
    try {
      await _audioService.dispose();
    } catch (e) {
      print('⚠️ Error disposing audio service: $e');
    }

    return super.close();
  }

  /// Start recording with specified settings
  Future<void> _onStartRecording(
      StartRecording event,
      Emitter<RecordingState> emit,
      ) async {
    try {
      print('🎤 Starting recording...');
      emit(const RecordingStarting());

      // Check permissions first
      final hasPermission = await _audioService.hasMicrophonePermission();
      if (!hasPermission) {
        print('❌ No microphone permission');
        emit(const RecordingError(
          'Microphone permission required to start recording',
          errorType: RecordingErrorType.permission,
        ));
        return;
      }

      // Generate file path
      final filePath = _generateFilePath(event.format, event.folderId);
      print('📁 Recording file path: $filePath');

      // Start recording
      final success = await _audioService.startRecording(
        filePath: filePath,
        format: event.format,
        sampleRate: event.sampleRate,
        bitRate: event.bitRate,
      );

      if (!success) {
        print('❌ Failed to start recording');
        emit(const RecordingError(
          'Failed to start recording',
          errorType: RecordingErrorType.recording,
        ));
        return;
      }

      // Start real-time updates
      _startAmplitudeUpdates();
      _startDurationUpdates();

      emit(RecordingInProgress(
        filePath: filePath,
        folderId: event.folderId,
        folderName: event.folderName,
        format: event.format,
        sampleRate: event.sampleRate,
        bitRate: event.bitRate,
        duration: Duration.zero,
        amplitude: 0.0,
        startTime: DateTime.now(),
      ));

      print('✅ Recording started successfully: $filePath');

    } catch (e, stackTrace) {
      print('❌ Error starting recording: $e');
      print('Stack trace: $stackTrace');
      emit(RecordingError(
        'Failed to start recording: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  /// Stop recording and create RecordingEntity
  Future<void> _onStopRecording(
      StopRecording event,
      Emitter<RecordingState> emit,
      ) async {
    if (state is! RecordingInProgress && state is! RecordingPaused) {
      emit(const RecordingError(
        'No active recording to stop',
        errorType: RecordingErrorType.state,
      ));
      return;
    }

    try {
      emit(const RecordingStopping());

      // Stop real-time updates
      _stopAmplitudeUpdates();
      _stopDurationUpdates();

      // Stop recording and get the recording entity
      final recording = await _audioService.stopRecording();

      if (recording != null) {
        // Save recording to repository with proper location-based naming
        try {
          print('🔄 Starting recording save process...');
          
          // Generate location-based name and update the recording
          print('🔄 Generating location-based name...');
          final finalRecording = await _generateLocationBasedRecording(recording);
          print('✅ Location-based name generated: ${finalRecording.name}');
          
          print('🔄 Saving recording to repository...');
          final savedRecording = await _recordingRepository.createRecording(finalRecording);
          print('✅ Recording saved to repository with ID: ${savedRecording.id}');
          
          print('🔄 Emitting RecordingCompleted event...');
          emit(RecordingCompleted(recording: savedRecording));
          print('✅ Recording completed and saved: ${savedRecording.name} in folder: ${savedRecording.folderId}');
          
        } catch (e) {
          print('❌ Error saving recording to repository: $e');
          emit(RecordingCompleted(recording: recording));
          print('✅ Recording completed (not saved to repository): ${recording.name}');
        }
      } else {
        emit(const RecordingError(
          'Failed to complete recording',
          errorType: RecordingErrorType.recording,
        ));
      }

    } catch (e) {
      print('❌ Error stopping recording: $e');
      emit(RecordingError(
        'Failed to stop recording: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  /// Pause recording
  Future<void> _onPauseRecording(
      PauseRecording event,
      Emitter<RecordingState> emit,
      ) async {
    if (state is! RecordingInProgress) return;

    try {
      final success = await _audioService.pauseRecording();
      if (success) {
        final currentState = state as RecordingInProgress;
        emit(RecordingPaused(
          filePath: currentState.filePath,
          folderId: currentState.folderId,
          folderName: currentState.folderName,
          format: currentState.format,
          sampleRate: currentState.sampleRate,
          bitRate: currentState.bitRate,
          duration: currentState.duration,
          startTime: currentState.startTime,
        ));
        print('⏸️ Recording paused');
      }
    } catch (e) {
      print('❌ Error pausing recording: $e');
    }
  }

  /// Resume recording
  Future<void> _onResumeRecording(
      ResumeRecording event,
      Emitter<RecordingState> emit,
      ) async {
    if (state is! RecordingPaused) return;

    try {
      final success = await _audioService.resumeRecording();
      if (success) {
        final currentState = state as RecordingPaused;
        emit(RecordingInProgress(
          filePath: currentState.filePath,
          folderId: currentState.folderId,
          folderName: currentState.folderName,
          format: currentState.format,
          sampleRate: currentState.sampleRate,
          bitRate: currentState.bitRate,
          duration: currentState.duration,
          amplitude: 0.0,
          startTime: currentState.startTime,
        ));

        // Restart updates
        _startAmplitudeUpdates();
        _startDurationUpdates();

        print('▶️ Recording resumed');
      }
    } catch (e) {
      print('❌ Error resuming recording: $e');
    }
  }

  /// Cancel recording
  Future<void> _onCancelRecording(
      CancelRecording event,
      Emitter<RecordingState> emit,
      ) async {
    try {
      // Stop updates
      _stopAmplitudeUpdates();
      _stopDurationUpdates();

      // Cancel recording
      await _audioService.cancelRecording();

      emit(const RecordingCancelled());
      print('🚫 Recording cancelled');

    } catch (e) {
      print('❌ Error cancelling recording: $e');
    }
  }

  /// Update recording amplitude
  void _onUpdateRecordingAmplitude(
      UpdateRecordingAmplitude event,
      Emitter<RecordingState> emit,
      ) {
    if (state is RecordingInProgress) {
      final currentState = state as RecordingInProgress;
      emit(currentState.copyWith(amplitude: event.amplitude));
    }
  }

  /// Update recording duration
  void _onUpdateRecordingDuration(
      UpdateRecordingDuration event,
      Emitter<RecordingState> emit,
      ) {
    if (state is RecordingInProgress) {
      final currentState = state as RecordingInProgress;
      emit(currentState.copyWith(duration: event.duration));
    } else if (state is RecordingPaused) {
      final currentState = state as RecordingPaused;
      emit(currentState.copyWith(duration: event.duration));
    }
  }

  /// Check recording permissions
  Future<void> _onCheckRecordingPermissions(
      CheckRecordingPermissions event,
      Emitter<RecordingState> emit,
      ) async {
    try {
      final hasPermission = await _audioService.hasMicrophonePermission();
      final hasMicrophone = await _audioService.hasMicrophone();

      emit(RecordingPermissionStatus(
        hasMicrophonePermission: hasPermission,
        hasMicrophone: hasMicrophone,
      ));

    } catch (e) {
      print('❌ Error checking permissions: $e');
      emit(const RecordingPermissionStatus(
        hasMicrophonePermission: false,
        hasMicrophone: false,
      ));
    }
  }

  /// Request recording permissions
  Future<void> _onRequestRecordingPermissions(
      RequestRecordingPermissions event,
      Emitter<RecordingState> emit,
      ) async {
    try {
      emit(const RecordingPermissionRequesting());

      final granted = await _audioService.requestMicrophonePermission();
      final hasMicrophone = await _audioService.hasMicrophone();

      emit(RecordingPermissionStatus(
        hasMicrophonePermission: granted,
        hasMicrophone: hasMicrophone,
      ));

      if (!granted) {
        emit(const RecordingError(
          'Microphone permission denied',
          errorType: RecordingErrorType.permission,
        ));
      }

    } catch (e) {
      print('❌ Error requesting permissions: $e');
      emit(const RecordingError(
        'Failed to request permissions',
        errorType: RecordingErrorType.permission,
      ));
    }
  }

  /// Load recordings for a specific folder
  Future<void> _onLoadRecordings(
      LoadRecordings event,
      Emitter<RecordingState> emit,
      ) async {
    try {
      print('🔄 Loading recordings for folder: ${event.folderId}');
      emit(const RecordingLoading());

      // Get recordings from recording repository
      final recordings = await _recordingRepository.getRecordingsByFolder(event.folderId);
      
      print('✅ Loaded ${recordings.length} recordings for folder ${event.folderId}');
      if (recordings.isNotEmpty) {
        print('📋 Recordings found:');
        for (final recording in recordings) {
          print('  📝 ${recording.name} (ID: ${recording.id}, Folder: ${recording.folderId})');
        }
      } else {
        print('📭 No recordings found for folder ${event.folderId}');
      }

      emit(RecordingLoaded(recordings));

    } catch (e) {
      print('❌ Error loading recordings: $e');
      emit(RecordingError(
        'Failed to load recordings: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  // ==== PRIVATE HELPER METHODS ====

  /// Start amplitude updates for visualization
  void _startAmplitudeUpdates() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _audioService.getRecordingAmplitudeStream().listen(
          (amplitude) {
        add(UpdateRecordingAmplitude(amplitude));
      },
      onError: (error) {
        print('❌ Amplitude stream error: $error');
      },
    );
  }

  /// Stop amplitude updates
  void _stopAmplitudeUpdates() {
    _amplitudeSubscription?.cancel();
  }

  /// Start duration updates
  void _startDurationUpdates() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      try {
        final duration = await _audioService.getCurrentRecordingDuration();
        add(UpdateRecordingDuration(duration));
      } catch (e) {
        print('❌ Duration update error: $e');
      }
    });
  }

  /// Stop duration updates
  void _stopDurationUpdates() {
    _durationTimer?.cancel();
  }

  /// Generate file path for recording
  String _generateFilePath(AudioFormat format, String? folderId) {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final folderPath = folderId ?? 'all_recordings';
    final extension = format.fileExtension;
    return '$folderPath/recording_$timestamp$extension';
  }

  /// Handle UI events
  void _onToggleEditMode(ToggleEditMode event, Emitter<RecordingState> emit) {
    if (state is RecordingLoaded) {
      final currentState = state as RecordingLoaded;
      emit(currentState.copyWith(
        isEditMode: !currentState.isEditMode,
        selectedRecordings: currentState.isEditMode ? <String>{} : currentState.selectedRecordings,
      ));
    }
  }

  void _onToggleRecordingSelection(ToggleRecordingSelection event, Emitter<RecordingState> emit) {
    if (state is RecordingLoaded) {
      final currentState = state as RecordingLoaded;
      final selectedRecordings = Set<String>.from(currentState.selectedRecordings);
      
      if (selectedRecordings.contains(event.recordingId)) {
        selectedRecordings.remove(event.recordingId);
      } else {
        selectedRecordings.add(event.recordingId);
      }
      
      emit(currentState.copyWith(selectedRecordings: selectedRecordings));
    }
  }

  void _onClearRecordingSelection(ClearRecordingSelection event, Emitter<RecordingState> emit) {
    if (state is RecordingLoaded) {
      final currentState = state as RecordingLoaded;
      emit(currentState.copyWith(selectedRecordings: <String>{}));
    }
  }

  void _onSelectAllRecordings(SelectAllRecordings event, Emitter<RecordingState> emit) {
    if (state is RecordingLoaded) {
      final currentState = state as RecordingLoaded;
      final allRecordingIds = currentState.recordings.map((r) => r.id).toSet();
      emit(currentState.copyWith(selectedRecordings: allRecordingIds));
    }
  }

  void _onDeselectAllRecordings(DeselectAllRecordings event, Emitter<RecordingState> emit) {
    if (state is RecordingLoaded) {
      final currentState = state as RecordingLoaded;
      emit(currentState.copyWith(selectedRecordings: <String>{}));
    }
  }

  Future<void> _onDeleteSelectedRecordings(DeleteSelectedRecordings event, Emitter<RecordingState> emit) async {
    if (state is RecordingLoaded) {
      final currentState = state as RecordingLoaded;
      final selectedIds = currentState.selectedRecordings;
      
      if (selectedIds.isEmpty) return;
      
      try {
        print('🗑️ Deleting ${selectedIds.length} selected recordings');
        
        // Delete all selected recordings based on folder context
        for (final recordingId in selectedIds) {
          if (event.folderId == 'recently_deleted') {
            // Permanent delete from Recently Deleted folder
            await _recordingRepository.deleteRecording(recordingId);
          } else {
            // Soft delete from any other folder (moves to Recently Deleted)
            await _recordingRepository.softDeleteRecording(recordingId);
          }
        }
        
        // Update the recordings list by removing deleted recordings
        final updatedRecordings = currentState.recordings
            .where((recording) => !selectedIds.contains(recording.id))
            .toList();
        
        // Clear selection and update list
        emit(currentState.copyWith(
          recordings: updatedRecordings,
          selectedRecordings: <String>{},
        ));
        
        print('✅ Successfully deleted ${selectedIds.length} recordings');
        
      } catch (e) {
        print('❌ Error deleting selected recordings: $e');
        emit(RecordingError(
          'Failed to delete selected recordings: ${e.toString()}',
          errorType: RecordingErrorType.unknown,
        ));
      }
    }
  }

  /// Toggle favorite status of a recording
  Future<void> _onToggleFavoriteRecording(ToggleFavoriteRecording event, Emitter<RecordingState> emit) async {
    if (state is RecordingLoaded) {
      final currentState = state as RecordingLoaded;
      
      try {
        print('❤️ Toggling favorite for recording: ${event.recordingId}');
        
        // Find the recording
        final recording = currentState.recordings.firstWhere(
          (r) => r.id == event.recordingId,
        );
        
        // Toggle favorite status
        final success = await _recordingRepository.toggleFavorite(event.recordingId);
        
        if (success) {
          // Update the recording in the list
          final updatedRecordings = currentState.recordings.map((r) {
            if (r.id == event.recordingId) {
              return r.toggleFavorite();
            }
            return r;
          }).toList();
          
          emit(currentState.copyWith(recordings: updatedRecordings));
          print('✅ Successfully toggled favorite status');
        } else {
          throw Exception('Failed to toggle favorite status');
        }
        
      } catch (e) {
        print('❌ Error toggling favorite: $e');
        emit(RecordingError(
          'Failed to toggle favorite: ${e.toString()}',
          errorType: RecordingErrorType.unknown,
        ));
      }
    }
  }

  // Removed _onExpandRecording - expansion managed at screen level

  void _onUpdateRecordingTitle(UpdateRecordingTitle event, Emitter<RecordingState> emit) {
    if (state is RecordingInProgress) {
      final currentState = state as RecordingInProgress;
      emit(currentState.copyWith(title: event.title));
    }
  }

  /// Delete a recording
  Future<void> _onDeleteRecording(DeleteRecording event, Emitter<RecordingState> emit) async {
    try {
      print('🗑️ Deleting recording: ${event.recordingId}');
      
      // Delete from repository
      await _recordingRepository.deleteRecording(event.recordingId);
      
      // If currently in RecordingLoaded state, update the list
      if (state is RecordingLoaded) {
        final currentState = state as RecordingLoaded;
        final updatedRecordings = currentState.recordings
            .where((recording) => recording.id != event.recordingId)
            .toList();
        
        emit(currentState.copyWith(recordings: updatedRecordings));
        print('✅ Recording deleted successfully and list updated');
      }
      
    } catch (e) {
      print('❌ Error deleting recording: $e');
      emit(RecordingError(
        'Failed to delete recording: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  /// Soft delete a recording (move to Recently Deleted)
  Future<void> _onSoftDeleteRecording(SoftDeleteRecording event, Emitter<RecordingState> emit) async {
    try {
      print('🗑️ Soft deleting recording: ${event.recordingId}');
      
      // Soft delete from repository
      final success = await _recordingRepository.softDeleteRecording(event.recordingId);
      
      if (success) {
        // If currently in RecordingLoaded state, update the list
        if (state is RecordingLoaded) {
          final currentState = state as RecordingLoaded;
          final updatedRecordings = currentState.recordings
              .where((recording) => recording.id != event.recordingId)
              .toList();
          
          emit(currentState.copyWith(recordings: updatedRecordings));
          print('✅ Recording soft deleted successfully and list updated');
        }
      } else {
        throw Exception('Failed to soft delete recording');
      }
      
    } catch (e) {
      print('❌ Error soft deleting recording: $e');
      emit(RecordingError(
        'Failed to delete recording: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  /// Permanently delete a recording
  Future<void> _onPermanentDeleteRecording(PermanentDeleteRecording event, Emitter<RecordingState> emit) async {
    try {
      print('💀 Permanently deleting recording: ${event.recordingId}');
      
      // Permanently delete from repository
      final success = await _recordingRepository.permanentlyDeleteRecording(event.recordingId);
      
      if (success) {
        // If currently in RecordingLoaded state, update the list
        if (state is RecordingLoaded) {
          final currentState = state as RecordingLoaded;
          final updatedRecordings = currentState.recordings
              .where((recording) => recording.id != event.recordingId)
              .toList();
          
          emit(currentState.copyWith(recordings: updatedRecordings));
          print('✅ Recording permanently deleted successfully and list updated');
        }
      } else {
        throw Exception('Failed to permanently delete recording');
      }
      
    } catch (e) {
      print('❌ Error permanently deleting recording: $e');
      emit(RecordingError(
        'Failed to permanently delete recording: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  /// Restore a recording from Recently Deleted
  Future<void> _onRestoreRecording(RestoreRecording event, Emitter<RecordingState> emit) async {
    try {
      print('🔄 Restoring recording: ${event.recordingId}');
      
      // Restore from repository
      final success = await _recordingRepository.restoreRecording(event.recordingId);
      
      if (success) {
        // If currently in RecordingLoaded state, update the list (remove from Recently Deleted)
        if (state is RecordingLoaded) {
          final currentState = state as RecordingLoaded;
          final updatedRecordings = currentState.recordings
              .where((recording) => recording.id != event.recordingId)
              .toList();
          
          emit(currentState.copyWith(recordings: updatedRecordings));
          print('✅ Recording restored successfully and removed from Recently Deleted list');
        }
      } else {
        throw Exception('Failed to restore recording');
      }
      
    } catch (e) {
      print('❌ Error restoring recording: $e');
      emit(RecordingError(
        'Failed to restore recording: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  /// Clean up expired recordings (auto-delete after 15 days)
  Future<void> _onCleanupExpiredRecordings(CleanupExpiredRecordings event, Emitter<RecordingState> emit) async {
    try {
      print('🧹 Cleaning up expired recordings...');
      
      // Clean up from repository
      final deletedCount = await _recordingRepository.cleanupExpiredRecordings();
      
      print('✅ Cleaned up $deletedCount expired recordings');
      
      // If currently viewing Recently Deleted folder, refresh the list
      if (state is RecordingLoaded) {
        final currentState = state as RecordingLoaded;
        // Could trigger a refresh here if needed
      }
      
    } catch (e) {
      print('❌ Error cleaning up expired recordings: $e');
      emit(RecordingError(
        'Failed to clean up expired recordings: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  /// Debug: Load all recordings from database
  Future<void> _onDebugLoadAllRecordings(DebugLoadAllRecordings event, Emitter<RecordingState> emit) async {
    try {
      emit(const RecordingLoading());
      print('🔍 DEBUG: Loading ALL recordings from database...');

      // Get all recordings from recording repository
      final allRecordings = await _recordingRepository.getAllRecordings();
      
      print('🔍 DEBUG: Found ${allRecordings.length} total recordings in database:');
      for (var recording in allRecordings) {
        print('  📁 ${recording.name} (folder: ${recording.folderId}, id: ${recording.id})');
      }

      emit(RecordingLoaded(allRecordings));
      print('✅ DEBUG: Loaded all recordings for debugging');

    } catch (e) {
      print('❌ DEBUG: Error loading all recordings: $e');
      emit(RecordingError(
        'Debug error: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  /// Debug: Create a test recording
  Future<void> _onDebugCreateTestRecording(DebugCreateTestRecording event, Emitter<RecordingState> emit) async {
    try {
      print('🧪 DEBUG: Creating test recording for folder: ${event.folderId}');

      final testRecording = RecordingEntity.create(
        name: 'Test Recording ${DateTime.now().millisecondsSinceEpoch}',
        filePath: '/test/path/recording.m4a',
        folderId: event.folderId,
        format: AudioFormat.m4a,
        duration: const Duration(seconds: 30),
        fileSize: 1024,
        sampleRate: 44100,
      );

      // Save to repository
      final savedRecording = await _recordingRepository.createRecording(testRecording);
      
      emit(RecordingCompleted(recording: savedRecording));
      print('🧪 DEBUG: Test recording created and saved: ${savedRecording.name}');

    } catch (e) {
      print('❌ DEBUG: Error creating test recording: $e');
      emit(RecordingError(
        'Debug test recording error: ${e.toString()}',
        errorType: RecordingErrorType.unknown,
      ));
    }
  }

  /// Generate location-based recording with incremental naming
  Future<RecordingEntity> _generateLocationBasedRecording(RecordingEntity recording) async {
    try {
      // Get the current address from geolocation with timeout
      String locationName;
      
      try {
        // Add a shorter timeout to prevent blocking
        locationName = await _geolocationService.getRecordingLocationName()
            .timeout(const Duration(seconds: 3));
        print('📍 Using geolocation address for recording: "$locationName"');
      } catch (e) {
        print('⚠️ Geolocation timeout/error, using fallback naming: $e');
        // Use timestamp-based fallback if geolocation fails
        final now = DateTime.now();
        locationName = 'Recording ${now.day}/${now.month} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
        print('📍 Using fallback name: "$locationName"');
      }

      // Get existing recordings in this folder to determine the next number
      final existingRecordings = await _recordingRepository.getRecordingsByFolder(recording.folderId);
      
      // Filter recordings that start with the location name
      final matchingRecordings = existingRecordings.where((r) => 
        r.name.startsWith(locationName)
      ).toList();

      // Determine the next number
      String newName;
      if (matchingRecordings.isEmpty) {
        // First recording with this location name
        newName = locationName;
      } else {
        // Find the highest number used
        int highestNumber = 1;
        for (final existingRecording in matchingRecordings) {
          if (existingRecording.name == locationName) {
            // This is the base name without number
            highestNumber = math.max(highestNumber, 1);
          } else {
            // Try to extract number from name like "Via Cerlini 19 2"
            final escapedLocationName = RegExp.escape(locationName);
            final regex = RegExp('^$escapedLocationName (\\d+)\$');
            final match = regex.firstMatch(existingRecording.name);
            if (match != null) {
              final number = int.tryParse(match.group(1) ?? '0') ?? 0;
              highestNumber = math.max(highestNumber, number);
            }
          }
        }
        
        // Next recording should be the next number
        newName = '$locationName ${highestNumber + 1}';
      }

      print('📝 Generated location-based name: "$newName" for location: $locationName');
      print('📊 Found ${matchingRecordings.length} existing recordings with this location name');

      // Create updated recording with the new name and location
      return recording.copyWith(
        name: newName,
        locationName: locationName,
      );

    } catch (e) {
      print('❌ Error generating location-based recording name: $e');
      // Return original recording if naming fails
      return recording;
    }
  }

  /// Process waveform data in background after recording completion
  void _processWaveformInBackground(RecordingEntity recording) async {
    try {
      print('🎵 Starting background waveform processing for: ${recording.name}');
      
      // Process waveform in background (don't await to avoid blocking)
      _waveformProcessingService.processRecordingWaveform(recording).then((processedRecording) {
        if (processedRecording != null && processedRecording.waveformData != null) {
          print('✅ Background waveform processing completed for: ${recording.name}');
          // Optionally emit an event to refresh the UI with updated waveform data
          // add(RefreshRecordingWaveform(recording: processedRecording));
        }
      }).catchError((error) {
        print('❌ Background waveform processing failed for ${recording.name}: $error');
      });
      
    } catch (e) {
      print('❌ Error starting background waveform processing: $e');
    }
  }
}