// File: presentation/bloc/audio_player/audio_player_event.dart
import 'package:equatable/equatable.dart';

/// Base class for all audio player events
abstract class AudioPlayerEvent extends Equatable {
  const AudioPlayerEvent();
}

/// Initialize audio player
class InitializeAudioPlayerEvent extends AudioPlayerEvent {
  const InitializeAudioPlayerEvent();

  @override
  List<Object?> get props => [];
}

/// Load audio file for playback
class LoadAudioEvent extends AudioPlayerEvent {
  final String filePath;

  const LoadAudioEvent({required this.filePath});

  @override
  List<Object?> get props => [filePath];
}

/// Start playback
class StartPlaybackEvent extends AudioPlayerEvent {
  const StartPlaybackEvent();

  @override
  List<Object?> get props => [];
}

/// Pause playback
class PausePlaybackEvent extends AudioPlayerEvent {
  const PausePlaybackEvent();

  @override
  List<Object?> get props => [];
}

/// Resume playback
class ResumePlaybackEvent extends AudioPlayerEvent {
  const ResumePlaybackEvent();

  @override
  List<Object?> get props => [];
}

/// Stop playback
class StopPlaybackEvent extends AudioPlayerEvent {
  const StopPlaybackEvent();

  @override
  List<Object?> get props => [];
}

/// Seek to specific position
class SeekToPositionEvent extends AudioPlayerEvent {
  final Duration position;

  const SeekToPositionEvent({required this.position});

  @override
  List<Object?> get props => [position];
}

/// Set playback speed
class SetPlaybackSpeedEvent extends AudioPlayerEvent {
  final double speed;

  const SetPlaybackSpeedEvent({required this.speed});

  @override
  List<Object?> get props => [speed];
}

/// Set volume
class SetVolumeEvent extends AudioPlayerEvent {
  final double volume;

  const SetVolumeEvent({required this.volume});

  @override
  List<Object?> get props => [volume];
}

/// Update playback position (internal event)
class UpdatePlaybackPositionEvent extends AudioPlayerEvent {
  final Duration position;

  const UpdatePlaybackPositionEvent({required this.position});

  @override
  List<Object?> get props => [position];
}

/// Playback completed
class AudioPlaybackCompletedEvent extends AudioPlayerEvent {
  const AudioPlaybackCompletedEvent();

  @override
  List<Object?> get props => [];
}

/// Skip backward 15 seconds
class SkipBackwardEvent extends AudioPlayerEvent {
  const SkipBackwardEvent();

  @override
  List<Object?> get props => [];
}

/// Skip forward 15 seconds
class SkipForwardEvent extends AudioPlayerEvent {
  const SkipForwardEvent();

  @override
  List<Object?> get props => [];
}