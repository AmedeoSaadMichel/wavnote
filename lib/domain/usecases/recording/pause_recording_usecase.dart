// File: domain/usecases/recording/pause_recording_usecase.dart
import 'package:dartz/dartz.dart';
import '../../repositories/i_audio_service_repository.dart';
import 'start_recording_usecase.dart';

/// Use case for pausing and resuming audio recording
///
/// Handles the complete flow of recording pause/resume including:
/// - Recording state validation
/// - Audio service pause/resume
/// - Duration tracking
/// - State management
/// - Error handling
class PauseRecordingUseCase {
  final IAudioServiceRepository _audioServiceRepository;

  const PauseRecordingUseCase({
    required IAudioServiceRepository audioServiceRepository,
  }) : _audioServiceRepository = audioServiceRepository;

  /// Pause active recording
  Future<Either<RecordingFailure, PausedRecordingSession>> pause(
      PauseRecordingParams params,
      ) async {
    try {
      // 1. Validate recording session
      final validationResult = await _validateActiveRecording(params.session);
      if (validationResult.isLeft()) {
        return Left(validationResult.fold((l) => l, (r) => throw Exception()));
      }

      // 2. Check if recording is already paused
      final isAlreadyPaused = await _audioServiceRepository.isRecordingPaused();
      if (isAlreadyPaused) {
        return Left(RecordingFailure.stateError('Recording is already paused'));
      }

      // 3. Get current recording duration before pausing
      final currentDuration = await _audioServiceRepository.getCurrentRecordingDuration();

      // 4. Pause recording
      final pauseResult = await _audioServiceRepository.pauseRecording();
      if (!pauseResult) {
        return Left(RecordingFailure.audioServiceError('Failed to pause recording'));
      }

      // 5. Create paused session
      final pausedSession = PausedRecordingSession(
        originalSession: params.session,
        pausedAt: DateTime.now(),
        durationAtPause: currentDuration,
        previousPausedDuration: params.existingPausedDuration ?? Duration.zero,
      );

      return Right(pausedSession);
    } catch (e) {
      return Left(RecordingFailure.unexpected('Failed to pause recording: $e'));
    }
  }

  /// Resume paused recording
  Future<Either<RecordingFailure, RecordingSession>> resume(
      ResumeRecordingParams params,
      ) async {
    try {
      // 1. Validate paused session
      final validationResult = await _validatePausedRecording(params.pausedSession);
      if (validationResult.isLeft()) {
        return Left(validationResult.fold((l) => l, (r) => throw Exception()));
      }

      // 2. Check if recording is actually paused
      final isPaused = await _audioServiceRepository.isRecordingPaused();
      if (!isPaused) {
        return Left(RecordingFailure.stateError('Recording is not currently paused'));
      }

      // 3. Resume recording
      final resumeResult = await _audioServiceRepository.resumeRecording();
      if (!resumeResult) {
        return Left(RecordingFailure.audioServiceError('Failed to resume recording'));
      }

      // 4. Calculate total paused time
      final pauseDuration = DateTime.now().difference(params.pausedSession.pausedAt);
      final totalPausedDuration = params.pausedSession.previousPausedDuration + pauseDuration;

      // 5. Create resumed session
      final resumedSession = RecordingSession(
        filePath: params.pausedSession.originalSession.filePath,
        folderId: params.pausedSession.originalSession.folderId,
        format: params.pausedSession.originalSession.format,
        sampleRate: params.pausedSession.originalSession.sampleRate,
        bitRate: params.pausedSession.originalSession.bitRate,
        startTime: params.pausedSession.originalSession.startTime,
        customName: params.pausedSession.originalSession.customName,
        latitude: params.pausedSession.originalSession.latitude,
        longitude: params.pausedSession.originalSession.longitude,
        locationName: params.pausedSession.originalSession.locationName,
        tags: params.pausedSession.originalSession.tags,
      );

      return Right(resumedSession);
    } catch (e) {
      return Left(RecordingFailure.unexpected('Failed to resume recording: $e'));
    }
  }

