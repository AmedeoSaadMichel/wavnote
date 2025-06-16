// File: presentation/blocs/audio_player/audio_player_state.dart
part of 'audio_player_bloc.dart';

/// Base class for all audio player states
abstract class AudioPlayerState extends Equatable {
  const AudioPlayerState();

  @override
  List<Object?> get props => [];

  /// Whether audio is currently playing
  bool get isPlaying => this is AudioPlayerPlaying;

  /// Whether audio is currently paused
  bool get isPaused => this is AudioPlayerPaused;

  /// Whether audio is stopped
  bool get isStopped => this is AudioPlayerStopped || this is AudioPlayerInitial;

  /// Whether audio is loading
  bool get isLoading => this is AudioPlayerLoading;

  /// Whether there's an error
  bool get hasError => this is AudioPlayerError;

  /// Whether playback can be started
  bool get canPlay => this is AudioPlayerInitial || this is AudioPlayerStopped || this is AudioPlayerCompleted;

  /// Whether playback can be paused
  bool get canPause => this is AudioPlayerPlaying;

  /// Whether playback can be resumed
  bool get canResume => this is AudioPlayerPaused;

  /// Whether playback can be stopped
  bool get canStop => this is AudioPlayerPlaying || this is AudioPlayerPaused;

  /// Whether seeking is allowed
  bool get canSeek => this is AudioPlayerPlaying || this is AudioPlayerPaused;
}

/// Initial state when no audio is loaded
class AudioPlayerInitial extends AudioPlayerState {
  const AudioPlayerInitial();

  @override
  String toString() => 'AudioPlayerInitial';
}

/// State when audio is being loaded
class AudioPlayerLoading extends AudioPlayerState {
  final RecordingEntity? currentRecording;

  const AudioPlayerLoading({this.currentRecording});

  @override
  List<Object?> get props => [currentRecording];

  @override
  String toString() => 'AudioPlayerLoading { recording: ${currentRecording?.name} }';
}

/// Base class for states with an active recording
abstract class AudioPlayerWithRecording extends AudioPlayerState {
  final RecordingEntity currentRecording;
  final Duration position;
  final Duration duration;
  final double speed;
  final double volume;

  const AudioPlayerWithRecording({
    required this.currentRecording,
    required this.position,
    required this.duration,
    required this.speed,
    required this.volume,
  });

  @override
  List<Object> get props => [currentRecording, position, duration, speed, volume];

  /// Progress as percentage (0.0 - 1.0)
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Remaining time
  Duration get remainingTime => duration - position;

  /// Position formatted as string
  String get positionFormatted {
    final minutes = position.inMinutes;
    final seconds = position.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Duration formatted as string
  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Speed as formatted string
  String get speedFormatted => '${speed}x';

  /// Volume as percentage
  int get volumePercentage => (volume * 100).round();
}

/// State when audio is playing
class AudioPlayerPlaying extends AudioPlayerWithRecording {
  const AudioPlayerPlaying({
    required super.currentRecording,
    required super.position,
    required super.duration,
    required super.speed,
    required super.volume,
  });

  /// Create copy with updated values
  AudioPlayerPlaying copyWith({
    RecordingEntity? currentRecording,
    Duration? position,
    Duration? duration,
    double? speed,
    double? volume,
  }) {
    return AudioPlayerPlaying(
      currentRecording: currentRecording ?? this.currentRecording,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
    );
  }

  @override
  String toString() => 'AudioPlayerPlaying { recording: ${currentRecording.name}, position: $positionFormatted, speed: ${speed}x }';
}

/// State when audio is paused
class AudioPlayerPaused extends AudioPlayerWithRecording {
  const AudioPlayerPaused({
    required super.currentRecording,
    required super.position,
    required super.duration,
    required super.speed,
    required super.volume,
  });

  /// Create copy with updated values
  AudioPlayerPaused copyWith({
    RecordingEntity? currentRecording,
    Duration? position,
    Duration? duration,
    double? speed,
    double? volume,
  }) {
    return AudioPlayerPaused(
      currentRecording: currentRecording ?? this.currentRecording,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
    );
  }

  @override
  String toString() => 'AudioPlayerPaused { recording: ${currentRecording.name}, position: $positionFormatted }';
}

/// State when audio is stopped
class AudioPlayerStopped extends AudioPlayerState {
  const AudioPlayerStopped();

  @override
  String toString() => 'AudioPlayerStopped';
}

/// State when audio playback completes
class AudioPlayerCompleted extends AudioPlayerState {
  const AudioPlayerCompleted();

  @override
  String toString() => 'AudioPlayerCompleted';
}

/// State when an error occurs
class AudioPlayerError extends AudioPlayerState {
  final String message;
  final RecordingEntity? currentRecording;
  final String? errorCode;
  final dynamic error;

  const AudioPlayerError(
      this.message, {
        this.currentRecording,
        this.errorCode,
        this.error,
      });

  @override
  List<Object?> get props => [message, currentRecording, errorCode, error];

  @override
  String toString() => 'AudioPlayerError { message: $message, recording: ${currentRecording?.name} }';
}