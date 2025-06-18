// File: core/errors/failure_types/audio_failures.dart
import 'package:equatable/equatable.dart';
import '../failures.dart';
import '../exceptions.dart';

// ==== AUDIO RECORDING FAILURES ====

/// Failure in audio recording operations
class AudioRecordingFailure extends Failure {
  final AudioRecordingErrorType errorType;

  const AudioRecordingFailure({
    required String message,
    required this.errorType,
    String? code,
    FailureSeverity severity = FailureSeverity.error,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    severity: severity,
    context: context,
  );

  /// Create failure from exception
  factory AudioRecordingFailure.fromException(AudioRecordingException exception) {
    return AudioRecordingFailure(
      message: exception.userMessage,
      errorType: exception.errorType,
      code: exception.code,
      context: exception.context,
    );
  }

  /// Create failure for permission denied
  factory AudioRecordingFailure.permissionDenied() {
    return const AudioRecordingFailure(
      message: 'Microphone permission is required to record audio',
      errorType: AudioRecordingErrorType.microphonePermissionDenied,
      code: 'PERMISSION_DENIED',
    );
  }

  /// Create failure for microphone unavailable
  factory AudioRecordingFailure.microphoneUnavailable() {
    return const AudioRecordingFailure(
      message: 'Microphone is currently unavailable',
      errorType: AudioRecordingErrorType.microphoneUnavailable,
      code: 'MICROPHONE_UNAVAILABLE',
    );
  }

  /// Create failure for insufficient storage
  factory AudioRecordingFailure.insufficientStorage() {
    return const AudioRecordingFailure(
      message: 'Not enough storage space to save recording',
      errorType: AudioRecordingErrorType.insufficientStorage,
      code: 'INSUFFICIENT_STORAGE',
    );
  }

  /// Create failure for recording start failed
  factory AudioRecordingFailure.startFailed([String? reason]) {
    return AudioRecordingFailure(
      message: reason ?? 'Could not start recording',
      errorType: AudioRecordingErrorType.recordingStartFailed,
      code: 'START_FAILED',
    );
  }

  /// Create failure for recording stop failed
  factory AudioRecordingFailure.stopFailed([String? reason]) {
    return AudioRecordingFailure(
      message: reason ?? 'Could not stop recording properly',
      errorType: AudioRecordingErrorType.recordingStopFailed,
      code: 'STOP_FAILED',
    );
  }

  @override
  String get userMessage {
    switch (errorType) {
      case AudioRecordingErrorType.microphonePermissionDenied:
        return 'Microphone permission is required to record audio. Please enable it in Settings.';
      case AudioRecordingErrorType.microphoneUnavailable:
        return 'Microphone is not available. Please check if another app is using it.';
      case AudioRecordingErrorType.audioServiceInitializationFailed:
        return 'Failed to initialize audio recording. Please restart the app.';
      case AudioRecordingErrorType.recordingStartFailed:
        return 'Could not start recording. Please try again.';
      case AudioRecordingErrorType.recordingStopFailed:
        return 'Could not stop recording properly. Your recording may be incomplete.';
      case AudioRecordingErrorType.unsupportedAudioFormat:
        return 'The selected audio format is not supported on this device.';
      case AudioRecordingErrorType.insufficientStorage:
        return 'Not enough storage space to save the recording.';
      case AudioRecordingErrorType.audioDeviceError:
        return 'Audio device error occurred. Please check your microphone.';
      case AudioRecordingErrorType.recordingInterrupted:
        return 'Recording was interrupted. Your partial recording has been saved.';
    }
  }

  @override
  bool get isRetryable {
    switch (errorType) {
      case AudioRecordingErrorType.recordingStartFailed:
      case AudioRecordingErrorType.audioDeviceError:
      case AudioRecordingErrorType.recordingInterrupted:
        return true;
      default:
        return false;
    }
  }

  @override
  List<Object?> get props => [...super.props, errorType];
}

// ==== AUDIO PLAYBACK FAILURES ====

/// Failure in audio playback operations
class AudioPlaybackFailure extends Failure {
  final AudioPlaybackErrorType errorType;

  const AudioPlaybackFailure({
    required String message,
    required this.errorType,
    String? code,
    FailureSeverity severity = FailureSeverity.error,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    severity: severity,
    context: context,
  );

  /// Create failure from exception
  factory AudioPlaybackFailure.fromException(AudioPlaybackException exception) {
    return AudioPlaybackFailure(
      message: exception.userMessage,
      errorType: exception.errorType,
      code: exception.code,
      context: exception.context,
    );
  }

  /// Create failure for file not found
  factory AudioPlaybackFailure.fileNotFound(String filePath) {
    return AudioPlaybackFailure(
      message: 'Audio file not found',
      errorType: AudioPlaybackErrorType.audioFileNotFound,
      code: 'FILE_NOT_FOUND',
      context: {'filePath': filePath},
    );
  }

  /// Create failure for corrupted file
  factory AudioPlaybackFailure.fileCorrupted(String filePath) {
    return AudioPlaybackFailure(
      message: 'Audio file is corrupted',
      errorType: AudioPlaybackErrorType.audioFileCorrupted,
      code: 'FILE_CORRUPTED',
      context: {'filePath': filePath},
    );
  }

  /// Create failure for unsupported format
  factory AudioPlaybackFailure.unsupportedFormat(String format) {
    return AudioPlaybackFailure(
      message: 'Unsupported audio format: $format',
      errorType: AudioPlaybackErrorType.unsupportedAudioFormat,
      code: 'UNSUPPORTED_FORMAT',
      context: {'format': format},
    );
  }

  /// Create failure for playback start failed
  factory AudioPlaybackFailure.startFailed([String? reason]) {
    return AudioPlaybackFailure(
      message: reason ?? 'Could not start audio playback',
      errorType: AudioPlaybackErrorType.playbackStartFailed,
      code: 'PLAYBACK_START_FAILED',
    );
  }

  @override
  String get userMessage {
    switch (errorType) {
      case AudioPlaybackErrorType.audioFileNotFound:
        return 'The audio file could not be found. It may have been deleted.';
      case AudioPlaybackErrorType.audioFileCorrupted:
        return 'The audio file appears to be corrupted and cannot be played.';
      case AudioPlaybackErrorType.unsupportedAudioFormat:
        return 'This audio format is not supported for playback.';
      case AudioPlaybackErrorType.playbackInitializationFailed:
        return 'Failed to initialize audio playback. Please try again.';
      case AudioPlaybackErrorType.playbackStartFailed:
        return 'Could not start playing the audio. Please try again.';
      case AudioPlaybackErrorType.audioServiceUnavailable:
        return 'Audio service is currently unavailable. Please restart the app.';
      case AudioPlaybackErrorType.audioDeviceError:
        return 'Audio device error occurred. Please check your speakers/headphones.';
      case AudioPlaybackErrorType.playbackInterrupted:
        return 'Playback was interrupted by another app or system event.';
    }
  }

  @override
  bool get isRetryable {
    switch (errorType) {
      case AudioPlaybackErrorType.playbackStartFailed:
      case AudioPlaybackErrorType.audioDeviceError:
      case AudioPlaybackErrorType.playbackInterrupted:
        return true;
      default:
        return false;
    }
  }

  @override
  List<Object?> get props => [...super.props, errorType];
}