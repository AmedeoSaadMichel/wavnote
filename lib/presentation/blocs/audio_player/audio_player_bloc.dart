// File: presentation/blocs/audio_player/audio_player_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';

part 'audio_player_event.dart';
part 'audio_player_state.dart';

/// BLoC responsible for managing audio playback state and operations
///
/// Handles play/pause/stop/seek operations for recorded audio files.
/// Provides real-time playback position updates and completion events.
class AudioPlayerBloc extends Bloc<AudioPlayerEvent, AudioPlayerState> {
  final IAudioServiceRepository _audioService;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completionSubscription;
  Timer? _positionTimer;

  AudioPlayerBloc({
    required IAudioServiceRepository audioService,
  }) : _audioService = audioService,
        super(const AudioPlayerInitial()) {

    on<PlayRecording>(_onPlayRecording);
    on<PausePlayback>(_onPausePlayback);
    on<ResumePlayback>(_onResumePlayback);
    on<StopPlayback>(_onStopPlayback);
    on<SeekTo>(_onSeekTo);
    on<SetPlaybackSpeed>(_onSetPlaybackSpeed);
    on<SetVolume>(_onSetVolume);
    on<UpdatePlaybackPosition>(_onUpdatePlaybackPosition);
    on<PlaybackCompleted>(_onPlaybackCompleted);
  }

  /// Start playing a recording
  Future<void> _onPlayRecording(
      PlayRecording event,
      Emitter<AudioPlayerState> emit,
      ) async {
    try {
      emit(AudioPlayerLoading(currentRecording: event.recording));

      // Get audio file info
      final audioInfo = await _audioService.getAudioFileInfo(event.recording.filePath);
      if (audioInfo == null) {
        emit(AudioPlayerError(
          'Unable to load audio file: ${event.recording.name}',
          currentRecording: event.recording,
        ));
        return;
      }

      // Start playback
      final success = await _audioService.startPlaying(event.recording.filePath);
      if (!success) {
        emit(AudioPlayerError(
          'Failed to start playback: ${event.recording.name}',
          currentRecording: event.recording,
        ));
        return;
      }

      // Start position updates
      _startPositionUpdates();
      _startCompletionListener();

      emit(AudioPlayerPlaying(
        currentRecording: event.recording,
        position: Duration.zero,
        duration: audioInfo.duration,
        speed: 1.0,
        volume: 1.0,
      ));

      print('▶️ Started playing: ${event.recording.name}');

    } catch (e, stackTrace) {
      print('❌ Error playing recording: $e');
      print('Stack trace: $stackTrace');
      emit(AudioPlayerError(
        'Failed to play recording: ${e.toString()}',
        currentRecording: event.recording,
      ));
    }
  }

  /// Pause current playback
  Future<void> _onPausePlayback(
      PausePlayback event,
      Emitter<AudioPlayerState> emit,
      ) async {
    if (state is! AudioPlayerPlaying) {
      emit(const AudioPlayerError('No active playback to pause'));
      return;
    }

    final currentState = state as AudioPlayerPlaying;

    try {
      final success = await _audioService.pausePlaying();
      if (!success) {
        emit(AudioPlayerError(
          'Failed to pause playback',
          currentRecording: currentState.currentRecording,
        ));
        return;
      }

      _stopPositionUpdates();

      emit(AudioPlayerPaused(
        currentRecording: currentState.currentRecording,
        position: currentState.position,
        duration: currentState.duration,
        speed: currentState.speed,
        volume: currentState.volume,
      ));

      print('⏸️ Playback paused');

    } catch (e) {
      print('❌ Error pausing playback: $e');
      emit(AudioPlayerError(
        'Failed to pause playback: ${e.toString()}',
        currentRecording: currentState.currentRecording,
      ));
    }
  }

  /// Resume paused playback
  Future<void> _onResumePlayback(
      ResumePlayback event,
      Emitter<AudioPlayerState> emit,
      ) async {
    if (state is! AudioPlayerPaused) {
      emit(const AudioPlayerError('No paused playback to resume'));
      return;
    }

    final currentState = state as AudioPlayerPaused;

    try {
      final success = await _audioService.resumePlaying();
      if (!success) {
        emit(AudioPlayerError(
          'Failed to resume playback',
          currentRecording: currentState.currentRecording,
        ));
        return;
      }

      _startPositionUpdates();

      emit(AudioPlayerPlaying(
        currentRecording: currentState.currentRecording,
        position: currentState.position,
        duration: currentState.duration,
        speed: currentState.speed,
        volume: currentState.volume,
      ));

      print('▶️ Playback resumed');

    } catch (e) {
      print('❌ Error resuming playback: $e');
      emit(AudioPlayerError(
        'Failed to resume playback: ${e.toString()}',
        currentRecording: currentState.currentRecording,
      ));
    }
  }

  /// Stop current playback
  Future<void> _onStopPlayback(
      StopPlayback event,
      Emitter<AudioPlayerState> emit,
      ) async {
    if (state is! AudioPlayerPlaying && state is! AudioPlayerPaused) {
      emit(const AudioPlayerError('No active playback to stop'));
      return;
    }

    try {
      _stopPositionUpdates();
      _stopCompletionListener();

      final success = await _audioService.stopPlaying();
      if (!success) {
        emit(const AudioPlayerError('Failed to stop playback'));
        return;
      }

      emit(const AudioPlayerStopped());

      print('⏹️ Playback stopped');

    } catch (e) {
      print('❌ Error stopping playback: $e');
      _stopPositionUpdates();
      _stopCompletionListener();
      emit(AudioPlayerError('Failed to stop playback: ${e.toString()}'));
    }
  }

