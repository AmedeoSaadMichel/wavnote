// File: presentation/bloc/audio_player/audio_player_state.dart
import 'package:equatable/equatable.dart';

/// Base class for all audio player states
abstract class AudioPlayerState extends Equatable {
  const AudioPlayerState();

  /// Whether audio is currently playing
  bool get isPlaying => this is AudioPlayerPlaying;

  /// Whether audio is paused
  bool get isPaused => this is AudioPlayerPaused;

  /// Whether audio is loaded and ready
  bool get isLoaded => this is AudioPlayerLoaded || this is AudioPlayerPlaying || this is AudioPlayerPaused;

  /// Get current position
  Duration get currentPosition {
    if (this is AudioPlayerPlaying) {
      return (this as AudioPlayerPlaying).position;
    }
    if (this is AudioPlayerPaused) {
      return (this as AudioPlayerPaused).pausedPosition;
    }
    return Duration.zero;
  }

  /// Get total duration
  Duration get totalDuration {
    if (this is AudioPlayerPlaying) {
      return (this as AudioPlayerPlaying).totalDuration;
    }
    if (this is AudioPlayerPaused) {
      return (this as AudioPlayerPaused).totalDuration;
    }
    if (this is AudioPlayerLoaded) {
      return (this as AudioPlayerLoaded).totalDuration;
    }
    if (this is AudioPlayerCompleted) {
      return (this as AudioPlayerCompleted).totalDuration;
    }
    return Duration.zero;
  }
}

/// Initial state
class AudioPlayerInitial extends AudioPlayerState {
  const AudioPlayerInitial();

  @override
  List<Object?> get props => [];
}

/// Loading audio file
class AudioPlayerLoading extends AudioPlayerState {
  final String filePath;

  const AudioPlayerLoading({required this.filePath});

  @override
  List<Object?> get props => [filePath];
}

/// Audio loaded and ready for playback
class AudioPlayerLoaded extends AudioPlayerState {
  final String currentFilePath;
  final Duration totalDuration;
  final Duration duration; // Alias for totalDuration

  const AudioPlayerLoaded({
    required this.currentFilePath,
    required this.totalDuration,
  }) : duration = totalDuration;

  @override
  List<Object?> get props => [currentFilePath, totalDuration];
}

/// Audio currently playing
class AudioPlayerPlaying extends AudioPlayerState {
  final String currentFilePath;
  final Duration totalDuration;
  final Duration duration; // Alias for totalDuration
  final Duration position;
  final double volume;
  final double playbackSpeed;

  const AudioPlayerPlaying({
    required this.currentFilePath,
    required this.totalDuration,
    required this.position,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
  }) : duration = totalDuration;

  @override
  List<Object?> get props => [
    currentFilePath,
    totalDuration,
    position,
    volume,
    playbackSpeed,
  ];

  /// Create copy with updated values
  AudioPlayerPlaying copyWith({
    String? currentFilePath,
    Duration? totalDuration,
    Duration? position,
    double? volume,
    double? playbackSpeed,
  }) {
    return AudioPlayerPlaying(
      currentFilePath: currentFilePath ?? this.currentFilePath,
      totalDuration: totalDuration ?? this.totalDuration,
      position: position ?? this.position,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  /// Get formatted position string
  String get formattedPosition {
    final minutes = position.inMinutes;
    final seconds = position.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted remaining time
  String get formattedRemaining {
    final remaining = totalDuration - position;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return '-${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get playback progress (0.0 to 1.0)
  double get progress {
    if (totalDuration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
  }
}

/// Audio paused
class AudioPlayerPaused extends AudioPlayerState {
  final String currentFilePath;
  final Duration totalDuration;
  final Duration duration; // Alias for totalDuration
  final Duration pausedPosition;
  final Duration position; // Alias for pausedPosition

  const AudioPlayerPaused({
    required this.currentFilePath,
    required this.totalDuration,
    required this.pausedPosition,
  }) : duration = totalDuration, position = pausedPosition;

  @override
  List<Object?> get props => [currentFilePath, totalDuration, pausedPosition];
}

/// Audio playback completed
class AudioPlayerCompleted extends AudioPlayerState {
  final String currentFilePath;
  final Duration totalDuration;

  const AudioPlayerCompleted({
    required this.currentFilePath,
    required this.totalDuration,
  });

  @override
  List<Object?> get props => [currentFilePath, totalDuration];
}

/// Audio player error
class AudioPlayerError extends AudioPlayerState {
  final String message;
  final String? filePath;

  const AudioPlayerError({
    required this.message,
    this.filePath,
  });

  @override
  List<Object?> get props => [message, filePath];
}