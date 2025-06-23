// File: presentation/bloc/recording/recording_state.dart
part of 'recording_bloc.dart';

/// Base class for all recording states
abstract class RecordingState extends Equatable {
  const RecordingState();

  @override
  List<Object?> get props => [];

  // ==== CONVENIENCE GETTERS ====

  /// Whether currently recording
  bool get isRecording => this is RecordingInProgress;

  /// Whether recording is paused
  bool get isPaused => this is RecordingPaused;

  /// Whether can start recording
  bool get canStartRecording {
    return this is RecordingInitial ||
        this is RecordingPermissionStatus ||
        this is RecordingCompleted ||
        this is RecordingCancelled ||
        this is RecordingLoaded; // Can start recording while viewing recordings
  }

  /// Whether can stop recording
  bool get canStopRecording {
    return this is RecordingInProgress || this is RecordingPaused;
  }

  /// Whether can pause recording
  bool get canPauseRecording => this is RecordingInProgress;

  /// Whether can resume recording
  bool get canResumeRecording => this is RecordingPaused;

  /// Whether recording operations are available
  bool get isOperational {
    if (this is RecordingPermissionStatus) {
      return (this as RecordingPermissionStatus).canRecord;
    }
    return !(this is RecordingError || this is RecordingPermissionRequesting);
  }

  /// Get current recording duration if available
  Duration? get currentDuration {
    if (this is RecordingInProgress) {
      return (this as RecordingInProgress).duration;
    }
    if (this is RecordingPaused) {
      return (this as RecordingPaused).duration;
    }
    return null;
  }

  /// Get formatted duration string
  String get durationFormatted {
    final duration = currentDuration;
    if (duration == null) return '0:00';

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Initial state when recording bloc is created
class RecordingInitial extends RecordingState {
  const RecordingInitial();
}

/// State when recording is starting
class RecordingStarting extends RecordingState {
  const RecordingStarting();
}

/// State when recording is in progress
class RecordingInProgress extends RecordingState {
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

  const RecordingInProgress({
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

  RecordingInProgress copyWith({
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
    return RecordingInProgress(
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
class RecordingPaused extends RecordingState {
  final String filePath;
  final String? folderId;
  final String? folderName;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final Duration duration;
  final DateTime startTime;

  const RecordingPaused({
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

  RecordingPaused copyWith({
    String? filePath,
    String? folderId,
    String? folderName,
    AudioFormat? format,
    int? sampleRate,
    int? bitRate,
    Duration? duration,
    DateTime? startTime,
  }) {
    return RecordingPaused(
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
class RecordingStopping extends RecordingState {
  const RecordingStopping();
}

/// State when recording is completed
class RecordingCompleted extends RecordingState {
  final RecordingEntity recording;

  const RecordingCompleted({required this.recording});

  @override
  List<Object> get props => [recording];
}

/// State when recording is cancelled
class RecordingCancelled extends RecordingState {
  const RecordingCancelled();
}

/// State when loading recordings
class RecordingLoading extends RecordingState {
  const RecordingLoading();
}

/// State when recordings are loaded
class RecordingLoaded extends RecordingState {
  final List<RecordingEntity> recordings;
  final bool isEditMode;
  final Set<String> selectedRecordings;

  const RecordingLoaded(
    this.recordings, {
    this.isEditMode = false,
    this.selectedRecordings = const <String>{},
  });

  @override
  List<Object?> get props => [recordings, isEditMode, selectedRecordings];

  RecordingLoaded copyWith({
    List<RecordingEntity>? recordings,
    bool? isEditMode,
    Set<String>? selectedRecordings,
  }) {
    return RecordingLoaded(
      recordings ?? this.recordings,
      isEditMode: isEditMode ?? this.isEditMode,
      selectedRecordings: selectedRecordings ?? this.selectedRecordings,
    );
  }
}

/// State when checking permissions
class RecordingPermissionRequesting extends RecordingState {
  const RecordingPermissionRequesting();
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
}

/// State when an error occurs
class RecordingError extends RecordingState {
  final String message;
  final RecordingErrorType errorType;

  const RecordingError(
      this.message, {
        this.errorType = RecordingErrorType.unknown,
      });

  @override
  List<Object> get props => [message, errorType];

  /// Whether this is a permission-related error
  bool get isPermissionError => errorType == RecordingErrorType.permission;
}

/// Types of recording errors
enum RecordingErrorType {
  permission,
  recording,
  state,
  unknown,
}