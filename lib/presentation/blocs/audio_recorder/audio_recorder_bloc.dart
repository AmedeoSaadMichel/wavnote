// File: presentation/blocs/audio_recorder/audio_recorder_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/usecases/recording/start_recording_usecase.dart';
import '../../../domain/usecases/recording/stop_recording_usecase.dart';
import '../../../domain/usecases/recording/pause_recording_usecase.dart';
import '../../../domain/usecases/recording/delete_recording_usecase.dart';
import '../../../core/enums/audio_format.dart';

part 'audio_recorder_event.dart';
part 'audio_recorder_state.dart';

/// BLoC responsible for managing audio recording state and operations
///
/// Orchestrates the complete recording lifecycle by coordinating between
/// multiple use cases while providing clean state management for the UI.
///
/// Features:
/// - Complete recording session management
/// - Real-time duration and amplitude tracking
/// - Pause/resume functionality with accurate time tracking
/// - Error handling and recovery
/// - Session persistence and restoration
class AudioRecorderBloc extends Bloc<AudioRecorderEvent, AudioRecorderState> {
  final StartRecordingUseCase _startRecordingUseCase;
  final StopRecordingUseCase _stopRecordingUseCase;
  final PauseRecordingUseCase _pauseRecordingUseCase;
  final DeleteRecordingUseCase _deleteRecordingUseCase;

  // Active session tracking
  RecordingSession? _currentSession;
  PausedRecordingSession? _pausedSession;

  // Real-time tracking
  Timer? _durationTimer;
  Timer? _amplitudeTimer;
  Duration _currentDuration = Duration.zero;
  double _currentAmplitude = 0.0;

  // Session statistics
  DateTime? _sessionStartTime;
  Duration _totalPausedDuration = Duration.zero;

  AudioRecorderBloc({
    required StartRecordingUseCase startRecordingUseCase,
    required StopRecordingUseCase stopRecordingUseCase,
    required PauseRecordingUseCase pauseRecordingUseCase,
    required DeleteRecordingUseCase deleteRecordingUseCase,
  })  : _startRecordingUseCase = startRecordingUseCase,
        _stopRecordingUseCase = stopRecordingUseCase,
        _pauseRecordingUseCase = pauseRecordingUseCase,
        _deleteRecordingUseCase = deleteRecordingUseCase,
        super(const AudioRecorderInitial()) {
    // Register event handlers
    on<StartRecordingRequested>(_onStartRecordingRequested);
    on<StopRecordingRequested>(_onStopRecordingRequested);
    on<PauseRecordingRequested>(_onPauseRecordingRequested);
    on<ResumeRecordingRequested>(_onResumeRecordingRequested);
    on<CancelRecordingRequested>(_onCancelRecordingRequested);
    on<DeleteRecordingRequested>(_onDeleteRecordingRequested);
    on<UpdateRecordingDuration>(_onUpdateRecordingDuration);
    on<UpdateRecordingAmplitude>(_onUpdateRecordingAmplitude);
    on<RestoreSessionRequested>(_onRestoreSessionRequested);
  }

  @override
  Future<void> close() async {
    await _stopTimers();
    return super.close();
  }

  // ==== EVENT HANDLERS ====

  /// Handle start recording request
  Future<void> _onStartRecordingRequested(
      StartRecordingRequested event,
      Emitter<AudioRecorderState> emit,
      ) async {
    try {
      emit(const AudioRecorderStarting());

      // Create start recording parameters
      final startParams = StartRecordingParams(
        folderId: event.folderId,
        format: event.format,
        sampleRate: event.sampleRate,
        bitRate: event.bitRate,
        customName: event.customName,
        latitude: event.latitude,
        longitude: event.longitude,
        locationName: event.locationName,
        tags: event.tags,
      );

      // Execute start recording use case
      final result = await _startRecordingUseCase.execute(startParams);

      result.fold(
            (failure) {
          emit(AudioRecorderError(
            failure.message,
            errorType: _mapFailureToErrorType(failure.type),
          ));
        },
            (session) {
          _currentSession = session;
          _sessionStartTime = DateTime.now();
          _totalPausedDuration = Duration.zero;
          _currentDuration = Duration.zero;

          // Start real-time tracking
          _startRealTimeTracking();

          emit(AudioRecorderRecording(
            session: session,
            duration: _currentDuration,
            amplitude: _currentAmplitude,
            effectiveDuration: _currentDuration,
            totalPausedDuration: _totalPausedDuration,
            sessionStartTime: _sessionStartTime!,
          ));
        },
      );
    } catch (e) {
      emit(AudioRecorderError(
        'Unexpected error starting recording: $e',
        errorType: AudioRecorderErrorType.unexpected,
      ));
    }
  }

