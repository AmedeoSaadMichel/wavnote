// File: domain/usecases/recording/pause_recording_usecase.dart
//
// Pause/Resume Recording Use Case - Domain Layer
// ================================================
// Returns Either<Failure, Duration> following the canonical Either pattern
// (CLAUDE.md). Duration is the current recording duration at pause/resume time.
import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../core/errors/failures.dart';
import '../../../core/errors/exceptions.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';

/// Use case for pausing and resuming active audio recording
///
/// Handles all business logic for recording pause/resume operations including:
/// - Recording state validation
/// - Audio service pause/resume coordination
/// - Error handling and state management
/// - Duration preservation across pause/resume cycles
class PauseRecordingUseCase {
  final IAudioServiceRepository _audioService;

  PauseRecordingUseCase({
    required IAudioServiceRepository audioService,
  }) : _audioService = audioService;

  /// Pause the active recording.
  ///
  /// Returns [Either<Failure, Duration>]:
  /// - [Left]  — a [Failure] on error
  /// - [Right] — the current duration at the moment of pausing
  Future<Either<Failure, Duration>> executePause() async {
    try {
      if (!await _audioService.isRecording()) {
        return Left(AudioRecordingFailure(
          message: 'No active recording to pause',
          errorType: AudioRecordingErrorType.recordingStartFailed,
          code: 'NO_ACTIVE_RECORDING',
        ));
      }
      if (await _audioService.isRecordingPaused()) {
        return Left(AudioRecordingFailure(
          message: 'Recording is already paused',
          errorType: AudioRecordingErrorType.recordingStartFailed,
          code: 'ALREADY_PAUSED',
        ));
      }

      final duration = await _audioService.getCurrentRecordingDuration();
      final success = await _audioService.pauseRecording();

      if (!success) {
        return Left(AudioRecordingFailure(
          message: 'Failed to pause recording',
          errorType: AudioRecordingErrorType.recordingInterrupted,
          code: 'PAUSE_FAILED',
        ));
      }
      return Right(duration);
    } catch (e, st) {
      debugPrint('❌ PauseRecordingUseCase.executePause: $e\n$st');
      return Left(UnexpectedFailure(
        message: 'Unexpected error pausing recording: $e',
        code: 'PAUSE_UNEXPECTED',
      ));
    }
  }

  /// Resume the paused recording.
  ///
  /// Returns [Either<Failure, Duration>]:
  /// - [Left]  — a [Failure] on error
  /// - [Right] — the current duration at the moment of resuming
  Future<Either<Failure, Duration>> executeResume() async {
    try {
      if (!await _audioService.isRecordingPaused()) {
        return Left(AudioRecordingFailure(
          message: 'Recording is not currently paused',
          errorType: AudioRecordingErrorType.recordingStartFailed,
          code: 'NOT_PAUSED',
        ));
      }

      final duration = await _audioService.getCurrentRecordingDuration();
      final success = await _audioService.resumeRecording();

      if (!success) {
        return Left(AudioRecordingFailure(
          message: 'Failed to resume recording',
          errorType: AudioRecordingErrorType.recordingInterrupted,
          code: 'RESUME_FAILED',
        ));
      }
      return Right(duration);
    } catch (e, st) {
      debugPrint('❌ PauseRecordingUseCase.executeResume: $e\n$st');
      return Left(UnexpectedFailure(
        message: 'Unexpected error resuming recording: $e',
        code: 'RESUME_UNEXPECTED',
      ));
    }
  }

  /// Get the current recording state
  ///
  /// Returns [RecordingStateResult] with current state information
  Future<RecordingStateResult> getCurrentState() async {
    try {
      debugPrint('🔍 PauseRecordingUseCase: Checking current recording state...');

      final isRecording = await _audioService.isRecording();
      if (!isRecording) {
        return RecordingStateResult.idle();
      }

      final isPaused = await _audioService.isRecordingPaused();
      final currentDuration = await _audioService.getCurrentRecordingDuration();

      debugPrint('📊 PauseRecordingUseCase: State - Recording: $isRecording, Paused: $isPaused, Duration: ${currentDuration.inMilliseconds}ms');

      if (isPaused) {
        return RecordingStateResult.paused(duration: currentDuration);
      } else {
        return RecordingStateResult.recording(duration: currentDuration);
      }

    } catch (e) {
      debugPrint('❌ PauseRecordingUseCase: Error getting current state: $e');
      return RecordingStateResult.error('Failed to get recording state: $e');
    }
  }
}


/// Result class for recording state query
class RecordingStateResult {
  final RecordingState state;
  final Duration? duration;
  final String? errorMessage;

  const RecordingStateResult._({
    required this.state,
    this.duration,
    this.errorMessage,
  });

  /// Create idle state result
  factory RecordingStateResult.idle() =>
      const RecordingStateResult._(state: RecordingState.idle);

  /// Create recording state result
  factory RecordingStateResult.recording({required Duration duration}) =>
      RecordingStateResult._(
        state: RecordingState.recording,
        duration: duration,
      );

  /// Create paused state result
  factory RecordingStateResult.paused({required Duration duration}) =>
      RecordingStateResult._(
        state: RecordingState.paused,
        duration: duration,
      );

  /// Create error state result
  factory RecordingStateResult.error(String message) =>
      RecordingStateResult._(
        state: RecordingState.error,
        errorMessage: message,
      );

  @override
  String toString() {
    return 'RecordingStateResult(state: $state, duration: ${duration?.inMilliseconds}ms, error: $errorMessage)';
  }
}

/// Types of operations for pause/resume
enum PauseRecordingOperation {
  pause,
  resume,
}

/// Recording state enum
enum RecordingState {
  idle,
  recording,
  paused,
  error,
}

/// Types of errors that can occur during pause/resume operations
enum PauseRecordingErrorType {
  noActiveRecording,
  alreadyPaused,
  notPaused,
  audioServiceError,
  invalidState,
  unknown,
}

/// Extension to get user-friendly error messages
extension PauseRecordingErrorTypeExtension on PauseRecordingErrorType {
  String get userMessage {
    switch (this) {
      case PauseRecordingErrorType.noActiveRecording:
        return 'No active recording session';
      case PauseRecordingErrorType.alreadyPaused:
        return 'Recording is already paused';
      case PauseRecordingErrorType.notPaused:
        return 'Recording is not currently paused';
      case PauseRecordingErrorType.audioServiceError:
        return 'Audio service error';
      case PauseRecordingErrorType.invalidState:
        return 'Invalid recording state';
      case PauseRecordingErrorType.unknown:
        return 'An unexpected error occurred';
    }
  }
}