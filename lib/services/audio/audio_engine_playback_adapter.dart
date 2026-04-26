// File: lib/services/audio/audio_engine_playback_adapter.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_engine_service.dart';
import 'audio_playback_state.dart';
import 'i_audio_playback_engine.dart';

/// Implementazione di IAudioPlaybackEngine per iOS/macOS.
/// Wrappa AudioEngineService (AVAudioEngine nativo) invece di just_audio,
/// eliminando il conflitto AVAudioSession con il plugin di registrazione.
class AudioEnginePlaybackAdapter implements IAudioPlaybackEngine {
  final AudioEngineService _engineService;

  String? _loadedFilePath;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  Duration _cachedSeekPosition = Duration.zero;
  AudioPlaybackState _status = AudioPlaybackState.idle;
  bool _isInitialized = false;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<AudioPlaybackState> _stateController =
      StreamController<AudioPlaybackState>.broadcast();
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  StreamSubscription<PlaybackTick>? _tickSub;
  StreamSubscription<void>? _completionSub;

  AudioEnginePlaybackAdapter({required AudioEngineService engineService})
      : _engineService = engineService;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    final ok = await _engineService.initialize();
    if (!ok) return false;

    _tickSub = _engineService.playbackTickStream.listen((tick) {
      _currentPosition = tick.position;
      _currentDuration = tick.totalDuration;
      _positionController.add(tick.position);
      _durationController.add(tick.totalDuration);
    });

    _completionSub = _engineService.completionStream.listen((_) {
      _currentPosition = Duration.zero;
      _status = AudioPlaybackState.loaded;
      _stateController.add(AudioPlaybackState.completed);
    });

    _isInitialized = true;
    return true;
  }

  @override
  Future<void> load(String filePath, {Duration? initialPosition}) async {
    _loadedFilePath = filePath;
    _cachedSeekPosition = initialPosition ?? Duration.zero;
    _currentPosition = initialPosition ?? Duration.zero;

    // Lettura durata da metadati file (fast — nessun buffering audio)
    _currentDuration = await _engineService.getAudioDuration(filePath);
    _durationController.add(_currentDuration);

    _status = AudioPlaybackState.loaded;
    _stateController.add(AudioPlaybackState.loaded);
  }

  @override
  Future<void> play() async {
    if (_loadedFilePath == null) return;

    if (_status == AudioPlaybackState.paused) {
      final shouldRestartFromSeek = _cachedSeekPosition != _currentPosition;
      if (shouldRestartFromSeek) {
        await _engineService.startPlayback(
          _loadedFilePath!,
          position: _cachedSeekPosition,
        );
        _currentPosition = _cachedSeekPosition;
        _cachedSeekPosition = Duration.zero;
      } else {
        await _engineService.resumePlayback();
      }
    } else {
      final pos = _cachedSeekPosition == Duration.zero
          ? null
          : _cachedSeekPosition;
      await _engineService.startPlayback(_loadedFilePath!, position: pos);
      _cachedSeekPosition = Duration.zero;
    }

    _status = AudioPlaybackState.playing;
    _stateController.add(AudioPlaybackState.playing);
  }

  @override
  Future<void> pause() async {
    await _engineService.pausePlayback();
    _status = AudioPlaybackState.paused;
    _stateController.add(AudioPlaybackState.paused);
  }

  @override
  Future<void> stop() async {
    await _engineService.stopPlayback();
    _loadedFilePath = null;
    _currentPosition = Duration.zero;
    _cachedSeekPosition = Duration.zero;
    _status = AudioPlaybackState.idle;
    _stateController.add(AudioPlaybackState.idle);
  }

  @override
  Future<void> seek(Duration position) async {
    _cachedSeekPosition = position;
    if (_status == AudioPlaybackState.playing) {
      await _engineService.seekTo(position);
    }
  }

  /// no-op: AVAudioEngine nativo non espone setSpeed tramite MethodChannel.
  @override
  Future<void> setSpeed(double speed) async {
    if (kDebugMode) {
      debugPrint('AudioEnginePlaybackAdapter: setSpeed no-op su iOS/macOS');
    }
  }

  /// no-op: AVAudioEngine nativo non espone setVolume tramite MethodChannel.
  @override
  Future<void> setVolume(double volume) async {}

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<AudioPlaybackState> get playbackStateStream =>
      _stateController.stream;

  @override
  Stream<void> get completionStream => _engineService.completionStream;

  @override
  // iOS usa waveform pre-calcolata dal DB — nessuna ampiezza real-time necessaria.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  Duration get currentDuration => _currentDuration;

  @override
  String? get currentFilePath => _loadedFilePath;

  @override
  bool get isLoaded =>
      _loadedFilePath != null && _status != AudioPlaybackState.idle;

  @override
  bool get isPlaying => _status == AudioPlaybackState.playing;

  @override
  bool get isPlaybackPaused => _status == AudioPlaybackState.paused;

  @override
  Future<void> dispose() async {
    await _engineService.stopPlayback();
    await _tickSub?.cancel();
    await _completionSub?.cancel();
    await _positionController.close();
    await _durationController.close();
    await _stateController.close();
    await _amplitudeController.close();
    _isInitialized = false;
  }
}