  /// Seek to specific position
  Future<void> _onSeekTo(
      SeekTo event,
      Emitter<AudioPlayerState> emit,
      ) async {
    if (state is! AudioPlayerPlaying && state is! AudioPlayerPaused) {
      emit(const AudioPlayerError('No active playback to seek'));
      return;
    }

    final currentState = state as AudioPlayerWithRecording;

    try {
      final success = await _audioService.seekTo(event.position);
      if (!success) {
        emit(AudioPlayerError(
          'Failed to seek to position',
          currentRecording: currentState.currentRecording,
        ));
        return;
      }

      if (state is AudioPlayerPlaying) {
        emit((state as AudioPlayerPlaying).copyWith(position: event.position));
      } else if (state is AudioPlayerPaused) {
        emit((state as AudioPlayerPaused).copyWith(position: event.position));
      }

      print('⏭️ Seeked to: ${event.position.inSeconds}s');

    } catch (e) {
      print('❌ Error seeking: $e');
      emit(AudioPlayerError(
        'Failed to seek: ${e.toString()}',
        currentRecording: currentState.currentRecording,
      ));
    }
  }

  /// Set playback speed
  Future<void> _onSetPlaybackSpeed(
      SetPlaybackSpeed event,
      Emitter<AudioPlayerState> emit,
      ) async {
    if (state is! AudioPlayerPlaying && state is! AudioPlayerPaused) {
      emit(const AudioPlayerError('No active playback to adjust speed'));
      return;
    }

    final currentState = state as AudioPlayerWithRecording;

    try {
      final success = await _audioService.setPlaybackSpeed(event.speed);
      if (!success) {
        emit(AudioPlayerError(
          'Failed to set playback speed',
          currentRecording: currentState.currentRecording,
        ));
        return;
      }

      if (state is AudioPlayerPlaying) {
        emit((state as AudioPlayerPlaying).copyWith(speed: event.speed));
      } else if (state is AudioPlayerPaused) {
        emit((state as AudioPlayerPaused).copyWith(speed: event.speed));
      }

      print('🔄 Playback speed set to: ${event.speed}x');

    } catch (e) {
      print('❌ Error setting playback speed: $e');
      emit(AudioPlayerError(
        'Failed to set speed: ${e.toString()}',
        currentRecording: currentState.currentRecording,
      ));
    }
  }

  /// Set volume
  Future<void> _onSetVolume(
      SetVolume event,
      Emitter<AudioPlayerState> emit,
      ) async {
    if (state is! AudioPlayerPlaying && state is! AudioPlayerPaused) {
      emit(const AudioPlayerError('No active playback to adjust volume'));
      return;
    }

    final currentState = state as AudioPlayerWithRecording;

    try {
      final success = await _audioService.setVolume(event.volume);
      if (!success) {
        emit(AudioPlayerError(
          'Failed to set volume',
          currentRecording: currentState.currentRecording,
        ));
        return;
      }

      if (state is AudioPlayerPlaying) {
        emit((state as AudioPlayerPlaying).copyWith(volume: event.volume));
      } else if (state is AudioPlayerPaused) {
        emit((state as AudioPlayerPaused).copyWith(volume: event.volume));
      }

      print('🔊 Volume set to: ${(event.volume * 100).round()}%');

    } catch (e) {
      print('❌ Error setting volume: $e');
      emit(AudioPlayerError(
        'Failed to set volume: ${e.toString()}',
        currentRecording: currentState.currentRecording,
      ));
    }
  }

  /// Update playback position (internal event)
  Future<void> _onUpdatePlaybackPosition(
      UpdatePlaybackPosition event,
      Emitter<AudioPlayerState> emit,
      ) async {
    if (state is AudioPlayerPlaying) {
      final currentState = state as AudioPlayerPlaying;
      emit(currentState.copyWith(position: event.position));
    }
  }

  /// Handle playback completion
  Future<void> _onPlaybackCompleted(
      PlaybackCompleted event,
      Emitter<AudioPlayerState> emit,
      ) async {
    _stopPositionUpdates();
    _stopCompletionListener();

    emit(const AudioPlayerCompleted());

    print('✅ Playback completed');
  }

  // ==== PRIVATE HELPER METHODS ====

  /// Start position updates for progress tracking
  void _startPositionUpdates() {
    _stopPositionUpdates();

    _positionSubscription = _audioService.getPlaybackPositionStream().listen(
          (position) {
        add(UpdatePlaybackPosition(position));
      },
      onError: (error) {
        print('❌ Position stream error: $error');
      },
    );

    // Fallback timer-based position updates
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      try {
        final position = await _audioService.getCurrentPlaybackPosition();
        add(UpdatePlaybackPosition(position));
      } catch (e) {
        print('❌ Position update error: $e');
      }
    });
  }

  /// Stop position updates
  void _stopPositionUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  /// Start listening for playback completion
  void _startCompletionListener() {
    _stopCompletionListener();

    _completionSubscription = _audioService.getPlaybackCompletionStream().listen(
          (_) {
        add(const PlaybackCompleted());
      },
      onError: (error) {
        print('❌ Completion stream error: $error');
      },
    );
  }

  /// Stop completion listener
  void _stopCompletionListener() {
    _completionSubscription?.cancel();
    _completionSubscription = null;
  }

  @override
  Future<void> close() {
    _stopPositionUpdates();
    _stopCompletionListener();
    return super.close();
  }
}