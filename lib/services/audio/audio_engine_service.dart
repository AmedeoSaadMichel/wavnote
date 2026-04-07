// File: services/audio/audio_engine_service.dart
//
// Audio Engine Service - Service Layer
// =====================================
//
// Flutter wrapper for AVAudioEngine-based recording and playback.
// This service allows simultaneous recording and playback without
// the file locking issues found in AVAssetWriter.
//
// Key features:
// - Record audio to file while being able to play it back
// - Pause/resume recording
// - Playback with seek support
// - No file locking issues on iOS

import 'dart:async';
import 'package:flutter/services.dart';

class AudioEngineService {
  static const _channel = MethodChannel('com.wavnote/audio_engine');

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  bool _isPlaying = false;
  bool _isPlaybackPaused = false;

  String? _currentRecordingPath;
  String? _currentPlaybackPath;

  StreamController<double>? _amplitudeController;
  StreamController<Duration>? _positionController;
  Timer? _amplitudeTimer;
  Timer? _positionTimer;

  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  bool get isRecordingPaused => _isRecordingPaused;
  bool get isPlaying => _isPlaying;
  bool get isPlaybackPaused => _isPlaybackPaused;
  String? get currentRecordingPath => _currentRecordingPath;
  String? get currentPlaybackPath => _currentPlaybackPath;

  Stream<double> get amplitudeStream =>
      _amplitudeController?.stream ?? const Stream.empty();

  Stream<Duration> get positionStream =>
      _positionController?.stream ?? const Stream.empty();

  double _lastAmplitude = 0.0;

  double get lastAmplitude => _lastAmplitude;

