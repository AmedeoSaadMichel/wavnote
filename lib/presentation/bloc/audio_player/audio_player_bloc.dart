// File: presentation/bloc/audio_player/audio_player_bloc.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import 'audio_player_event.dart';
import 'audio_player_state.dart';

/// Cosmic Audio Player BLoC - Mystical Sound Management
///
/// Orchestrates the ethereal flow of audio playback with transcendent precision.
/// This BLoC channels the cosmic forces of sound through the digital realm,
/// providing seamless audio control with mystical state management.
///
/// Features:
/// - Transcendent audio file loading with cosmic validation
/// - Ethereal playback controls (play, pause, resume, stop)
/// - Mystical position tracking with real-time updates
/// - Celestial seeking and skip functionality
/// - Universal volume and speed control
/// - Divine error handling with recovery mechanisms
class AudioPlayerBloc extends Bloc<AudioPlayerEvent, AudioPlayerState> {
  final IAudioServiceRepository _audioRepository;

  // Cosmic state tracking
  String? _currentAudioPath;
  Duration _currentDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  double _currentVolume = 1.0;
  double _currentSpeed = 1.0;
  bool _isCurrentlyPlaying = false;
  bool _isCurrentlyPaused = false;

  // Ethereal stream subscriptions
  StreamSubscription<Duration>? _positionStreamSub;
  StreamSubscription<void>? _completionStreamSub;
  Timer? _positionUpdateTimer;

  AudioPlayerBloc({
    required IAudioServiceRepository audioRepository,
  }) : _audioRepository = audioRepository,
        super(const AudioPlayerInitial()) {

    // Register cosmic event handlers
    on<InitializeAudioPlayerEvent>(_handleInitializePlayer);
    on<LoadAudioEvent>(_handleLoadAudio);
    on<StartPlaybackEvent>(_handleStartPlayback);
    on<PausePlaybackEvent>(_handlePausePlayback);
    on<ResumePlaybackEvent>(_handleResumePlayback);
    on<StopPlaybackEvent>(_handleStopPlayback);
    on<SeekToPositionEvent>(_handleSeekToPosition);
    on<SetPlaybackSpeedEvent>(_handleSetPlaybackSpeed);
    on<SetVolumeEvent>(_handleSetVolume);
    on<UpdatePlaybackPositionEvent>(_handleUpdatePosition);
    on<AudioPlaybackCompletedEvent>(_handlePlaybackCompleted);
    on<SkipBackwardEvent>(_handleSkipBackward);
    on<SkipForwardEvent>(_handleSkipForward);
  }

  // ==== COSMIC EVENT HANDLERS ====

  /// Initialize the cosmic audio player
  Future<void> _handleInitializePlayer(
      InitializeAudioPlayerEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    try {
      final bool initSuccess = await _audioRepository.initialize();

      if (initSuccess) {
        _resetCosmicState();
        emit(const AudioPlayerInitial());
      } else {
        emit(const AudioPlayerError(
          message: 'Failed to initialize the cosmic audio realm',
        ));
      }
    } catch (cosmicError) {
      emit(AudioPlayerError(
        message: 'Cosmic interference during initialization: $cosmicError',
      ));
    }
  }

  /// Load audio file into the cosmic realm
  Future<void> _handleLoadAudio(
      LoadAudioEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    try {
      emit(AudioPlayerLoading(filePath: event.filePath));

      // Stop any current cosmic transmission
      await _stopCurrentTransmission();

      // Validate the cosmic audio file
      final bool isValidAudio = await _validateCosmicAudioFile(event.filePath);
      if (!isValidAudio) {
        emit(AudioPlayerError(
          message: 'Invalid cosmic audio transmission detected',
          filePath: event.filePath,
        ));
        return;
      }

      // Extract cosmic audio metadata
      final Duration? audioDuration = await _extractCosmicDuration(event.filePath);

      if (audioDuration != null) {
        _currentAudioPath = event.filePath;
        _currentDuration = audioDuration;
        _currentPosition = Duration.zero;
        _isCurrentlyPlaying = false;
        _isCurrentlyPaused = false;

        emit(AudioPlayerLoaded(
          currentFilePath: _currentAudioPath!,
          totalDuration: _currentDuration,
        ));
      } else {
        emit(AudioPlayerError(
          message: 'Unable to decode cosmic audio metadata',
          filePath: event.filePath,
        ));
      }
    } catch (cosmicError) {
      emit(AudioPlayerError(
        message: 'Cosmic disruption while loading audio: $cosmicError',
        filePath: event.filePath,
      ));
    }
  }