  /// Toggle pause/resume state
  Future<Either<RecordingFailure, RecordingSessionState>> toggle(
      TogglePauseParams params,
      ) async {
    try {
      // Check current recording state
      final isRecording = await _audioServiceRepository.isRecording();
      if (!isRecording) {
        return Left(RecordingFailure.stateError('No active recording to pause/resume'));
      }

      final isPaused = await _audioServiceRepository.isRecordingPaused();

      if (isPaused && params.pausedSession != null) {
        // Resume recording
        final resumeParams = ResumeRecordingParams(pausedSession: params.pausedSession!);
        final resumeResult = await resume(resumeParams);

        return resumeResult.fold(
              (failure) => Left(failure),
              (session) => Right(RecordingSessionState.active(session)),
        );
      } else if (!isPaused && params.activeSession != null) {
        // Pause recording
        final pauseParams = PauseRecordingParams(session: params.activeSession!);
        final pauseResult = await pause(pauseParams);

        return pauseResult.fold(
              (failure) => Left(failure),
              (pausedSession) => Right(RecordingSessionState.paused(pausedSession)),
        );
      } else {
        return Left(RecordingFailure.stateError('Invalid session state for toggle operation'));
      }
    } catch (e) {
      return Left(RecordingFailure.unexpected('Failed to toggle recording state: $e'));
    }
  }

  /// Get current recording state and duration
  Future<Either<RecordingFailure, RecordingStateInfo>> getRecordingState() async {
    try {
      final isRecording = await _audioServiceRepository.isRecording();

      if (!isRecording) {
        return Right(RecordingStateInfo.idle());
      }

      final isPaused = await _audioServiceRepository.isRecordingPaused();
      final currentDuration = await _audioServiceRepository.getCurrentRecordingDuration();

      if (isPaused) {
        return Right(RecordingStateInfo.paused(currentDuration));
      } else {
        return Right(RecordingStateInfo.active(currentDuration));
      }
    } catch (e) {
      return Left(RecordingFailure.audioServiceError('Failed to get recording state: $e'));
    }
  }

  /// Validate active recording session
  Future<Either<RecordingFailure, void>> _validateActiveRecording(
      RecordingSession session,
      ) async {
    try {
      final isRecording = await _audioServiceRepository.isRecording();
      if (!isRecording) {
        return Left(RecordingFailure.stateError('No active recording session'));
      }

      // Check if session is still valid (not too old)
      final sessionAge = DateTime.now().difference(session.startTime);
      if (sessionAge.inHours > 24) {
        return Left(RecordingFailure.stateError('Recording session is too old'));
      }

      return const Right(null);
    } catch (e) {
      return Left(RecordingFailure.stateError('Failed to validate recording session: $e'));
    }
  }

  /// Validate paused recording session
  Future<Either<RecordingFailure, void>> _validatePausedRecording(
      PausedRecordingSession pausedSession,
      ) async {
    try {
      final isRecording = await _audioServiceRepository.isRecording();
      if (!isRecording) {
        return Left(RecordingFailure.stateError('No recording session to resume'));
      }

      // Check if pause duration is reasonable
      final pauseDuration = DateTime.now().difference(pausedSession.pausedAt);
      if (pauseDuration.inHours > 1) {
        return Left(RecordingFailure.stateError('Recording has been paused too long'));
      }

      return const Right(null);
    } catch (e) {
      return Left(RecordingFailure.stateError('Failed to validate paused session: $e'));
    }
  }
}

/// Parameters for pausing recording
class PauseRecordingParams {
  final RecordingSession session;
  final Duration? existingPausedDuration; // Track any previous pauses

  const PauseRecordingParams({
    required this.session,
    this.existingPausedDuration,
  });
}

/// Parameters for resuming recording
class ResumeRecordingParams {
  final PausedRecordingSession pausedSession;

  const ResumeRecordingParams({required this.pausedSession});
}

/// Parameters for toggling pause/resume
class TogglePauseParams {
  final RecordingSession? activeSession;
  final PausedRecordingSession? pausedSession;

  const TogglePauseParams({
    this.activeSession,
    this.pausedSession,
  });

  /// Create params for active session
  factory TogglePauseParams.fromActive(RecordingSession session) {
    return TogglePauseParams(activeSession: session);
  }

  /// Create params for paused session
  factory TogglePauseParams.fromPaused(PausedRecordingSession pausedSession) {
    return TogglePauseParams(pausedSession: pausedSession);
  }
}