  Future<double> getCurrentAmplitude() async {
    if (!_isRecording || _isRecordingPaused) return 0.0;
    try {
      final raw = await _channel.invokeMethod<double>('getAmplitude');
      _lastAmplitude = (raw ?? 0.0).clamp(0.0, 1.0);
      return _lastAmplitude;
    } catch (_) {
      return 0.0;
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _amplitudeController = StreamController<double>.broadcast();
      _positionController = StreamController<Duration>.broadcast();

      final result = await _channel.invokeMethod<bool>('initialize');
      _isInitialized = result ?? false;
      return _isInitialized;
    } catch (e) {
      print('AudioEngineService: Failed to initialize: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    await cancelRecording();
    await stopPlayback();

    _amplitudeTimer?.cancel();
    _positionTimer?.cancel();

    await _amplitudeController?.close();
    await _positionController?.close();

    _amplitudeController = null;
    _positionController = null;

    _isInitialized = false;
  }

  Future<bool> startRecording({
    required String path,
    int sampleRate = 44100,
    int bitRate = 128000,
    String format = 'm4a',
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    try {
      _currentRecordingPath = path;

      final result = await _channel.invokeMethod<bool>('startRecording', {
        'path': path,
        'sampleRate': sampleRate,
        'bitRate': bitRate,
        'format': format,
      });

      if (result == true) {
        _isRecording = true;
        _isRecordingPaused = false;
        _startAmplitudeUpdates();
      }

      return result ?? false;
    } catch (e) {
      print('AudioEngineService: Failed to start recording: $e');
      return false;
    }
  }

  Future<bool> pauseRecording() async {
    if (!_isRecording || _isRecordingPaused) return false;

    try {
      final result = await _channel.invokeMethod<bool>('pauseRecording');
      if (result == true) {
        _isRecordingPaused = true;
        _stopAmplitudeUpdates();
      }
      return result ?? false;
    } catch (e) {
      print('AudioEngineService: Failed to pause recording: $e');
      return false;
    }
  }

  Future<bool> resumeRecording() async {
    if (!_isRecording || !_isRecordingPaused) return false;

    try {
      final result = await _channel.invokeMethod<bool>('resumeRecording');
      if (result == true) {
        _isRecordingPaused = false;
        _startAmplitudeUpdates();
      }
      return result ?? false;
    } catch (e) {
      print('AudioEngineService: Failed to resume recording: $e');
      return false;
    }
  }

  /// Ferma la registrazione.
  /// Se [raw] è true, restituisce il WAV grezzo senza conversione al formato finale.
  /// Usato da seek-and-resume per mantenere tutto in WAV fino alla conversione finale.
  Future<Map<String, dynamic>?> stopRecording({bool raw = false}) async {
    if (!_isRecording) return null;

    try {
      _stopAmplitudeUpdates();

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'stopRecording',
        raw ? {'raw': true} : null,
      );
      _isRecording = false;
      _isRecordingPaused = false;

      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      print('AudioEngineService: Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Converte un file WAV al formato specificato (singola codifica).
  /// Usato dopo seek-and-resume per la conversione finale unica.
  Future<Map<String, dynamic>?> convertAudio({
    required String wavPath,
    required String outputPath,
    required String format,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'convertAudio',
        {
          'wavPath': wavPath,
          'outputPath': outputPath,
          'format': format,
        },
      );
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      print('AudioEngineService: Failed to convert audio: $e');
      return null;
    }
  }

  Future<bool> cancelRecording() async {
    if (!_isRecording && _currentRecordingPath == null) return true;

    try {
      _stopAmplitudeUpdates();

      await _channel.invokeMethod<bool>('cancelRecording');
      _isRecording = false;
      _isRecordingPaused = false;
      _currentRecordingPath = null;

      return true;
    } catch (e) {
      print('AudioEngineService: Failed to cancel recording: $e');
      return false;
    }
  }

  Future<bool> startPlayback(String path) async {
    if (_isPlaying) {
      await stopPlayback();
    }

    try {
      _currentPlaybackPath = path;

      final result = await _channel.invokeMethod<bool>('startPlayback', {
        'path': path,
      });

      if (result == true) {
        _isPlaying = true;
        _isPlaybackPaused = false;
        _startPositionUpdates();
      }

      return result ?? false;
    } catch (e) {
      print('AudioEngineService: Failed to start playback: $e');
      return false;
    }
  }

  Future<bool> stopPlayback() async {
    if (!_isPlaying) return true;

    try {
      _stopPositionUpdates();

      await _channel.invokeMethod<bool>('stopPlayback');
      _isPlaying = false;
      _isPlaybackPaused = false;
      _currentPlaybackPath = null;

      return true;
    } catch (e) {
      print('AudioEngineService: Failed to stop playback: $e');
      return false;
    }
  }

  Future<bool> pausePlayback() async {
    if (!_isPlaying || _isPlaybackPaused) return false;

    try {
      final result = await _channel.invokeMethod<bool>('pausePlayback');
      if (result == true) {
        _isPlaybackPaused = true;
        _stopPositionUpdates();
      }
      return result ?? false;
    } catch (e) {
      print('AudioEngineService: Failed to pause playback: $e');
      return false;
    }
  }

  Future<bool> resumePlayback() async {
    if (!_isPlaying || !_isPlaybackPaused) return false;

    try {
      final result = await _channel.invokeMethod<bool>('resumePlayback');
      if (result == true) {
        _isPlaybackPaused = false;
        _startPositionUpdates();
      }
      return result ?? false;
    } catch (e) {
      print('AudioEngineService: Failed to resume playback: $e');
      return false;
    }
  }

  Future<bool> seekTo(Duration position) async {
    if (!_isPlaying) return false;

    try {
      final result = await _channel.invokeMethod<bool>('seekTo', {
        'position': position.inMilliseconds,
      });
      return result ?? false;
    } catch (e) {
      print('AudioEngineService: Failed to seek: $e');
      return false;
    }
  }

  Future<Duration> getPlaybackPosition() async {
    if (!_isPlaying) return Duration.zero;

    try {
      final result = await _channel.invokeMethod<int>('getPlaybackPosition');
      return Duration(milliseconds: result ?? 0);
    } catch (e) {
      return Duration.zero;
    }
  }

  Future<Duration> getPlaybackDuration() async {
    if (!_isPlaying) return Duration.zero;

    try {
      final result = await _channel.invokeMethod<int>('getPlaybackDuration');
      return Duration(milliseconds: result ?? 0);
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Interroga il layer nativo per sapere se il player sta ancora ripproducendo.
  /// Usato per rilevare il completamento naturale del playback (Swift imposta
  /// isPlaying = false nel completion callback di scheduleFile).
  Future<bool> checkIsPlayingNative() async {
    try {
      return await _channel.invokeMethod<bool>('isPlaying') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Configura la categoria della sessione audio nativa.
  Future<bool> setAudioSessionCategory(String category, {List<String> options = const ['defaultToSpeaker', 'allowBluetooth']}) async {
    try {
      final result = await _channel.invokeMethod<bool>('setAudioSessionCategory', {
        'category': category,
        'options': options,
      });
      return result ?? false;
    } catch (e) {
      print('AudioEngineService: Failed to set audio session category: $e');
      return false;
    }
  }

  /// Abilita/disabilita voice processing (echo cancellation + noise suppression).
  Future<bool> setVoiceProcessing(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>('setVoiceProcessing', {
        'enabled': enabled,
      });
      return result ?? false;
    } catch (e) {
      print('AudioEngineService: Failed to set voice processing: $e');
      return false;
    }
  }

  void _startAmplitudeUpdates() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (
      _,
    ) async {
      if (_isRecording && !_isRecordingPaused) {
        try {
          final raw = await _channel.invokeMethod<double>('getAmplitude');
          _amplitudeController?.add((raw ?? 0.0).clamp(0.0, 1.0));
        } catch (_) {
          _amplitudeController?.add(0.0);
        }
      }
    });
  }

  void _stopAmplitudeUpdates() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _amplitudeController?.add(0.0);
  }

  void _startPositionUpdates() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      if (_isPlaying && !_isPlaybackPaused) {
        final position = await getPlaybackPosition();
        _positionController?.add(position);
      }
    });
  }

  void _stopPositionUpdates() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }
}
