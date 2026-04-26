// File: lib/services/audio/audio_playback_engine_impl.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_playback_state.dart';
import 'i_audio_playback_engine.dart';
import '../../core/errors/exceptions.dart'; // Importa le eccezioni tipizzate

class AudioPlaybackEngineImpl implements IAudioPlaybackEngine {
  AudioPlayer? _audioPlayer;
  bool _isServiceInitialized = false;
  String? _currentlyPlayingFile;

  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  double _playbackVolume = 1.0;

  final StreamController<Duration> _positionStreamController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationStreamController =
      StreamController<Duration?>.broadcast();
  final StreamController<void> _completionStreamController =
      StreamController<void>.broadcast();
  final StreamController<AudioPlaybackState> _playbackStateStreamController =
      StreamController<AudioPlaybackState>.broadcast();
  final StreamController<double> _amplitudeStreamController =
      StreamController<double>.broadcast();

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  Timer? _amplitudeSimulationTimer;

  @override
  Future<bool> initialize() async {
    try {
      if (kDebugMode) debugPrint('🔧 AUDIO_ENGINE: Initialize called');
      if (_isServiceInitialized) return true;

      // Pulisce eventuale istanza precedente in errore prima di ricrearla
      if (_audioPlayer != null) await _audioPlayer!.dispose();

      _audioPlayer = AudioPlayer();
      await _initializePlayerListeners();

      _isServiceInitialized = true;
      _playbackStateStreamController.add(AudioPlaybackState.idle);
      return true;
    } catch (e) {
      _isServiceInitialized = false;
      throw AudioPlaybackException(
        message: 'Failed to initialize audio engine',
        errorType: AudioPlaybackErrorType.playbackInitializationFailed,
        originalError: e,
      );
    }
  }

