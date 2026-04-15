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
  final String? originalFilePathForOverwrite;
  final Duration? overwriteStartTime;
  final String?
  seekBasePath; // path del file base tagliato se è avvenuto un seek-trim
  /// Dati waveform troncati dopo un seek-and-resume; null per registrazioni normali.
  final List<double>? truncatedWaveData;

  /// Dati waveform completi per il player, non vengono mai troncati.
  final List<double>? waveformDataForPlayer;

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
    this.originalFilePathForOverwrite,
    this.overwriteStartTime,
    this.seekBasePath,
    this.truncatedWaveData,
    this.waveformDataForPlayer,
  });

  @override
  List<Object?> get props => [
    filePath,
    folderId,
    folderName,
    format,
    sampleRate,
    bitRate,
    duration,
    amplitude,
    startTime,
    title,
    originalFilePathForOverwrite,
    overwriteStartTime,
    seekBasePath,
    truncatedWaveData,
    waveformDataForPlayer,
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
    String? originalFilePathForOverwrite,
    Duration? overwriteStartTime,
    String? seekBasePath,
    List<double>? truncatedWaveData,
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
      originalFilePathForOverwrite:
          originalFilePathForOverwrite ?? this.originalFilePathForOverwrite,
      overwriteStartTime: overwriteStartTime ?? this.overwriteStartTime,
      seekBasePath: seekBasePath ?? this.seekBasePath,
      truncatedWaveData: truncatedWaveData ?? this.truncatedWaveData,
    );
  }
}

/// State when recording is paused
class RecordingPaused extends RecordingState {
  final String filePath;
  final String? folderId;
  final String? folderName;
  final String? title;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final Duration duration;
  final DateTime startTime;

  /// true mentre il playback di anteprima è attivo (ascolto del registrato).
  final bool isPlayingPreview;

  /// Indice della barra di seek nella waveform (single source of truth).
  final int seekBarIndex;

  final String? seekBasePath;
  final String? originalFilePathForOverwrite;
  final Duration? overwriteStartTime;
  final List<double>? truncatedWaveData;

  /// File path del preview assemblato, riutilizzato per playback multipli.
  final String? previewFilePath;

  const RecordingPaused({
    required this.filePath,
    this.folderId,
    this.folderName,
    this.title,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    required this.duration,
    required this.startTime,
    this.isPlayingPreview = false,
    this.seekBarIndex = 0,
    this.seekBasePath,
    this.originalFilePathForOverwrite,
    this.overwriteStartTime,
    this.truncatedWaveData,
    this.previewFilePath,
  });

  @override
  List<Object?> get props => [
    filePath,
    folderId,
    folderName,
    title,
    format,
    sampleRate,
    bitRate,
    duration,
    startTime,
    isPlayingPreview,
    seekBarIndex,
    seekBasePath,
    originalFilePathForOverwrite,
    overwriteStartTime,
    truncatedWaveData,
    previewFilePath,
  ];

  RecordingPaused copyWith({
    String? filePath,
    String? folderId,
    String? folderName,
    String? title,
    AudioFormat? format,
    int? sampleRate,
    int? bitRate,
    Duration? duration,
    DateTime? startTime,
    bool? isPlayingPreview,
    int? seekBarIndex,
    String? seekBasePath,
    String? originalFilePathForOverwrite,
    Duration? overwriteStartTime,
    List<double>? truncatedWaveData,
    String? previewFilePath,
  }) {
    return RecordingPaused(
      filePath: filePath ?? this.filePath,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      title: title ?? this.title,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      bitRate: bitRate ?? this.bitRate,
      duration: duration ?? this.duration,
      startTime: startTime ?? this.startTime,
      isPlayingPreview: isPlayingPreview ?? this.isPlayingPreview,
      seekBarIndex: seekBarIndex ?? this.seekBarIndex,
      seekBasePath: seekBasePath ?? this.seekBasePath,
      originalFilePathForOverwrite:
          originalFilePathForOverwrite ?? this.originalFilePathForOverwrite,
      overwriteStartTime: overwriteStartTime ?? this.overwriteStartTime,
      truncatedWaveData: truncatedWaveData ?? this.truncatedWaveData,
      previewFilePath: previewFilePath ?? this.previewFilePath,
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
  final DateTime timestamp; // Force state differentiation

  RecordingLoaded(
    this.recordings, {
    this.isEditMode = false,
    this.selectedRecordings = const <String>{},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [
    recordings,
    isEditMode,
    selectedRecordings,
    timestamp,
  ];

  RecordingLoaded copyWith({
    List<RecordingEntity>? recordings,
    bool? isEditMode,
    Set<String>? selectedRecordings,
    bool? forceUpdate,
  }) {
    return RecordingLoaded(
      recordings ?? this.recordings,
      isEditMode: isEditMode ?? this.isEditMode,
      selectedRecordings: selectedRecordings ?? this.selectedRecordings,
      timestamp: (forceUpdate == true) ? DateTime.now() : timestamp,
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
enum RecordingErrorType { permission, recording, state, unknown }
