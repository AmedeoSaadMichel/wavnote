// File: domain/usecases/recording/pause_recording_usecase.dart
import 'dart:async';
import '../../../domain/repositories/i_audio_service_repository.dart';
import 'package:flutter/foundation.dart';

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

  /// Execute the pause recording process
  ///
  /// Returns [PauseRecordingResult] containing success status or error info
  Future<PauseRecordingResult> executePause() async {
    try {
      debugPrint('⏸️ PauseRecordingUseCase: Pausing recording...');

      // Step 1: Validate there's an active recording
      final isRecording = await _audioService.isRecording();
      if (!isRecording) {
        debugPrint('❌ PauseRecordingUseCase: No active recording to pause');
        return PauseRecordingResult.failure(
          'No active recording to pause',
          PauseRecordingErrorType.noActiveRecording,
        );
      }

      // Step 2: Check if recording is already paused
      final isPaused = await _audioService.isRecordingPaused();
      if (isPaused) {
        debugPrint('⚠️ PauseRecordingUseCase: Recording is already paused');
        return PauseRecordingResult.failure(
          'Recording is already paused',
          PauseRecordingErrorType.alreadyPaused,
        );
      }

      // Step 3: Get current duration before pausing
      final currentDuration = await _audioService.getCurrentRecordingDuration();
      debugPrint('⏱️ PauseRecordingUseCase: Current duration before pause: ${currentDuration.inMilliseconds}ms');

      // Step 4: Pause the recording
      final success = await _audioService.pauseRecording();
      
      if (success) {
        debugPrint('✅ PauseRecordingUseCase: Recording paused successfully');
        return PauseRecordingResult.successPause(
          pausedDuration: currentDuration,
        );
      } else {
        debugPrint('❌ PauseRecordingUseCase: Audio service failed to pause recording');
        return PauseRecordingResult.failure(
          'Failed to pause recording',
          PauseRecordingErrorType.audioServiceError,
        );
      }

    } catch (e, stackTrace) {
      debugPrint('❌ PauseRecordingUseCase: Unexpected error during pause: $e');
      debugPrint('📍 PauseRecordingUseCase: Stack trace: $stackTrace');
      return PauseRecordingResult.failure(
        'Unexpected error during recording pause: $e',
        PauseRecordingErrorType.unknown,
      );
    }
  }

  /// Execute the resume recording process
  ///
  /// Returns [PauseRecordingResult] containing success status or error info
  Future<PauseRecordingResult> executeResume() async {
    try {
      debugPrint('▶️ PauseRecordingUseCase: Resuming recording...');

      // Step 1: Validate there's an active recording session
      final isRecording = await _audioService.isRecording();
      if (!isRecording) {
        debugPrint('❌ PauseRecordingUseCase: No recording session to resume');
        return PauseRecordingResult.failure(
          'No recording session to resume',
          PauseRecordingErrorType.noActiveRecording,
        );
      }

      // Step 2: Check if recording is actually paused
      final isPaused = await _audioService.isRecordingPaused();
      if (!isPaused) {
        debugPrint('⚠️ PauseRecordingUseCase: Recording is not paused');
        return PauseRecordingResult.failure(
          'Recording is not currently paused',
          PauseRecordingErrorType.notPaused,
        );
      }

      // Step 3: Get current duration before resuming
      final currentDuration = await _audioService.getCurrentRecordingDuration();
      debugPrint('⏱️ PauseRecordingUseCase: Duration before resume: ${currentDuration.inMilliseconds}ms');

      // Step 4: Resume the recording
      final success = await _audioService.resumeRecording();
      
      if (success) {
        debugPrint('✅ PauseRecordingUseCase: Recording resumed successfully');
        return PauseRecordingResult.successResume(
          resumedDuration: currentDuration,
        );
      } else {
        debugPrint('❌ PauseRecordingUseCase: Audio service failed to resume recording');
        return PauseRecordingResult.failure(
          'Failed to resume recording',
          PauseRecordingErrorType.audioServiceError,
        );
      }

    } catch (e, stackTrace) {
      debugPrint('❌ PauseRecordingUseCase: Unexpected error during resume: $e');
      debugPrint('📍 PauseRecordingUseCase: Stack trace: $stackTrace');
      return PauseRecordingResult.failure(
        'Unexpected error during recording resume: $e',
        PauseRecordingErrorType.unknown,
      );
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

/// Result class for pause recording operation
class PauseRecordingResult {
  final bool isSuccess;
  final PauseRecordingOperation? operation;
  final Duration? duration;
  final String? errorMessage;
  final PauseRecordingErrorType? errorType;

  const PauseRecordingResult._({
    required this.isSuccess,
    this.operation,
    this.duration,
    this.errorMessage,
    this.errorType,
  });

  /// Create a successful pause result
  factory PauseRecordingResult.successPause({
    required Duration pausedDuration,
  }) =>
      PauseRecordingResult._(
        isSuccess: true,
        operation: PauseRecordingOperation.pause,
        duration: pausedDuration,
      );

  /// Create a successful resume result
  factory PauseRecordingResult.successResume({
    required Duration resumedDuration,
  }) =>
      PauseRecordingResult._(
        isSuccess: true,
        operation: PauseRecordingOperation.resume,
        duration: resumedDuration,
      );

  /// Create a failure result
  factory PauseRecordingResult.failure(
    String message,
    PauseRecordingErrorType errorType,
  ) =>
      PauseRecordingResult._(
        isSuccess: false,
        errorMessage: message,
        errorType: errorType,
      );

  @override
  String toString() {
    if (isSuccess) {
      return 'PauseRecordingResult.success(operation: $operation, duration: ${duration?.inMilliseconds}ms)';
    } else {
      return 'PauseRecordingResult.failure(error: $errorMessage, type: $errorType)';
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