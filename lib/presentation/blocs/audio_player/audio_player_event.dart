// File: presentation/blocs/audio_player/audio_player_event.dart
part of 'audio_player_bloc.dart';

/// Base class for all audio player events
abstract class AudioPlayerEvent extends Equatable {
  const AudioPlayerEvent();

  @override
  List<Object?> get props => [];
}

/// Event to start playing a recording
class PlayRecording extends AudioPlayerEvent {
  final RecordingEntity recording;

  const PlayRecording(this.recording);

  @override
  List<Object> get props => [recording];

  @override
  String toString() => 'PlayRecording { recording: ${recording.name} }';
}

/// Event to pause current playback
class PausePlayback extends AudioPlayerEvent {
  const PausePlayback();

  @override
  String toString() => 'PausePlayback';
}

/// Event to resume paused playback
class ResumePlayback extends AudioPlayerEvent {
  const ResumePlayback();

  @override
  String toString() => 'ResumePlayback';
}

/// Event to stop current playback
class StopPlayback extends AudioPlayerEvent {
  const StopPlayback();

  @override
  String toString() => 'StopPlayback';
}

/// Event to seek to specific position
class SeekTo extends AudioPlayerEvent {
  final Duration position;

  const SeekTo(this.position);

  @override
  List<Object> get props => [position];

  @override
  String toString() => 'SeekTo { position: ${position.inSeconds}s }';
}

/// Event to set playback speed
class SetPlaybackSpeed extends AudioPlayerEvent {
  final double speed;

  const SetPlaybackSpeed(this.speed);

  @override
  List<Object> get props => [speed];

  @override
  String toString() => 'SetPlaybackSpeed { speed: ${speed}x }';
}

/// Event to set volume
class SetVolume extends AudioPlayerEvent {
  final double volume;

  const SetVolume(this.volume);

  @override
  List<Object> get props => [volume];

  @override
  String toString() => 'SetVolume { volume: $volume }';
}

/// Internal event to update playback position
class UpdatePlaybackPosition extends AudioPlayerEvent {
  final Duration position;

  const UpdatePlaybackPosition(this.position);

  @override
  List<Object> get props => [position];

  @override
  String toString() => 'UpdatePlaybackPosition { position: ${position.inSeconds}s }';
}

/// Internal event when playback completes
class PlaybackCompleted extends AudioPlayerEvent {
  const PlaybackCompleted();

  @override
  String toString() => 'PlaybackCompleted';
}