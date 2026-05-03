// File: lib/services/audio/audio_engine_service.dart
//
// Audio Engine Service - Service Layer
// =====================================
//
// Flutter wrapper for AVAudioEngine-based recording and playback.
//
// Clock architecture (ADR-001):
// - Recording ticks: pushed by native installTap → clock_events EventChannel
//   (ogni ~100ms, throttled; contiene positionMs + amplitude sample-accurate)
// - Playback ticks: pushed by native DispatchSourceTimer (100ms) → clock_events EventChannel
//   (contiene positionMs + durationMs basati su lastRenderTime)
// - Zero timer Dart in questo file.

import 'dart:async';
import 'package:flutter/services.dart';

import '../../domain/entities/recording_external_control_action.dart';
import '../../domain/entities/recording_waveform_bucket_batch.dart';

// Record types per i tick del clock
typedef RecordingTick = ({Duration position, double amplitude});
typedef PlaybackTick = ({Duration position, Duration totalDuration});

class AudioEngineRecordingStatus {
  const AudioEngineRecordingStatus({
    required this.isRecording,
    required this.isPaused,
    required this.path,
    required this.duration,
    required this.amplitude,
  });

  const AudioEngineRecordingStatus.idle()
    : isRecording = false,
      isPaused = false,
      path = null,
      duration = Duration.zero,
      amplitude = 0.0;

  factory AudioEngineRecordingStatus.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const AudioEngineRecordingStatus.idle();
    return AudioEngineRecordingStatus(
      isRecording: map['isRecording'] as bool? ?? false,
      isPaused: map['isPaused'] as bool? ?? false,
      path: map['path'] as String?,
      duration: Duration(
        milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0,
      ),
      amplitude: ((map['amplitude'] as num?)?.toDouble() ?? 0.0)
          .clamp(0.0, 1.0)
          .toDouble(),
    );
  }

  final bool isRecording;
  final bool isPaused;
  final String? path;
  final Duration duration;
  final double amplitude;
}

class AudioEngineService {
  static const _channel = MethodChannel('com.wavnote/audio_engine');
  static const _playbackEventChannel = EventChannel(
    'com.wavnote/audio_engine/playback_events',
  );
  static const _clockEventChannel = EventChannel(
    'com.wavnote/audio_engine/clock_events',
  );

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  bool _isPlaying = false;
  bool _isPlaybackPaused = false;

  String? _currentRecordingPath;
  String? _currentPlaybackPath;

  // Completion stream (playback_events EventChannel — già push-based)
  StreamController<void>? _completionController;
  StreamSubscription<dynamic>? _playbackEventSubscription;

  // Clock streams (clock_events EventChannel — ADR-001)
  StreamController<RecordingTick>? _recordingTickController;
  StreamController<RecordingWaveformBucketBatch>? _waveformBucketController;
  StreamController<PlaybackTick>? _playbackTickController;
  StreamController<RecordingExternalControlEvent>? _externalControlController;
  StreamSubscription<dynamic>? _clockEventSubscription;

  double _lastAmplitude = 0.0;

  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  bool get isRecordingPaused => _isRecordingPaused;
  bool get isPlaying => _isPlaying;
  bool get isPlaybackPaused => _isPlaybackPaused;
  String? get currentRecordingPath => _currentRecordingPath;
  String? get currentPlaybackPath => _currentPlaybackPath;
  double get lastAmplitude => _lastAmplitude;

  // Recording tick stream: position (sample-accurate) + amplitude
  Stream<RecordingTick> get recordingTickStream =>
      _recordingTickController?.stream ?? const Stream.empty();

  Stream<RecordingWaveformBucketBatch> get waveformBucketStream =>
      _waveformBucketController?.stream ?? const Stream.empty();

  // Playback tick stream: position + totalDuration (da lastRenderTime nativo)
  Stream<PlaybackTick> get playbackTickStream =>
      _playbackTickController?.stream ?? const Stream.empty();

  Stream<RecordingExternalControlEvent> get externalControlStream =>
      _externalControlController?.stream ?? const Stream.empty();

  // Derived streams — mantenuti per compatibilità con AudioServiceCoordinator
  // (verranno sostituiti in Step 3 con activeClockStream)
  Stream<double> get amplitudeStream =>
      _recordingTickController?.stream.map((t) {
        _lastAmplitude = t.amplitude;
        return t.amplitude;
      }) ??
      const Stream.empty();

  Stream<Duration> get positionStream =>
      _playbackTickController?.stream.map((t) => t.position) ??
      const Stream.empty();

  Stream<void> get completionStream =>
      _completionController?.stream ?? const Stream.empty();

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

