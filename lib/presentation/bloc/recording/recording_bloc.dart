// File: presentation/bloc/recording/recording_bloc.dart
// 
// Recording BLoC - Presentation Layer
// ==================================
//
// Central state management for all recording operations in the WavNote app.
// This BLoC implements the BLoC pattern to provide a clean separation between
// UI components and business logic for audio recording functionality.
//
// Key Responsibilities:
// - Manage recording lifecycle (start, pause, resume, stop)
// - Handle real-time recording updates (amplitude, duration)
// - Coordinate with use cases for complex business logic
// - Manage recording list operations (load, delete, search, organize)
// - Handle edit mode and multi-selection for bulk operations
// - Provide error handling and user feedback
//
// Architecture Features:
// - Uses Clean Architecture with dependency injection
// - Implements use case pattern for complex operations
// - Provides reactive streams for real-time UI updates
// - Maintains immutable state with Equatable
// - Handles async operations with proper error management
//
// State Management:
// - RecordingInitial: Initial/idle state
// - RecordingStarting: Preparing to record
// - RecordingInProgress: Active recording with real-time updates
// - RecordingPaused: Recording paused by user
// - RecordingCompleted: Recording finished successfully
// - RecordingLoaded: List of recordings with edit capabilities
// - RecordingError: Error states with descriptive messages
//
// Real-time Features:
// - Live amplitude monitoring for waveform visualization
// - Continuous duration updates during recording
// - Automatic cleanup of expired recordings (15+ days)
// - Background recording state preservation

import 'dart:async';
import 'dart:math' as math;
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

// Domain imports
import '../../../domain/entities/recording_entity.dart';              // Recording business entity
import '../../../domain/repositories/i_audio_service_repository.dart'; // Audio service interface
import '../../../services/audio/audio_service_coordinator.dart';     // Audio service coordinator
import '../../../domain/repositories/i_recording_repository.dart';     // Recording data interface
import '../../../core/enums/audio_format.dart';                       // Audio format definitions

// Use case imports for complex business logic
import '../../../domain/usecases/recording/start_recording_usecase.dart'; // Recording initiation
import '../../../domain/usecases/recording/stop_recording_usecase.dart';  // Recording completion
import '../../../domain/usecases/recording/pause_recording_usecase.dart'; // Recording pause/resume

// Service imports
import '../../../services/location/geolocation_service.dart'; // Location-based recording naming

// BLoC parts
part 'recording_event.dart'; // Recording events (user actions)
part 'recording_state.dart'; // Recording states (app states)

