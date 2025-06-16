// File: presentation/blocs/audio_recorder/audio_recorder_state.dart
part of 'audio_recorder_bloc.dart';

/// Base class for all audio recorder states
///
/// States represent the current condition of the recording system
/// and provide data for the UI to render appropriately.
abstract class AudioRecorderState extends Equatable {
  const AudioRecorderState();

  @override
  List<Object?> get props => [];
}

// ==== INITIAL & LOADING STATES ====

/// Initial state when the recorder is ready but not active
class AudioRecorderInitial extends AudioRecorderState {
  const AudioRecorderInitial();

  @override
  String toString() => 'AudioRecorderInitial';
}

/// State when starting a recording session
class AudioRecorderStarting extends AudioRecorderState {
  const AudioRecorderStarting();

  @override
  String toString() => 'AudioRecorderStarting';
}

/// State when stopping a recording session
class AudioRecorderStopping extends AudioRecorderState {
  const AudioRecorderStopping();

  @override
  String toString() => 'AudioRecorderStopping';
}

/// State when pausing a recording
class AudioRecorderPausing extends AudioRecorderState {
  const AudioRecorderPausing();

  @override
  String toString() => 'AudioRecorderPausing';
}

/// State when resuming a recording
class AudioRecorderResuming extends AudioRecorderState {
  const AudioRecorderResuming();

  @override
  String toString() => 'AudioRecorderResuming';
}

/// State when cancelling a recording
class AudioRecorderCancelling extends AudioRecorderState {
  const AudioRecorderCancelling();

  @override
  String toString() => 'AudioRecorderCancelling';
}

// ==== ACTIVE RECORDING STATES ====

/// State when actively recording audio
class AudioRecorderRecording extends AudioRecorderState {
  final RecordingSession session;
  final Duration duration;
  final double amplitude;
  final Duration effectiveDuration;
  final Duration totalPausedDuration;
  final DateTime sessionStartTime;

  const AudioRecorderRecording({
    required this.session,
    required this.duration,
    required this.amplitude,
    required this.effectiveDuration,
    required this.totalPausedDuration,
    required this.sessionStartTime,
  });

  @override
  List<Object?> get props => [
    session,
    duration,
    amplitude,
    effectiveDuration,
    totalPausedDuration,
    sessionStartTime,
  ];

  /// Create copy with updated values
  AudioRecorderRecording copyWith({
    RecordingSession? session,
    Duration? duration,
    double? amplitude,
    Duration? effectiveDuration,
    Duration? totalPausedDuration,
    DateTime? sessionStartTime,
  }) {
    return AudioRecorderRecording(
      session: session ?? this.session,
      duration: duration ?? this.duration,
      amplitude: amplitude ?? this.amplitude,
      effectiveDuration: effectiveDuration ?? this.effectiveDuration,
      totalPausedDuration: totalPausedDuration ?? this.totalPausedDuration,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
    );
  }

  /// Get formatted duration string
  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted effective duration string
  String get effectiveDurationFormatted {
    final minutes = effectiveDuration.inMinutes;
    final seconds = effectiveDuration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get recording efficiency percentage
  double get recordingEfficiency {
    if (duration.inMilliseconds == 0) return 1.0;
    return effectiveDuration.inMilliseconds / duration.inMilliseconds;
  }

  /// Check if recording has been paused
  bool get hasPauses => totalPausedDuration.inSeconds > 0;

  @override
  String toString() => 'AudioRecorderRecording { duration: $durationFormatted, amplitude: ${amplitude.toStringAsFixed(2)} }';
}

/// State when recording is paused
class AudioRecorderPaused extends AudioRecorderState {
  final RecordingSession session;
  final PausedRecordingSession pausedSession;
  final Duration duration;
  final Duration effectiveDuration;
  final Duration totalPausedDuration;
  final DateTime pausedAt;
  final DateTime sessionStartTime;

  const AudioRecorderPaused({
    required this.session,
    required this.pausedSession,
    required this.duration,
    required this.effectiveDuration,
    required this.totalPausedDuration,
    required this.pausedAt,
    required this.sessionStartTime,
  });

  @override
  List<Object?> get props => [
    session,
    pausedSession,
    duration,
    effectiveDuration,
    totalPausedDuration,
    pausedAt,
    sessionStartTime,
  ];

  /// Get current pause duration
  Duration get currentPauseDuration => DateTime.now().difference(pausedAt);

