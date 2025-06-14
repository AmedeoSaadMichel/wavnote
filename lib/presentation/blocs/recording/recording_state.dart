// File: presentation/blocs/recording/recording_state.dart
part of 'recording_bloc.dart';

/// Base class for all recording states
abstract class RecordingState extends Equatable {
  const RecordingState();

  @override
  List<Object?> get props => [];

  /// Whether recording is currently active
  bool get isRecording => this is RecordingInProgress;

  /// Whether recording is paused
  bool get isPaused => this is RecordingPaused;

  /// Whether recording can be started
  bool get canStartRecording => this is RecordingInitial || this is RecordingCompleted || this is RecordingCancelled;

  /// Whether recording can be stopped
  bool get canStopRecording => this is RecordingInProgress || this is RecordingPaused;

  /// Whether recording can be paused
  bool get canPauseRecording => this is RecordingInProgress;

  /// Whether recording can be resumed
  bool get canResumeRecording => this is RecordingPaused;

  /// Whether recording can be cancelled
  bool get canCancelRecording => this is RecordingInProgress || this is RecordingPaused;
}

/// Initial state when no recording is active
class RecordingInitial extends RecordingState {
  const RecordingInitial();

  @override
  String toString() => 'RecordingInitial';
}

/// State when starting recording
class RecordingStarting extends RecordingState {
  const RecordingStarting();

  @override
  String toString() => 'RecordingStarting';
}

/// State when recording is in progress
class RecordingInProgress extends RecordingState {
  final String filePath;
  final String folderId;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final Duration duration;
  final double amplitude;
  final DateTime startTime;

  const RecordingInProgress({
    required this.filePath,
    required this.folderId,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    required this.duration,
    required this.amplitude,
    required this.startTime,
  });

  @override
  List<Object> get props => [
    filePath, folderId, format, sampleRate, bitRate,
    duration, amplitude, startTime
  ];

  /// Duration in formatted string
  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Amplitude as percentage (0-100)
  int get amplitudePercentage => (amplitude * 100).round();

  /// Copy with updated values
  RecordingInProgress copyWith({
    String? filePath,
    String? folderId,
    AudioFormat? format,
    int? sampleRate,
    int? bitRate,
    Duration? duration,
    double? amplitude,
    DateTime? startTime,
  }) {
    return RecordingInProgress(
      filePath: filePath ?? this.filePath,
      folderId: folderId ?? this.folderId,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      bitRate: bitRate ?? this.bitRate,
      duration: duration ?? this.duration,
      amplitude: amplitude ?? this.amplitude,
      startTime: startTime ?? this.startTime,
    );
  }

  @override
  String toString() => 'RecordingInProgress { duration: $durationFormatted, amplitude: $amplitudePercentage% }';
}

/// State when recording is paused
class RecordingPaused extends RecordingState {
  final String filePath;
  final String folderId;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final Duration duration;
  final double amplitude;
  final DateTime startTime;
  final DateTime pausedAt;

  const RecordingPaused({
    required this.filePath,
    required this.folderId,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    required this.duration,
    required this.amplitude,
    required this.startTime,
    required this.pausedAt,
  });

  @override
  List<Object> get props => [
    filePath, folderId, format, sampleRate, bitRate,
    duration, amplitude, startTime, pausedAt
  ];

  /// Duration in formatted string
  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() => 'RecordingPaused { duration: $durationFormatted }';
}

/// State when stopping recording
class RecordingStopping extends RecordingInProgress {
  const RecordingStopping({
    required super.filePath,
    required super.folderId,
    required super.format,
    required super.sampleRate,
    required super.bitRate,
    required super.duration,
    required super.amplitude,
    required super.startTime,
  });

  @override
  String toString() => 'RecordingStopping { duration: $durationFormatted }';
}

/// State when recording is completed
class RecordingCompleted extends RecordingState {
  final RecordingEntity recording;
  final bool wasSuccessful;

  const RecordingCompleted({
    required this.recording,
    required this.wasSuccessful,
  });

  @override
  List<Object> get props => [recording, wasSuccessful];

  @override
  String toString() => 'RecordingCompleted { recording: ${recording.name}, successful: $wasSuccessful }';
}

/// State when recording is cancelled
class RecordingCancelled extends RecordingState {
  const RecordingCancelled();

  @override
  String toString() => 'RecordingCancelled';
}

/// State when recording permissions are being checked/requested
class RecordingPermissionRequesting extends RecordingState {
  const RecordingPermissionRequesting();

  @override
  String toString() => 'RecordingPermissionRequesting';
}

/// State with permission status information
class RecordingPermissionStatus extends RecordingState {
  final bool hasMicrophonePermission;
  final bool hasMicrophone;

  const RecordingPermissionStatus({
    required this.hasMicrophonePermission,
    required this.hasMicrophone,
  });

  @override
  List<Object> get props => [hasMicrophonePermission, hasMicrophone];

  /// Whether recording is possible
  bool get canRecord => hasMicrophonePermission && hasMicrophone;

  @override
  String toString() => 'RecordingPermissionStatus { micPermission: $hasMicrophonePermission, hasMic: $hasMicrophone }';
}

/// State when an error occurs
class RecordingError extends RecordingState {
  final String message;
  final RecordingErrorType errorType;
  final String? errorCode;
  final dynamic error;

  const RecordingError(
      this.message, {
        this.errorType = RecordingErrorType.unknown,
        this.errorCode,
        this.error,
      });

  @override
  List<Object?> get props => [message, errorType, errorCode, error];

  /// Whether this is a permission error
  bool get isPermissionError => errorType == RecordingErrorType.permission;

  /// Whether this is a recording error
  bool get isRecordingError => errorType == RecordingErrorType.recording;

  /// Whether this is a state error
  bool get isStateError => errorType == RecordingErrorType.state;

  /// Whether this is a file system error
  bool get isFileSystemError => errorType == RecordingErrorType.fileSystem;

  @override
  String toString() => 'RecordingError { message: $message, type: $errorType }';
}

/// Types of recording errors
enum RecordingErrorType {
  permission,
  recording,
  fileSystem,
  state,
  network,
  unknown,
}

extension RecordingErrorTypeExtension on RecordingErrorType {
  String get displayName {
    switch (this) {
      case RecordingErrorType.permission:
        return 'Permission Error';
      case RecordingErrorType.recording:
        return 'Recording Error';
      case RecordingErrorType.fileSystem:
        return 'File System Error';
      case RecordingErrorType.state:
        return 'State Error';
      case RecordingErrorType.network:
        return 'Network Error';
      case RecordingErrorType.unknown:
        return 'Unknown Error';
    }
  }
}