  Future<void> _initializePlayerListeners() async {
    if (_audioPlayer == null) return;

    try {
      _positionSubscription = _audioPlayer!.positionStream.listen((position) {
        _playbackPosition = position;
        _positionStreamController.add(position);
      });

      _durationSubscription = _audioPlayer!.durationStream.listen((duration) {
        if (duration != null && duration > Duration.zero) {
          _playbackDuration = duration;
        }
        _durationStreamController.add(duration);
      });

      _stateSubscription = _audioPlayer!.playerStateStream.listen((state) {
        final AudioPlaybackState newState = _mapPlayerState(state);
        _playbackStateStreamController.add(newState);

        if (state.processingState == ProcessingState.completed) {
          _completionStreamController.add(null);
          _playbackPosition = Duration.zero;
          _stopAmplitudeSimulation();
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error setting up player listeners: $e');
    }
  }

  AudioPlaybackState _mapPlayerState(PlayerState playerState) {
    if (playerState.processingState == ProcessingState.loading ||
        playerState.processingState == ProcessingState.buffering) {
      return AudioPlaybackState.buffering;
    } else if (playerState.processingState == ProcessingState.ready) {
      return playerState.playing
          ? AudioPlaybackState.playing
          : AudioPlaybackState.paused;
    } else if (playerState.processingState == ProcessingState.completed) {
      return AudioPlaybackState.completed;
    } else if (playerState.processingState == ProcessingState.idle) {
      return AudioPlaybackState.idle;
    }
    return AudioPlaybackState.error;
  }

  @override
  Future<void> load(String filePath, {Duration? initialPosition}) async {
    if (!_ensureInitialized()) {
      throw const AudioPlaybackException(
        message: 'Engine not initialized',
        errorType: AudioPlaybackErrorType.audioServiceUnavailable,
      );
    }

    try {
      if (filePath.isEmpty) {
        throw AudioPlaybackException(
          message: 'Invalid audio file path (empty)',
          errorType: AudioPlaybackErrorType.audioFileNotFound,
          context: {'filePath': filePath},
        );
      }

      await _audioPlayer!.setAudioSource(
        AudioSource.file(filePath),
        initialPosition: initialPosition,
      );
      await _audioPlayer!.setSpeed(_playbackSpeed);
      await _audioPlayer!.setVolume(_playbackVolume);
      _currentlyPlayingFile = filePath;
      _playbackPosition = initialPosition ?? Duration.zero;
      _playbackStateStreamController.add(AudioPlaybackState.loaded);
    } catch (e) {
      if (e is AudioPlaybackException) rethrow;
      throw AudioPlaybackException(
        message: 'Failed to load audio: ${e.toString()}',
        errorType: AudioPlaybackErrorType.playbackStartFailed,
        originalError: e,
      );
    }
  }

  @override
  Future<void> play() async {
    if (!_ensureInitialized()) {
      throw const AudioPlaybackException(
        message: 'Engine not initialized',
        errorType: AudioPlaybackErrorType.audioServiceUnavailable,
      );
    }
    try {
      await _audioPlayer!.play();
      _startAmplitudeSimulation();
    } catch (e) {
      throw AudioPlaybackException(
        message: 'Failed to play audio',
        errorType: AudioPlaybackErrorType.playbackStartFailed,
        originalError: e,
      );
    }
  }

  @override
  Future<void> pause() async {
    if (!_ensureInitialized()) {
      throw const AudioPlaybackException(
        message: 'Engine not initialized',
        errorType: AudioPlaybackErrorType.audioServiceUnavailable,
      );
    }
    await _audioPlayer!.pause();
    _stopAmplitudeSimulation();
  }

  @override
  Future<void> stop() async {
    if (!_ensureInitialized()) return;
    await _audioPlayer!.stop();
    await _audioPlayer!.seek(Duration.zero);
    _playbackPosition = Duration.zero;
    _currentlyPlayingFile = null;
    _stopAmplitudeSimulation();
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_ensureInitialized()) return;
    try {
      await _audioPlayer!.seek(position);
      _playbackPosition = position;
    } catch (e) {
      throw AudioPlaybackException(
        message: 'Failed to seek',
        errorType: AudioPlaybackErrorType.audioDeviceError,
        originalError: e,
      );
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (!_ensureInitialized()) return;
    try {
      final validSpeed = speed.clamp(0.5, 2.0);
      await _audioPlayer!.setSpeed(validSpeed);
      _playbackSpeed = validSpeed;
    } catch (e) {
      throw AudioPlaybackException(
        message: 'Failed to set speed',
        errorType: AudioPlaybackErrorType.audioDeviceError,
        originalError: e,
      );
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    if (!_ensureInitialized()) return;
    try {
      final validVolume = volume.clamp(0.0, 1.0);
      await _audioPlayer!.setVolume(validVolume);
      _playbackVolume = validVolume;
    } catch (e) {
      throw AudioPlaybackException(
        message: 'Failed to set volume',
        errorType: AudioPlaybackErrorType.audioDeviceError,
        originalError: e,
      );
    }
  }

  @override
  Stream<Duration> get positionStream => _positionStreamController.stream;
  @override
  Stream<Duration?> get durationStream => _durationStreamController.stream;
  @override
  Stream<AudioPlaybackState> get playbackStateStream =>
      _playbackStateStreamController.stream;
  @override
  Stream<void> get completionStream => _completionStreamController.stream;
  @override
  Stream<double> get amplitudeStream => _amplitudeStreamController.stream;

  @override
  Duration get currentPosition => _playbackPosition;
  @override
  Duration get currentDuration => _playbackDuration;
  @override
  String? get currentFilePath => _currentlyPlayingFile;
  @override
  bool get isLoaded =>
      _currentlyPlayingFile != null &&
      (_audioPlayer?.playerState.processingState == ProcessingState.ready ||
          _audioPlayer?.playerState.processingState ==
              ProcessingState.buffering ||
          _audioPlayer?.playerState.processingState == ProcessingState.loading);
  @override
  bool get isPlaying => _audioPlayer?.playing ?? false;
  @override
  bool get isPlaybackPaused =>
      _audioPlayer?.playerState.playing == false &&
      _audioPlayer?.playerState.processingState != ProcessingState.completed &&
      _audioPlayer?.playerState.processingState != ProcessingState.idle;

  bool _ensureInitialized() => _isServiceInitialized && _audioPlayer != null;

  void _startAmplitudeSimulation() {
    _amplitudeSimulationTimer?.cancel();
    _amplitudeSimulationTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) {
        if (!isPlaying || isPlaybackPaused) {
          _amplitudeStreamController.add(0.0);
          return;
        }
        final random = math.Random();
        final amplitude =
            (0.2 +
                    (random.nextDouble() * 0.6) +
                    ((random.nextDouble() - 0.5) * 0.2))
                .clamp(0.0, 1.0);
        _amplitudeStreamController.add(amplitude);
      },
    );
  }

  void _stopAmplitudeSimulation() {
    _amplitudeSimulationTimer?.cancel();
    _amplitudeSimulationTimer = null;
    _amplitudeStreamController.add(0.0);
  }

  @override
  Future<void> dispose() async {
    await stop();
    _stopAmplitudeSimulation();
    await _positionSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _positionStreamController.close();
    await _durationStreamController.close();
    await _completionStreamController.close();
    await _playbackStateStreamController.close();
    await _amplitudeStreamController.close();
    await _audioPlayer?.dispose();
    _isServiceInitialized = false;
  }
}