  /// Get formatted pause duration
  String get pauseDurationFormatted {
    final duration = currentPauseDuration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted total duration
  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted effective duration
  String get effectiveDurationFormatted {
    final minutes = effectiveDuration.inMinutes;
    final seconds = effectiveDuration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if pause is getting too long
  bool get isPauseTooLong => currentPauseDuration.inMinutes > 30;

  @override
  String toString() => 'AudioRecorderPaused { duration: $durationFormatted, pausedFor: $pauseDurationFormatted }';
}

// ==== COMPLETION STATES ====

/// State when recording is completed successfully
class AudioRecorderCompleted extends AudioRecorderState {
  final RecordingEntity recording;
  final RecordingSession session;
  final Duration effectiveDuration;
  final Duration totalSessionDuration;
  final Duration totalPausedDuration;
  final dynamic statistics; // RecordingStatistics from stop_recording_usecase

  const AudioRecorderCompleted({
    required this.recording,
    required this.session,
    required this.effectiveDuration,
    required this.totalSessionDuration,
    required this.totalPausedDuration,
    required this.statistics,
  });

  @override
  List<Object?> get props => [
    recording,
    session,
    effectiveDuration,
    totalSessionDuration,
    totalPausedDuration,
    statistics,
  ];

  /// Get recording efficiency
  double get recordingEfficiency {
    if (totalSessionDuration.inMilliseconds == 0) return 1.0;
    return effectiveDuration.inMilliseconds / totalSessionDuration.inMilliseconds;
  }

  /// Get formatted effective duration
  String get effectiveDurationFormatted {
    final minutes = effectiveDuration.inMinutes;
    final seconds = effectiveDuration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted total session duration
  String get totalSessionDurationFormatted {
    final minutes = totalSessionDuration.inMinutes;
    final seconds = totalSessionDuration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if recording had significant pauses
  bool get hadSignificantPauses => totalPausedDuration.inSeconds > 10;

  /// Get completion summary
  String get summary {
    if (hadSignificantPauses) {
      return 'Recorded ${effectiveDurationFormatted} (${totalSessionDurationFormatted} total)';
    } else {
      return 'Recorded ${effectiveDurationFormatted}';
    }
  }

  @override
  String toString() => 'AudioRecorderCompleted { recording: ${recording.name}, duration: $effectiveDurationFormatted }';
}

/// State when recording is cancelled
class AudioRecorderCancelled extends AudioRecorderState {
  final RecordingSession session;
  final DateTime canceledAt;
  final Duration recordedDuration;
  final String reason;

  const AudioRecorderCancelled({
    required this.session,
    required this.canceledAt,
    required this.recordedDuration,
    required this.reason,
  });

  @override
  List<Object?> get props => [session, canceledAt, recordedDuration, reason];

  /// Get formatted recorded duration
  String get recordedDurationFormatted {
    final minutes = recordedDuration.inMinutes;
    final seconds = recordedDuration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if significant recording was lost
  bool get significantRecordingLost => recordedDuration.inSeconds > 30;

  /// Get cancellation summary
  String get summary => 'Cancelled after ${recordedDurationFormatted} - $reason';

  @override
  String toString() => 'AudioRecorderCancelled { duration: $recordedDurationFormatted, reason: $reason }';
}

/// State when a recording is deleted
class AudioRecorderDeleted extends AudioRecorderState {
  final RecordingEntity deletedRecording;
  final DateTime deletedAt;
  final bool wasBackedUp;
  final String? backupPath;

  const AudioRecorderDeleted({
    required this.deletedRecording,
    required this.deletedAt,
    required this.wasBackedUp,
    this.backupPath,
  });

  @override
  List<Object?> get props => [deletedRecording, deletedAt, wasBackedUp, backupPath];

  /// Check if backup was created successfully
  bool get hasBackup => wasBackedUp && backupPath != null;

  @override
  String toString() => 'AudioRecorderDeleted { recording: ${deletedRecording.name}, backed up: $wasBackedUp }';
}

// ==== ERROR STATES ====

/// State when an error occurs during recording operations
class AudioRecorderError extends AudioRecorderState {
  final String message;
  final AudioRecorderErrorType errorType;
  final String? errorCode;
  final dynamic error;

  const AudioRecorderError(
      this.message, {
        this.errorType = AudioRecorderErrorType.unexpected,
        this.errorCode,
        this.error,
      });

  @override
  List<Object?> get props => [message, errorType, errorCode, error];

  /// Whether this is a recoverable error
  bool get isRecoverable {
    switch (errorType) {
      case AudioRecorderErrorType.permission:
      case AudioRecorderErrorType.audioService:
      case AudioRecorderErrorType.validation:
        return true;
      case AudioRecorderErrorType.fileSystem:
      case AudioRecorderErrorType.invalidState:
      case AudioRecorderErrorType.unexpected:
        return false;
    }
  }

  /// Get user-friendly error message
  String get userFriendlyMessage {
    switch (errorType) {
      case AudioRecorderErrorType.permission:
        return 'Microphone permission is required to record audio';
      case AudioRecorderErrorType.audioService:
        return 'Audio recording service is not available';
      case AudioRecorderErrorType.fileSystem:
        return 'Unable to save recording file';
      case AudioRecorderErrorType.validation:
        return 'Invalid recording settings';
      case AudioRecorderErrorType.invalidState:
        return 'Invalid recording state';
      case AudioRecorderErrorType.unexpected:
        return 'An unexpected error occurred';
    }
  }

  /// Get suggested action for the error
  String get suggestedAction {
    switch (errorType) {
      case AudioRecorderErrorType.permission:
        return 'Please grant microphone permission in settings';
      case AudioRecorderErrorType.audioService:
        return 'Please restart the app and try again';
      case AudioRecorderErrorType.fileSystem:
        return 'Please check available storage space';
      case AudioRecorderErrorType.validation:
        return 'Please check recording settings';
      case AudioRecorderErrorType.invalidState:
        return 'Please stop current recording and try again';
      case AudioRecorderErrorType.unexpected:
        return 'Please try again or restart the app';
    }
  }

  @override
  String toString() => 'AudioRecorderError { message: $message, type: $errorType }';
}

// ==== ERROR TYPES ====

/// Types of errors that can occur in the audio recorder
enum AudioRecorderErrorType {
  permission,
  audioService,
  fileSystem,
  validation,
  invalidState,
  unexpected,
}

extension AudioRecorderErrorTypeExtension on AudioRecorderErrorType {
  /// Get display name for the error type
  String get displayName {
    switch (this) {
      case AudioRecorderErrorType.permission:
        return 'Permission Error';
      case AudioRecorderErrorType.audioService:
        return 'Audio Service Error';
      case AudioRecorderErrorType.fileSystem:
        return 'File System Error';
      case AudioRecorderErrorType.validation:
        return 'Validation Error';
      case AudioRecorderErrorType.invalidState:
        return 'Invalid State Error';
      case AudioRecorderErrorType.unexpected:
        return 'Unexpected Error';
    }
  }

  /// Get icon for the error type
  String get icon {
    switch (this) {
      case AudioRecorderErrorType.permission:
        return '🔒';
      case AudioRecorderErrorType.audioService:
        return '🎤';
      case AudioRecorderErrorType.fileSystem:
        return '💾';
      case AudioRecorderErrorType.validation:
        return '⚠️';
      case AudioRecorderErrorType.invalidState:
        return '❌';
      case AudioRecorderErrorType.unexpected:
        return '⁉️';
    }
  }
}

// ==== STATE HELPER EXTENSIONS ====

/// Extension to provide common state checking methods
extension AudioRecorderStateExtension on AudioRecorderState {
  /// Check if recorder is in an active recording state
  bool get isRecording => this is AudioRecorderRecording;

  /// Check if recorder is paused
  bool get isPaused => this is AudioRecorderPaused;

  /// Check if recorder has completed a recording
  bool get isCompleted => this is AudioRecorderCompleted;

  /// Check if recorder is in an error state
  bool get hasError => this is AudioRecorderError;

  /// Check if recorder is in a loading state
  bool get isLoading =>
      this is AudioRecorderStarting ||
          this is AudioRecorderStopping ||
          this is AudioRecorderPausing ||
          this is AudioRecorderResuming ||
          this is AudioRecorderCancelling;

  /// Check if recorder can start a new recording
  bool get canStartRecording =>
      this is AudioRecorderInitial ||
          this is AudioRecorderCompleted ||
          this is AudioRecorderCancelled ||
          this is AudioRecorderDeleted;

  /// Check if recorder can be paused
  bool get canPause => this is AudioRecorderRecording;

  /// Check if recorder can be resumed
  bool get canResume => this is AudioRecorderPaused;

  /// Check if recorder can be stopped
  bool get canStop => this is AudioRecorderRecording || this is AudioRecorderPaused;

  /// Check if recorder can be cancelled
  bool get canCancel => this is AudioRecorderRecording || this is AudioRecorderPaused;

  /// Get current session if available
  RecordingSession? get currentSession {
    if (this is AudioRecorderRecording) {
      return (this as AudioRecorderRecording).session;
    } else if (this is AudioRecorderPaused) {
      return (this as AudioRecorderPaused).session;
    }
    return null;
  }

  /// Get current duration if available
  Duration? get currentDuration {
    if (this is AudioRecorderRecording) {
      return (this as AudioRecorderRecording).duration;
    } else if (this is AudioRecorderPaused) {
      return (this as AudioRecorderPaused).duration;
    }
    return null;
  }

  /// Get current amplitude if available
  double? get currentAmplitude {
    if (this is AudioRecorderRecording) {
      return (this as AudioRecorderRecording).amplitude;
    }
    return null;
  }
}