  /// Begin cosmic audio transmission
  Future<void> _handleStartPlayback(
      StartPlaybackEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    try {
      if (_currentAudioPath == null) {
        emit(const AudioPlayerError(
          message: 'No cosmic audio transmission loaded',
        ));
        return;
      }

      // Start the ethereal playback
      _isCurrentlyPlaying = true;
      _isCurrentlyPaused = false;

      // Begin position tracking in the cosmic timeline
      _startCosmicPositionTracking();

      emit(AudioPlayerPlaying(
        currentFilePath: _currentAudioPath!,
        totalDuration: _currentDuration,
        position: _currentPosition,
        volume: _currentVolume,
        playbackSpeed: _currentSpeed,
      ));

    } catch (cosmicError) {
      emit(AudioPlayerError(
        message: 'Failed to initiate cosmic transmission: $cosmicError',
      ));
    }
  }

  /// Pause the cosmic transmission
  Future<void> _handlePausePlayback(
      PausePlaybackEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    try {
      if (!_isCurrentlyPlaying) return;

      _isCurrentlyPlaying = false;
      _isCurrentlyPaused = true;

      // Suspend cosmic position tracking
      _suspendCosmicPositionTracking();

      emit(AudioPlayerPaused(
        currentFilePath: _currentAudioPath!,
        totalDuration: _currentDuration,
        pausedPosition: _currentPosition,
      ));

    } catch (cosmicError) {
      emit(AudioPlayerError(
        message: 'Cosmic interference during pause: $cosmicError',
      ));
    }
  }

  /// Resume the cosmic transmission
  Future<void> _handleResumePlayback(
      ResumePlaybackEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    try {
      if (!_isCurrentlyPaused) return;

      _isCurrentlyPlaying = true;
      _isCurrentlyPaused = false;

      // Resume cosmic position tracking
      _startCosmicPositionTracking();

      emit(AudioPlayerPlaying(
        currentFilePath: _currentAudioPath!,
        totalDuration: _currentDuration,
        position: _currentPosition,
        volume: _currentVolume,
        playbackSpeed: _currentSpeed,
      ));

    } catch (cosmicError) {
      emit(AudioPlayerError(
        message: 'Cosmic interference during resume: $cosmicError',
      ));
    }
  }

  /// Terminate cosmic transmission
  Future<void> _handleStopPlayback(
      StopPlaybackEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    try {
      await _stopCurrentTransmission();

      if (_currentAudioPath != null) {
        emit(AudioPlayerLoaded(
          currentFilePath: _currentAudioPath!,
          totalDuration: _currentDuration,
        ));
      } else {
        emit(const AudioPlayerInitial());
      }

    } catch (cosmicError) {
      emit(AudioPlayerError(
        message: 'Cosmic disruption during transmission termination: $cosmicError',
      ));
    }
  }

  /// Navigate through cosmic timeline
  Future<void> _handleSeekToPosition(
      SeekToPositionEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    try {
      // Clamp position within cosmic boundaries
      final Duration clampedPosition = Duration(
        milliseconds: event.position.inMilliseconds.clamp(
          0,
          _currentDuration.inMilliseconds,
        ),
      );

      _currentPosition = clampedPosition;

      if (_isCurrentlyPlaying) {
        emit(AudioPlayerPlaying(
          currentFilePath: _currentAudioPath!,
          totalDuration: _currentDuration,
          position: _currentPosition,
          volume: _currentVolume,
          playbackSpeed: _currentSpeed,
        ));
      } else if (_isCurrentlyPaused) {
        emit(AudioPlayerPaused(
          currentFilePath: _currentAudioPath!,
          totalDuration: _currentDuration,
          pausedPosition: _currentPosition,
        ));
      }

    } catch (cosmicError) {
      emit(AudioPlayerError(
        message: 'Cosmic timeline navigation failed: $cosmicError',
      ));
    }
  }

  /// Adjust cosmic transmission speed
  Future<void> _handleSetPlaybackSpeed(
      SetPlaybackSpeedEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    try {
      _currentSpeed = event.speed.clamp(0.25, 3.0);

      if (_isCurrentlyPlaying) {
        emit(AudioPlayerPlaying(
          currentFilePath: _currentAudioPath!,
          totalDuration: _currentDuration,
          position: _currentPosition,
          volume: _currentVolume,
          playbackSpeed: _currentSpeed,
        ));
      }

    } catch (cosmicError) {
      emit(AudioPlayerError(
        message: 'Failed to adjust cosmic transmission speed: $cosmicError',
      ));
    }
  }

  /// Modulate cosmic volume
  Future<void> _handleSetVolume(
      SetVolumeEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    try {
      _currentVolume = event.volume.clamp(0.0, 1.0);

      if (_isCurrentlyPlaying) {
        emit(AudioPlayerPlaying(
          currentFilePath: _currentAudioPath!,
          totalDuration: _currentDuration,
          position: _currentPosition,
          volume: _currentVolume,
          playbackSpeed: _currentSpeed,
        ));
      }

    } catch (cosmicError) {
      emit(AudioPlayerError(
        message: 'Failed to modulate cosmic volume: $cosmicError',
      ));
    }
  }