/// BLoC responsible for managing audio recording state and operations
///
/// Handles recording start/stop/pause, real-time updates, and error states.
/// Provides clean separation between UI and audio service logic.
///
/// Key features:
/// - Real-time recording with amplitude and duration updates
/// - Location-based automatic recording naming
/// - Multi-format audio support (M4A, MP3, WAV, AAC)
/// - Edit mode with multi-selection capabilities
/// - Automatic cleanup of expired recordings
/// - Comprehensive error handling and recovery
///
/// Example usage:
/// ```dart
/// // Start recording
/// context.read<RecordingBloc>().add(StartRecording(
///   folderId: 'my_folder',
///   format: AudioFormat.m4a,
/// ));
/// 
/// // Listen to state changes
/// BlocBuilder<RecordingBloc, RecordingState>(
///   builder: (context, state) {
///     if (state is RecordingInProgress) {
///       return Text('Recording: ${state.duration}');
///     }
///     return SizedBox.shrink();
///   },
/// );
/// ```
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  final IAudioServiceRepository _audioService;
  final IRecordingRepository _recordingRepository;
  final StartRecordingUseCase _startRecordingUseCase;
  final StopRecordingUseCase _stopRecordingUseCase;
  final PauseRecordingUseCase _pauseRecordingUseCase;

  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  Timer? _durationTimer;

  RecordingBloc({
    required IAudioServiceRepository audioService,
    required IRecordingRepository recordingRepository,
    required GeolocationService geolocationService,
    StartRecordingUseCase? startRecordingUseCase,
    StopRecordingUseCase? stopRecordingUseCase,
    PauseRecordingUseCase? pauseRecordingUseCase,
  }) : _audioService = audioService,
        _recordingRepository = recordingRepository,
        _startRecordingUseCase = startRecordingUseCase ?? StartRecordingUseCase(
          audioService: audioService,
          geolocationService: geolocationService,
        ),
        _stopRecordingUseCase = stopRecordingUseCase ?? StopRecordingUseCase(
          audioService: audioService,
          recordingRepository: recordingRepository,
          geolocationService: geolocationService,
        ),
        _pauseRecordingUseCase = pauseRecordingUseCase ?? PauseRecordingUseCase(
          audioService: audioService,
        ),
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

    // Don't dispose audio service - it's a singleton/global service
    // Only dispose if it's a coordinator (not a singleton)
    if (_audioService is AudioServiceCoordinator) {
      try {
        await _audioService.dispose();
      } catch (e) {
        print('⚠️ Error disposing audio service coordinator: $e');
      }
    } else {
      print('✅ Skipping disposal of singleton audio service');
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

      // Use the StartRecordingUseCase
      final result = await _startRecordingUseCase.execute(
        folderId: event.folderId ?? 'all_recordings',
        format: event.format,
        sampleRate: event.sampleRate,
        bitRate: event.bitRate,
      );

      if (result.isSuccess) {
        // Start real-time updates
        _startAmplitudeUpdates();
        _startDurationUpdates();

        emit(RecordingInProgress(
          filePath: result.filePath!,
          folderId: result.folderId!,
          folderName: event.folderName,
          format: result.format!,
          sampleRate: result.sampleRate!,
          bitRate: result.bitRate!,
          duration: Duration.zero,
          amplitude: 0.0,
          startTime: result.startTime!,
          title: result.title,
        ));

        print('✅ Recording started successfully: ${result.filePath}');
      } else {
        print('❌ Failed to start recording: ${result.errorMessage}');
        final errorType = _mapStartRecordingErrorType(result.errorType!);
        emit(RecordingError(
          result.errorMessage!,
          errorType: errorType,
        ));
      }

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

      // Get current duration from state before stopping
      Duration? currentDuration;
      if (state is RecordingInProgress) {
        currentDuration = (state as RecordingInProgress).duration;
      } else if (state is RecordingPaused) {
        currentDuration = (state as RecordingPaused).duration;
      }
      
      print('\ud83d\udd50 Using BLoC duration for recording: ${currentDuration?.inSeconds ?? 0} seconds');

      // Use the StopRecordingUseCase with accurate duration from UI state
      final result = await _stopRecordingUseCase.execute(
        waveformData: event.waveformData,
        overrideDuration: currentDuration,
      );

      if (result.isSuccess) {
        emit(RecordingCompleted(recording: result.recording!));
        print('✅ Recording completed and saved: ${result.recording!.name}');
      } else {
        print('❌ Failed to stop recording: ${result.errorMessage}');
        final errorType = _mapStopRecordingErrorType(result.errorType!);
        emit(RecordingError(
          result.errorMessage!,
          errorType: errorType,
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
      final result = await _pauseRecordingUseCase.executePause();
      if (result.isSuccess) {
        final currentState = state as RecordingInProgress;
        emit(RecordingPaused(
          filePath: currentState.filePath,
          folderId: currentState.folderId,
          folderName: currentState.folderName,
          format: currentState.format,
          sampleRate: currentState.sampleRate,
          bitRate: currentState.bitRate,
          duration: result.duration ?? currentState.duration,
          startTime: currentState.startTime,
        ));
        print('⏸️ Recording paused');
      } else {
        print('❌ Failed to pause recording: ${result.errorMessage}');
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
      final result = await _pauseRecordingUseCase.executeResume();
      if (result.isSuccess) {
        final currentState = state as RecordingPaused;
        emit(RecordingInProgress(
          filePath: currentState.filePath,
          folderId: currentState.folderId,
          folderName: currentState.folderName,
          format: currentState.format,
          sampleRate: currentState.sampleRate,
          bitRate: currentState.bitRate,
          duration: result.duration ?? currentState.duration,
          amplitude: 0.0,
          startTime: currentState.startTime,
        ));

        // Restart updates
        _startAmplitudeUpdates();
        _startDurationUpdates();

        print('▶️ Recording resumed');
      } else {
        print('❌ Failed to resume recording: ${result.errorMessage}');
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

  /// Map StartRecordingErrorType to RecordingErrorType
  RecordingErrorType _mapStartRecordingErrorType(StartRecordingErrorType errorType) {
    switch (errorType) {
      case StartRecordingErrorType.permissionDenied:
        return RecordingErrorType.permission;
      case StartRecordingErrorType.audioServiceError:
        return RecordingErrorType.recording;
      case StartRecordingErrorType.invalidConfiguration:
        return RecordingErrorType.state;
      case StartRecordingErrorType.fileSystemError:
        return RecordingErrorType.recording;
      case StartRecordingErrorType.unknown:
        return RecordingErrorType.unknown;
    }
  }

  /// Map StopRecordingErrorType to RecordingErrorType
  RecordingErrorType _mapStopRecordingErrorType(StopRecordingErrorType errorType) {
    switch (errorType) {
      case StopRecordingErrorType.noActiveRecording:
        return RecordingErrorType.state;
      case StopRecordingErrorType.audioServiceError:
        return RecordingErrorType.recording;
      case StopRecordingErrorType.invalidRecording:
        return RecordingErrorType.state;
      case StopRecordingErrorType.repositoryError:
        return RecordingErrorType.unknown;
      case StopRecordingErrorType.fileSystemError:
        return RecordingErrorType.recording;
      case StopRecordingErrorType.unknown:
        return RecordingErrorType.unknown;
    }
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
        folderId: event.folderId ?? 'all_recordings',
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

}