/// Paused recording session data
class PausedRecordingSession {
  final RecordingSession originalSession;
  final DateTime pausedAt;
  final Duration durationAtPause;
  final Duration previousPausedDuration; // Cumulative pause time from previous pauses

  const PausedRecordingSession({
    required this.originalSession,
    required this.pausedAt,
    required this.durationAtPause,
    required this.previousPausedDuration,
  });

  /// Get current pause duration
  Duration get currentPauseDuration => DateTime.now().difference(pausedAt);

  /// Get total pause duration including current pause
  Duration get totalPauseDurationIncludingCurrent =>
      previousPausedDuration + currentPauseDuration;

  /// Get effective recording duration (actual recorded time)
  Duration get effectiveRecordingDuration =>
      durationAtPause - previousPausedDuration;

  /// Check if pause is getting too long
  bool get isPauseTooLong => currentPauseDuration.inMinutes > 30;

  /// Get formatted pause duration
  String get pauseDurationFormatted {
    final duration = currentPauseDuration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Extended recording session with pause tracking
class RecordingSessionWithPause {
  final RecordingSession baseSession;
  final Duration totalPausedDuration;

  const RecordingSessionWithPause({
    required this.baseSession,
    required this.totalPausedDuration,
  });

  /// Get current recording duration
  Duration get currentDuration => DateTime.now().difference(baseSession.startTime);

  /// Get formatted duration string
  String get formattedDuration {
    final duration = currentDuration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get effective recording duration (excluding pauses)
  Duration get effectiveDuration => currentDuration - totalPausedDuration;

  /// Get formatted effective duration
  String get effectiveDurationFormatted {
    final duration = effectiveDuration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Create new session with updated pause duration
  RecordingSessionWithPause withPauseDuration(Duration newPauseDuration) {
    return RecordingSessionWithPause(
      baseSession: baseSession,
      totalPausedDuration: newPauseDuration,
    );
  }
}

/// Recording session state union
abstract class RecordingSessionState {
  const RecordingSessionState();

  factory RecordingSessionState.active(RecordingSession session) = ActiveRecordingState;
  factory RecordingSessionState.paused(PausedRecordingSession pausedSession) = PausedRecordingState;
}

class ActiveRecordingState extends RecordingSessionState {
  final RecordingSession session;
  const ActiveRecordingState(this.session);
}

class PausedRecordingState extends RecordingSessionState {
  final PausedRecordingSession pausedSession;
  const PausedRecordingState(this.pausedSession);
}

/// Recording state information
class RecordingStateInfo {
  final RecordingState state;
  final Duration? currentDuration;

  const RecordingStateInfo({
    required this.state,
    this.currentDuration,
  });

  factory RecordingStateInfo.idle() {
    return const RecordingStateInfo(state: RecordingState.idle);
  }

  factory RecordingStateInfo.active(Duration duration) {
    return RecordingStateInfo(
      state: RecordingState.recording,
      currentDuration: duration,
    );
  }

  factory RecordingStateInfo.paused(Duration duration) {
    return RecordingStateInfo(
      state: RecordingState.paused,
      currentDuration: duration,
    );
  }

  /// Get formatted duration
  String get durationFormatted {
    if (currentDuration == null) return '0:00';
    final minutes = currentDuration!.inMinutes;
    final seconds = currentDuration!.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if recording is active
  bool get isRecording => state == RecordingState.recording;

  /// Check if recording is paused
  bool get isPaused => state == RecordingState.paused;

  /// Check if recording is idle
  bool get isIdle => state == RecordingState.idle;
}

/// Recording states
enum RecordingState {
  idle,
  recording,
  paused,
}

/// Recording failure types for error handling
class RecordingFailure {
  final String message;
  final RecordingFailureType type;

  const RecordingFailure._(this.message, this.type);

  factory RecordingFailure.audioServiceError(String message) =>
      RecordingFailure._(message, RecordingFailureType.audioService);

  factory RecordingFailure.stateError(String message) =>
      RecordingFailure._(message, RecordingFailureType.state);

  factory RecordingFailure.unexpected(String message) =>
      RecordingFailure._(message, RecordingFailureType.unexpected);

  @override
  String toString() => 'RecordingFailure: $message (${type.name})';
}

/// Types of recording failures
enum RecordingFailureType {
  audioService,
  state,
  unexpected,
}