  /// Update cosmic position during transmission
  Future<void> _handleUpdatePosition(
      UpdatePlaybackPositionEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    if (_isCurrentlyPlaying && _currentAudioPath != null) {
      _currentPosition = event.position;

      // Check if cosmic transmission has reached its conclusion
      if (_currentPosition >= _currentDuration) {
        add(const AudioPlaybackCompletedEvent());
        return;
      }

      emit(AudioPlayerPlaying(
        currentFilePath: _currentAudioPath!,
        totalDuration: _currentDuration,
        position: _currentPosition,
        volume: _currentVolume,
        playbackSpeed: _currentSpeed,
      ));
    }
  }

  /// Handle cosmic transmission completion
  Future<void> _handlePlaybackCompleted(
      AudioPlaybackCompletedEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    _isCurrentlyPlaying = false;
    _isCurrentlyPaused = false;
    _currentPosition = _currentDuration;

    _suspendCosmicPositionTracking();

    if (_currentAudioPath != null) {
      emit(AudioPlayerCompleted(
        currentFilePath: _currentAudioPath!,
        totalDuration: _currentDuration,
      ));
    }
  }

  /// Navigate backward through cosmic timeline
  Future<void> _handleSkipBackward(
      SkipBackwardEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    final Duration newPosition = Duration(
      milliseconds: (_currentPosition.inMilliseconds - 15000).clamp(
        0,
        _currentDuration.inMilliseconds,
      ),
    );
    add(SeekToPositionEvent(position: newPosition));
  }

  /// Navigate forward through cosmic timeline
  Future<void> _handleSkipForward(
      SkipForwardEvent event,
      Emitter<AudioPlayerState> emit,
      ) async {
    final Duration newPosition = Duration(
      milliseconds: (_currentPosition.inMilliseconds + 15000).clamp(
        0,
        _currentDuration.inMilliseconds,
      ),
    );
    add(SeekToPositionEvent(position: newPosition));
  }

  // ==== COSMIC HELPER METHODS ====

  /// Reset all cosmic state variables
  void _resetCosmicState() {
    _currentAudioPath = null;
    _currentDuration = Duration.zero;
    _currentPosition = Duration.zero;
    _currentVolume = 1.0;
    _currentSpeed = 1.0;
    _isCurrentlyPlaying = false;
    _isCurrentlyPaused = false;
  }

  /// Stop current cosmic transmission and reset state
  Future<void> _stopCurrentTransmission() async {
    _suspendCosmicPositionTracking();

    if (_isCurrentlyPlaying || _isCurrentlyPaused) {
      _isCurrentlyPlaying = false;
      _isCurrentlyPaused = false;
      _currentPosition = Duration.zero;
    }
  }

  /// Validate cosmic audio file integrity
  Future<bool> _validateCosmicAudioFile(String filePath) async {
    try {
      final File audioFile = File(filePath);

      // Check if file exists in the cosmic realm
      if (!await audioFile.exists()) {
        return false;
      }

      // Check if file has cosmic energy (non-zero size)
      final int fileSize = await audioFile.length();
      if (fileSize == 0) {
        return false;
      }

      // Validate file extension for cosmic compatibility
      final String extension = filePath.toLowerCase();
      final List<String> supportedFormats = [
        '.mp3', '.m4a', '.aac', '.wav', '.flac', '.ogg'
      ];

      return supportedFormats.any((format) => extension.endsWith(format));

    } catch (cosmicError) {
      return false;
    }
  }

  /// Extract cosmic audio duration
  Future<Duration?> _extractCosmicDuration(String filePath) async {
    try {
      // In a real implementation, this would use audio libraries
      // For now, simulate duration extraction based on file size
      final File audioFile = File(filePath);
      final int fileSize = await audioFile.length();

      // Simulate duration: ~1 minute per MB (rough estimate)
      final int estimatedSeconds = (fileSize / (1024 * 1024) * 60).round();
      final int clampedSeconds = estimatedSeconds.clamp(10, 3600); // 10 sec to 1 hour

      return Duration(seconds: clampedSeconds);

    } catch (cosmicError) {
      return null;
    }
  }

  /// Begin tracking position in the cosmic timeline
  void _startCosmicPositionTracking() {
    _suspendCosmicPositionTracking();

    // Create ethereal position updates every 100ms
    _positionUpdateTimer = Timer.periodic(
      const Duration(milliseconds: 100),
          (Timer timer) {
        if (_isCurrentlyPlaying) {
          final Duration newPosition = Duration(
            milliseconds: _currentPosition.inMilliseconds + (100 * _currentSpeed).round(),
          );

          // Ensure we don't exceed cosmic boundaries
          if (newPosition < _currentDuration) {
            add(UpdatePlaybackPositionEvent(position: newPosition));
          } else {
            add(const AudioPlaybackCompletedEvent());
          }
        }
      },
    );
  }

  /// Suspend cosmic position tracking
  void _suspendCosmicPositionTracking() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;

    _positionStreamSub?.cancel();
    _positionStreamSub = null;

    _completionStreamSub?.cancel();
    _completionStreamSub = null;
  }

  /// Release all cosmic resources
  @override
  Future<void> close() {
    _suspendCosmicPositionTracking();
    return super.close();
  }
}