  /// Handle stop recording request
  Future<void> _onStopRecordingRequested(
      StopRecordingRequested event,
      Emitter<AudioRecorderState> emit,
      ) async {
    if (_currentSession == null) {
      emit(const AudioRecorderError(
        'No active recording session to stop',
        errorType: AudioRecorderErrorType.invalidState,
      ));
      return;
    }

    try {
      emit(const AudioRecorderStopping());

      // Stop real-time tracking
      await _stopTimers();

      // Create stop recording parameters
      final stopParams = _pausedSession != null
          ? StopRecordingParams.fromPaused(_pausedSession!, customName: event.customName)
          : StopRecordingParams.fromActive(_currentSession!, customName: event.customName);

      // Execute stop recording use case
      final result = await _stopRecordingUseCase.execute(stopParams);

      result.fold(
            (failure) {
          emit(AudioRecorderError(
            failure.message,
            errorType: _mapFailureToErrorType(failure.type),
          ));
        },
            (stopResult) {
          // Clear session data
          _clearSessionData();

          emit(AudioRecorderCompleted(
            recording: stopResult.recording,
            session: stopResult.session,
            effectiveDuration: stopResult.effectiveDuration,
            totalSessionDuration: stopResult.totalSessionDuration,
            totalPausedDuration: stopResult.totalPausedDuration,
            statistics: stopResult.statistics,
          ));
        },
      );
    } catch (e) {
      emit(AudioRecorderError(
        'Unexpected error stopping recording: $e',
        errorType: AudioRecorderErrorType.unexpected,
      ));
    }
  }

  /// Handle pause recording request
  Future<void> _onPauseRecordingRequested(
      PauseRecordingRequested event,
      Emitter<AudioRecorderState> emit,
      ) async {
    if (_currentSession == null) {
      emit(const AudioRecorderError(
        'No active recording session to pause',
        errorType: AudioRecorderErrorType.invalidState,
      ));
      return;
    }

    try {
      emit(const AudioRecorderPausing());

      // Create pause parameters
      final pauseParams = PauseRecordingParams(
        session: _currentSession!,
        existingPausedDuration: _totalPausedDuration,
      );

      // Execute pause recording use case
      final result = await _pauseRecordingUseCase.pause(pauseParams);

      result.fold(
            (failure) {
          emit(AudioRecorderError(
            failure.message,
            errorType: _mapFailureToErrorType(failure.type),
          ));
        },
            (pausedSession) {
          _pausedSession = pausedSession;

          // Stop duration tracking but keep amplitude at zero
          _durationTimer?.cancel();
          _currentAmplitude = 0.0;

          emit(AudioRecorderPaused(
            session: _currentSession!,
            pausedSession: pausedSession,
            duration: _currentDuration,
            effectiveDuration: pausedSession.effectiveRecordingDuration,
            totalPausedDuration: pausedSession.previousPausedDuration,
            pausedAt: pausedSession.pausedAt,
            sessionStartTime: _sessionStartTime!,
          ));
        },
      );
    } catch (e) {
      emit(AudioRecorderError(
        'Unexpected error pausing recording: $e',
        errorType: AudioRecorderErrorType.unexpected,
      ));
    }
  }

