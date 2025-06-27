// File: presentation/bloc/recording_lifecycle/recording_lifecycle_state.dart
part of 'recording_lifecycle_bloc.dart';

/// Base class for all recording lifecycle states
abstract class RecordingLifecycleState extends Equatable {
  const RecordingLifecycleState();

  @override
  List<Object?> get props => [];

  /// Whether currently recording
  bool get isRecording => this is RecordingLifecycleInProgress;

  /// Whether recording is paused
  bool get isPaused => this is RecordingLifecyclePaused;

  /// Whether can start recording
  bool get canStartRecording {
    return this is RecordingLifecycleInitial ||
        this is RecordingLifecycleCompleted ||
        this is RecordingLifecycleCancelled;
  }

  /// Whether can stop recording
  bool get canStopRecording {
    return this is RecordingLifecycleInProgress || this is RecordingLifecyclePaused;
  }

  /// Whether can pause recording
  bool get canPauseRecording => this is RecordingLifecycleInProgress;

  /// Whether can resume recording
  bool get canResumeRecording => this is RecordingLifecyclePaused;

  /// Get current recording duration if available
  Duration? get currentDuration {
    if (this is RecordingLifecycleInProgress) {
      return (this as RecordingLifecycleInProgress).duration;
    }
    if (this is RecordingLifecyclePaused) {
      return (this as RecordingLifecyclePaused).duration;
    }
    return null;
  }
}

/// Initial state when recording lifecycle bloc is created
class RecordingLifecycleInitial extends RecordingLifecycleState {
  const RecordingLifecycleInitial();
}

/// State when recording is starting
class RecordingLifecycleStarting extends RecordingLifecycleState {
  const RecordingLifecycleStarting();
}

/// State when recording is in progress
class RecordingLifecycleInProgress extends RecordingLifecycleState {
  final String filePath;
  final String? folderId;
  final String? folderName;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final Duration duration;
  final double amplitude;
  final DateTime startTime;
  final String? title;

  const RecordingLifecycleInProgress({
    required this.filePath,
    this.folderId,
    this.folderName,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    required this.duration,
    required this.amplitude,
    required this.startTime,
    this.title,
  });

  @override
  List<Object?> get props => [
    filePath, folderId, folderName, format, sampleRate, bitRate,
    duration, amplitude, startTime, title
  ];

  RecordingLifecycleInProgress copyWith({
    String? filePath,
    String? folderId,
    String? folderName,
    AudioFormat? format,
    int? sampleRate,
    int? bitRate,
    Duration? duration,
    double? amplitude,
    DateTime? startTime,
    String? title,
  }) {
    return RecordingLifecycleInProgress(
      filePath: filePath ?? this.filePath,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      bitRate: bitRate ?? this.bitRate,
      duration: duration ?? this.duration,
      amplitude: amplitude ?? this.amplitude,
      startTime: startTime ?? this.startTime,
      title: title ?? this.title,
    );
  }
}

/// State when recording is paused
class RecordingLifecyclePaused extends RecordingLifecycleState {
  final String filePath;
  final String? folderId;
  final String? folderName;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final Duration duration;
  final DateTime startTime;

  const RecordingLifecyclePaused({
    required this.filePath,
    this.folderId,
    this.folderName,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    required this.duration,
    required this.startTime,
  });

  @override
  List<Object?> get props => [
    filePath, folderId, folderName, format, sampleRate, bitRate, duration, startTime
  ];

  RecordingLifecyclePaused copyWith({
    String? filePath,
    String? folderId,
    String? folderName,
    AudioFormat? format,
    int? sampleRate,
    int? bitRate,
    Duration? duration,
    DateTime? startTime,
  }) {
    return RecordingLifecyclePaused(
      filePath: filePath ?? this.filePath,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      bitRate: bitRate ?? this.bitRate,
      duration: duration ?? this.duration,
      startTime: startTime ?? this.startTime,
    );
  }
}

/// State when recording is stopping
class RecordingLifecycleStopping extends RecordingLifecycleState {
  const RecordingLifecycleStopping();
}

/// State when recording is completed
class RecordingLifecycleCompleted extends RecordingLifecycleState {
  final RecordingEntity recording;

  const RecordingLifecycleCompleted({required this.recording});

  @override
  List<Object> get props => [recording];
}

/// State when recording is cancelled
class RecordingLifecycleCancelled extends RecordingLifecycleState {
  const RecordingLifecycleCancelled();
}

/// State when an error occurs
class RecordingLifecycleError extends RecordingLifecycleState {
  final String message;

  const RecordingLifecycleError(this.message);

  @override
  List<Object> get props => [message];
}