  Future<AudioEngineRecordingStatus> getRecordingStatus() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getRecordingStatus',
      );
      final status = AudioEngineRecordingStatus.fromMap(raw);
      _isRecording = status.isRecording;
      _isRecordingPaused = status.isPaused;
      _currentRecordingPath = status.path ?? _currentRecordingPath;
      _lastAmplitude = status.amplitude;
      return status;
    } catch (_) {
      return const AudioEngineRecordingStatus.idle();
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _completionController = StreamController<void>.broadcast();
      _recordingTickController = StreamController<RecordingTick>.broadcast();
      _waveformBucketController =
          StreamController<RecordingWaveformBucketBatch>.broadcast();
      _playbackTickController = StreamController<PlaybackTick>.broadcast();
      _externalControlController =
          StreamController<RecordingExternalControlEvent>.broadcast();

      // Completion events (già presenti, invariati)
      _playbackEventSubscription = _playbackEventChannel
          .receiveBroadcastStream()
          .listen((event) {
            if (event is Map && event['event'] == 'playbackCompleted') {
              _completionController?.add(null);
            }
          });

      // Clock events (ADR-001) — recording e playback tick push-based
      _clockEventSubscription = _clockEventChannel
          .receiveBroadcastStream()
          .listen((event) {
            if (event is! Map) return;
            final type = event['type'] as String?;
            switch (type) {
              case 'recordingTick':
                final posMs = (event['positionMs'] as num?)?.toInt() ?? 0;
                final amp = ((event['amplitude'] as num?)?.toDouble() ?? 0.0)
                    .clamp(0.0, 1.0);
                _lastAmplitude = amp;
                _recordingTickController?.add((
                  position: Duration(milliseconds: posMs),
                  amplitude: amp,
                ));
              case 'waveformBuckets':
                final samples =
                    (event['samples'] as List?)
                        ?.whereType<num>()
                        .map((v) => v.toDouble().clamp(0.0, 1.0).toDouble())
                        .toList() ??
                    const <double>[];
                if (samples.isNotEmpty) {
                  _waveformBucketController?.add(
                    RecordingWaveformBucketBatch(
                      startIndex: (event['startIndex'] as num?)?.toInt() ?? 0,
                      samples: samples,
                      totalCount: (event['totalCount'] as num?)?.toInt() ?? 0,
                    ),
                  );
                }
              case 'playbackTick':
                final posMs = (event['positionMs'] as num?)?.toInt() ?? 0;
                final durMs = (event['durationMs'] as num?)?.toInt() ?? 0;
                _playbackTickController?.add((
                  position: Duration(milliseconds: posMs),
                  totalDuration: Duration(milliseconds: durMs),
                ));
              case 'liveActivityControl':
                final action = RecordingExternalControlAction.fromNative(
                  event['action'] as String?,
                );
                if (action != null) {
                  _externalControlController?.add(
                    RecordingExternalControlEvent.requested(action),
                  );
                }
              case 'liveActivityControlCompleted':
                final controlEvent = _parseLiveActivityControlCompleted(event);
                if (controlEvent != null) {
                  _externalControlController?.add(controlEvent);
                  ackLiveActivityControlCompleted(controlEvent.action);
                }
            }
          });

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

    _playbackEventSubscription?.cancel();
    _clockEventSubscription?.cancel();

    await _completionController?.close();
    await _recordingTickController?.close();
    await _waveformBucketController?.close();
    await _playbackTickController?.close();
    await _externalControlController?.close();

    _completionController = null;
    _recordingTickController = null;
    _waveformBucketController = null;
    _playbackTickController = null;
    _externalControlController = null;
    _playbackEventSubscription = null;
    _clockEventSubscription = null;

    _isInitialized = false;
  }

  Future<bool> startRecording({
    required String path,
    int sampleRate = 44100,
    int bitRate = 128000,
    String format = 'm4a',
    Duration initialElapsedOffset = Duration.zero,
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
        'initialElapsedMs': initialElapsedOffset.inMilliseconds,
      });

      if (result == true) {
        _isRecording = true;
        _isRecordingPaused = false;
        _currentRecordingPath = path;
        // Nessun timer Dart — i tick arrivano via clock_events EventChannel
      }

      return result ?? false;
    } catch (e) {
      print('AudioEngineService: Failed to start recording: $e');
      return false;
    }
  }

  RecordingExternalControlEvent? syncRecordingStatusFromNative(
    AudioEngineRecordingStatus status,
  ) {
    final wasPaused = _isRecordingPaused;

    _isRecording = status.isRecording;
    _isRecordingPaused = status.isRecording && status.isPaused;
    if (!status.isRecording) {
      _currentRecordingPath = null;
    } else if (status.path != null) {
      _currentRecordingPath = status.path;
    }

    if (!status.isRecording || wasPaused == _isRecordingPaused) {
      return null;
    }

    return RecordingExternalControlEvent.completed(
      action: _isRecordingPaused
          ? RecordingExternalControlAction.pause
          : RecordingExternalControlAction.resume,
      success: true,
      duration: status.duration,
    );
  }

  void emitExternalControlEvent(RecordingExternalControlEvent event) {
    _externalControlController?.add(event);
  }

  Future<RecordingExternalControlEvent?>
  getPendingLiveActivityControlCompleted() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getPendingLiveActivityControlCompleted',
      );
      if (raw == null) return null;
      return _parseLiveActivityControlCompleted(raw);
    } catch (_) {
      return null;
    }
  }

  RecordingExternalControlEvent? _parseLiveActivityControlCompleted(
    Map<dynamic, dynamic> event,
  ) {
    final action = RecordingExternalControlAction.fromNative(
      event['action'] as String?,
    );
    if (action == null) return null;

    final durationMs = (event['durationMs'] as num?)?.toInt();
    final path = event['path'] as String?;
    final success = event['success'] == true;
    _syncRecordingFlagsFromExternalControl(action: action, success: success);
    return RecordingExternalControlEvent.completed(
      action: action,
      success: success,
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
      path: path,
    );
  }

  void ackLiveActivityControlCompleted(RecordingExternalControlAction action) {
    unawaited(
      _channel.invokeMethod<void>('ackLiveActivityControlCompleted', {
        'action': action.name,
      }),
    );
  }

  void _syncRecordingFlagsFromExternalControl({
    required RecordingExternalControlAction action,
    required bool success,
  }) {
    if (!success) return;
    switch (action) {
      case RecordingExternalControlAction.pause:
        _isRecording = true;
        _isRecordingPaused = true;
      case RecordingExternalControlAction.resume:
        _isRecording = true;
        _isRecordingPaused = false;
      case RecordingExternalControlAction.stop:
        _isRecording = false;
        _isRecordingPaused = false;
        _currentRecordingPath = null;
      case RecordingExternalControlAction.cancel:
        _isRecording = false;
        _isRecordingPaused = false;
        _currentRecordingPath = null;
    }
  }

  Future<bool> pauseRecording() async {
    if (!_isRecording || _isRecordingPaused) return false;

    try {
      final result = await _channel.invokeMethod<bool>('pauseRecording');
      if (result == true) {
        _isRecordingPaused = true;
        // Nessun timer da fermare — il nativo smette di emettere recording tick
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
        // Nessun timer da riavviare — il nativo riprende a emettere recording tick
      }
      return result ?? false;
    } catch (e) {
      print('AudioEngineService: Failed to resume recording: $e');
      return false;
    }
  }

  /// Ferma la registrazione.
  /// Se [raw] è true, restituisce il WAV grezzo senza conversione al formato finale.
  Future<Map<String, dynamic>?> stopRecording({bool raw = false}) async {
    if (!_isRecording) return null;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'stopRecording',
        raw ? {'raw': true} : null,
      );
      _isRecording = false;
      _isRecordingPaused = false;
      _currentRecordingPath = null;

      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      print('AudioEngineService: Failed to stop recording: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      return null;
    }
  }

  /// Converte un file WAV al formato specificato (singola codifica).
  Future<Map<String, dynamic>?> convertAudio({
    required String wavPath,
    required String outputPath,
    required String format,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'convertAudio',
        {'wavPath': wavPath, 'outputPath': outputPath, 'format': format},
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

  Future<bool> startPlayback(String path, {Duration? position}) async {
    if (_isPlaying) {
      await stopPlayback();
    }

    try {
      _currentPlaybackPath = path;

      final args = <String, dynamic>{'path': path};
      if (position != null) {
        args['position'] = position.inMilliseconds;
      }

      final result = await _channel.invokeMethod<bool>('startPlayback', args);

      if (result == true) {
        _isPlaying = true;
        _isPlaybackPaused = false;
        // Nessun timer Dart — i tick arrivano via clock_events EventChannel
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
      // Nessun timer Dart da fermare — il nativo ferma il DispatchSourceTimer
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

  Future<Duration> getAudioDuration(String filePath) async {
    try {
      final result = await _channel.invokeMethod<int>('getAudioDuration', {
        'path': filePath,
      });
      return Duration(milliseconds: result ?? 0);
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Interroga il layer nativo per sapere se il player sta ancora riproducendo.
  Future<bool> checkIsPlayingNative() async {
    try {
      return await _channel.invokeMethod<bool>('isPlaying') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Configura la categoria della sessione audio nativa.
  Future<bool> setAudioSessionCategory(
    String category, {
    List<String> options = const ['defaultToSpeaker', 'allowBluetooth'],
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setAudioSessionCategory',
        {'category': category, 'options': options},
      );
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
}