  /// Handle resume recording request
  Future<void> _onResumeRecordingRequested(
      ResumeRecordingRequested event,
      Emitter<AudioRecorderState> emit,
      ) async {
    if (_pausedSession == null) {
      emit(const AudioRecorderError(
        'No paused recording session to resume',
        errorType: AudioRecorderErrorType.invalidState,
      ));
      return;
    }

    try {
      emit(const AudioRecorderResuming());

      // Create resume parameters
      final resumeParams = ResumeRecordingParams(pausedSession: _pausedSession!);

      // Execute resume recording use case
      final result = await _pauseRecordingUseCase.resume(resumeParams);

      result.fold(
            (failure) {
          emit(AudioRecorderError(
            failure.message,
            errorType: _mapFailureToErrorType(failure.type),
          ));
        },
            (resumedSession) {
          // Update total paused duration
          final pauseDuration = DateTime.now().difference(_pausedSession!.pausedAt);
          _totalPausedDuration = _pausedSession!.previousPausedDuration + pauseDuration;

          _currentSession = resumedSession;
          _pausedSession = null;

          // Resume real-time tracking
          _startRealTimeTracking();

          emit(AudioRecorderRecording(
            session: resumedSession,
            duration: _currentDuration,
            amplitude: _currentAmplitude,
            effectiveDuration: _currentDuration - _totalPausedDuration,
            totalPausedDuration: _totalPausedDuration,
            sessionStartTime: _sessionStartTime!,
          ));
        },
      );
    } catch (e) {
      emit(AudioRecorderError(
        'Unexpected error resuming recording: $e',
        errorType: AudioRecorderErrorType.unexpected,
      ));
    }
  }

  /// Handle cancel recording request
  Future<void> _onCancelRecordingRequested(
      CancelRecordingRequested event,
      Emitter<AudioRecorderState> emit,
      ) async {
    if (_currentSession == null) {
      emit(const AudioRecorderError(
        'No active recording session to cancel',
        errorType: AudioRecorderErrorType.invalidState,
      ));
      return;
    }

    try {
      emit(const AudioRecorderCancelling());

      // Stop real-time tracking
      await _stopTimers();

      // Create cancel parameters
      final cancelParams = _pausedSession != null
          ? CancelRecordingParams.fromPaused(_pausedSession!, reason: event.reason)
          : CancelRecordingParams.fromActive(_currentSession!, reason: event.reason);

      // Execute cancel recording use case
      final result = await _stopRecordingUseCase.cancel(cancelParams);

      result.fold(
            (failure) {
          emit(AudioRecorderError(
            failure.message,
            errorType: _mapFailureToErrorType(failure.type),
          ));
        },
            (cancelResult) {
          // Clear session data
          _clearSessionData();

          emit(AudioRecorderCancelled(
            session: cancelResult.session,
            canceledAt: cancelResult.canceledAt,
            recordedDuration: cancelResult.recordedDuration,
            reason: cancelResult.reason,
          ));
        },
      );
    } catch (e) {
      emit(AudioRecorderError(
        'Unexpected error cancelling recording: $e',
        errorType: AudioRecorderErrorType.unexpected,
      ));
    }
  }

  /// Handle delete recording request
  Future<void> _onDeleteRecordingRequested(
      DeleteRecordingRequested event,
      Emitter<AudioRecorderState> emit,
      ) async {
    try {
      // Create delete parameters
      final deleteParams = DeleteRecordingParams(
        recordingId: event.recordingId,
        createBackup: event.createBackup,
      );

      // Execute delete recording use case
      final result = await _deleteRecordingUseCase.execute(deleteParams);

      result.fold(
            (failure) {
          emit(AudioRecorderError(
            failure.message,
            errorType: _mapFailureToErrorType(failure.type),
          ));
        },
            (deleteResult) {
          emit(AudioRecorderDeleted(
            deletedRecording: deleteResult.deletedRecording,
            deletedAt: deleteResult.deletedAt,
            wasBackedUp: deleteResult.wasBackedUp,
            backupPath: deleteResult.backupPath,
          ));
        },
      );
    } catch (e) {
      emit(AudioRecorderError(
        'Unexpected error deleting recording: $e',
        errorType: AudioRecorderErrorType.unexpected,
      ));
    }
  }

  /// Handle recording duration updates
  void _onUpdateRecordingDuration(
      UpdateRecordingDuration event,
      Emitter<AudioRecorderState> emit,
      ) {
    _currentDuration = event.duration;

    // Only emit if currently recording
    if (state is AudioRecorderRecording && _currentSession != null) {
      final currentState = state as AudioRecorderRecording;
      emit(currentState.copyWith(
        duration: _currentDuration,
        effectiveDuration: _currentDuration - _totalPausedDuration,
      ));
    }
  }

  /// Handle recording amplitude updates
  void _onUpdateRecordingAmplitude(
      UpdateRecordingAmplitude event,
      Emitter<AudioRecorderState> emit,
      ) {
    _currentAmplitude = event.amplitude;

    // Only emit if currently recording
    if (state is AudioRecorderRecording && _currentSession != null) {
      final currentState = state as AudioRecorderRecording;
      emit(currentState.copyWith(amplitude: _currentAmplitude));
    }
  }

  /// Handle session restoration request
  Future<void> _onRestoreSessionRequested(
      RestoreSessionRequested event,
      Emitter<AudioRecorderState> emit,
      ) async {
    try {
      _currentSession = event.session;
      _pausedSession = event.pausedSession;
      _sessionStartTime = event.sessionStartTime;
      _totalPausedDuration = event.totalPausedDuration;
      _currentDuration = event.currentDuration;

      if (_pausedSession != null) {
        emit(AudioRecorderPaused(
          session: _currentSession!,
          pausedSession: _pausedSession!,
          duration: _currentDuration,
          effectiveDuration: _pausedSession!.effectiveRecordingDuration,
          totalPausedDuration: _totalPausedDuration,
          pausedAt: _pausedSession!.pausedAt,
          sessionStartTime: _sessionStartTime!,
        ));
      } else {
        _startRealTimeTracking();
        emit(AudioRecorderRecording(
          session: _currentSession!,
          duration: _currentDuration,
          amplitude: _currentAmplitude,
          effectiveDuration: _currentDuration - _totalPausedDuration,
          totalPausedDuration: _totalPausedDuration,
          sessionStartTime: _sessionStartTime!,
        ));
      }
    } catch (e) {
      emit(AudioRecorderError(
        'Failed to restore recording session: $e',
        errorType: AudioRecorderErrorType.unexpected,
      ));
    }
  }

  // ==== PRIVATE HELPER METHODS ====

  /// Start real-time duration and amplitude tracking
  void _startRealTimeTracking() {
    // Duration tracking
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sessionStartTime != null) {
        final totalElapsed = DateTime.now().difference(_sessionStartTime!);
        add(UpdateRecordingDuration(totalElapsed));
      }
    });

    // Amplitude simulation (in real implementation, get from audio service)
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final amplitude = 0.2 + (0.6 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000);
      add(UpdateRecordingAmplitude(amplitude));
    });
  }

  /// Stop all real-time tracking timers
  Future<void> _stopTimers() async {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    _currentAmplitude = 0.0;
  }

  /// Clear all session data
  void _clearSessionData() {
    _currentSession = null;
    _pausedSession = null;
    _sessionStartTime = null;
    _totalPausedDuration = Duration.zero;
    _currentDuration = Duration.zero;
    _currentAmplitude = 0.0;
  }

  /// Map failure types to error types
  AudioRecorderErrorType _mapFailureToErrorType(dynamic failureType) {
    // Map specific failure types to BLoC error types
    switch (failureType.toString()) {
      case 'RecordingFailureType.permission':
        return AudioRecorderErrorType.permission;
      case 'RecordingFailureType.audioService':
        return AudioRecorderErrorType.audioService;
      case 'RecordingFailureType.fileSystem':
        return AudioRecorderErrorType.fileSystem;
      case 'RecordingFailureType.validation':
        return AudioRecorderErrorType.validation;
      case 'RecordingFailureType.state':
        return AudioRecorderErrorType.invalidState;
      default:
        return AudioRecorderErrorType.unexpected;
    }
  }

  // ==== PUBLIC GETTERS ====

  /// Get current recording session
  RecordingSession? get currentSession => _currentSession;

  /// Get current paused session
  PausedRecordingSession? get pausedSession => _pausedSession;

  /// Check if currently recording
  bool get isRecording => state is AudioRecorderRecording;

  /// Check if currently paused
  bool get isPaused => state is AudioRecorderPaused;

  /// Check if has active session
  bool get hasActiveSession => _currentSession != null;

  /// Get current session duration
  Duration get currentDuration => _currentDuration;

  /// Get effective recording duration (excluding pauses)
  Duration get effectiveDuration => _currentDuration - _totalPausedDuration;

  /// Get current amplitude
  double get currentAmplitude => _currentAmplitude;
}