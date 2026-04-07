// File: services/audio/audio_service_coordinator.dart
//
// Audio Service Coordinator - Service Layer
// ==========================================
//
// Coordinator per tutte le operazioni audio in WavNote.
// Su iOS/macOS usa AudioEngineService (AVAudioEngine nativo) per la registrazione.
// Il codice del package `record` è mantenuto commentato come fallback.
//
// Regole:
// - Un solo servizio attivo alla volta (registrazione OPPURE playback)
// - initialize() idempotente tramite _isInitialized
// - Stream unificati per il layer di presentazione

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_audio_service_repository.dart';
import '../../core/enums/audio_format.dart';
// import 'audio_recorder_service.dart'; // package record — mantenuto come fallback
import 'audio_recorder_service.dart';
import 'audio_player_service.dart';
import 'audio_engine_service.dart';

class AudioServiceCoordinator implements IAudioServiceRepository {
  // package record — mantenuto ma non usato su iOS per la registrazione
  late final AudioRecorderService _recordingService;
  late final AudioPlayerService _playbackService;

  // Motore nativo AVAudioEngine (iOS + macOS)
  AudioEngineService? _engineService;

  /// True se la piattaforma supporta il motore nativo AVAudioEngine.
  bool get _useNativeEngine => Platform.isIOS || Platform.isMacOS;

  // Stato registrazione nativa
  bool _iosNativeActive = false;
  String? _iosRecordingPath;
  AudioFormat _iosFormat = AudioFormat.m4a;
  int _iosSampleRate = 44100;
  DateTime? _iosRecordingStartTime;
  Duration _iosPausedDuration = Duration.zero;
  DateTime? _iosPauseStartTime;

  IAudioServiceRepository? _activePlayer;

  // Playback nativo via engine durante registrazione in pausa (iOS/macOS)
  bool _nativePlaybackActive = false;
  Timer? _nativeCompletionTimer;

  bool _isInitialized = false;

  StreamController<double>? _amplitudeController;
  StreamController<Duration>? _positionController;
  StreamController<void>? _completionController;

  StreamSubscription<double>? _engineAmplitudeSubscription;
  // StreamSubscription<double>? _recordingAmplitudeSubscription; // record fallback
  // StreamSubscription<Duration>? _recordingPositionSubscription;
  // StreamSubscription<void>? _recordingCompletionSubscription;
  StreamSubscription<Duration>? _playbackPositionSubscription;
  StreamSubscription<void>? _playbackCompletionSubscription;

  AudioServiceCoordinator() {
    _recordingService = AudioRecorderService();
    _playbackService = AudioPlayerService.instance;
  }

  // ==== INITIALIZATION ====

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _amplitudeController = StreamController<double>.broadcast();
      _positionController = StreamController<Duration>.broadcast();
      _completionController = StreamController<void>.broadcast();

      // Inizializza il playback (sempre)
      final playbackInit = await _playbackService.initialize();

      if (_useNativeEngine) {
        // Usa AVAudioEngine nativo (iOS + macOS) — NON inizializzare _recordingService
        _engineService = AudioEngineService();
        final engineInit = await _engineService!.initialize();
        if (engineInit) {
          debugPrint('✅ AudioServiceCoordinator: AVAudioEngine inizializzato');
        } else {
          debugPrint('❌ AudioServiceCoordinator: AVAudioEngine fallito');
          return false;
        }
        _isInitialized = playbackInit;
      } else {
        // Non-iOS: usa package record
        final recordingInit = await _recordingService.initialize();
        _isInitialized = recordingInit && playbackInit;
      }

      if (_isInitialized) {
        debugPrint('✅ AudioServiceCoordinator inizializzato');
      }
      return _isInitialized;
    } catch (e) {
      debugPrint('❌ AudioServiceCoordinator.initialize: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      _engineAmplitudeSubscription?.cancel();
      _nativeCompletionTimer?.cancel();
      _nativeCompletionTimer = null;
      await _playbackPositionSubscription?.cancel();
      await _playbackCompletionSubscription?.cancel();

      if (_useNativeEngine) {
        await _engineService?.dispose();
      } else {
        await _recordingService.dispose();
      }
      await _playbackService.dispose();

      await _amplitudeController?.close();
      await _positionController?.close();
      await _completionController?.close();

      _isInitialized = false;
      _iosNativeActive = false;
      debugPrint('✅ AudioServiceCoordinator disposed');
    } catch (e) {
      debugPrint('❌ AudioServiceCoordinator dispose: $e');
    }
  }

  // ==== RECORDING OPERATIONS ====

  @override
  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
  }) async {
    if (!_isInitialized) return false;

    if (await _playbackService.isPlaying()) {
      await _playbackService.stopPlaying();
    }

    if (_useNativeEngine && _engineService != null) {
      // ── Percorso nativo AVAudioEngine ─────────────────────────────
      final resolvedPath = await _resolvePath(filePath);
      await File(resolvedPath).parent.create(recursive: true);

      final success = await _engineService!.startRecording(
        path: resolvedPath,
        sampleRate: sampleRate,
        bitRate: bitRate,
        format: format.fileExtension.substring(1), // 'wav', 'm4a', 'flac'
      );

      if (success) {
        _iosNativeActive = true;
        _iosRecordingPath = resolvedPath;
        _iosFormat = format;
        _iosSampleRate = sampleRate;
        _iosRecordingStartTime = DateTime.now();
        _iosPausedDuration = Duration.zero;
        _iosPauseStartTime = null;
        _setupEngineAmplitudeStream();
        debugPrint('✅ Registrazione avviata via AVAudioEngine: $resolvedPath');
      }
      return success;
    }

    // ── Fallback package record (non-iOS) ──────────────────────────
    // final success = await _recordingService.startRecording(
    //   filePath: filePath,
    //   format: format,
    //   sampleRate: sampleRate,
    //   bitRate: bitRate,
    // );
    // if (success) {
    //   _setupRecordingStreams();
    // }
    // return success;
    return false;
  }

  @override
  Future<RecordingEntity?> stopRecording({bool raw = false}) async {
    if (_useNativeEngine && _iosNativeActive && _engineService != null) {
      final rawResult = await _engineService!.stopRecording(raw: raw);
      _iosNativeActive = false;
      _cleanupEngineAmplitudeStream();

      // In raw mode il nativo restituisce il path WAV effettivo;
      // altrimenti usa il path originale (_iosRecordingPath) che è nel formato finale.
      final nativePath = rawResult?['path'] as String?;
      final path = raw ? (nativePath ?? _iosRecordingPath) : _iosRecordingPath;
      if (path == null) return null;

      final nativeDurationMs = (rawResult?['duration'] as num?)?.toInt();
      final duration = nativeDurationMs != null
          ? Duration(milliseconds: nativeDurationMs)
          : _calculateIosDuration();

      final file = File(path);
      if (!await file.exists()) {
        debugPrint('❌ File registrazione non trovato: $path');
        return null;
      }
      final fileSize = await file.length();

      final recording = RecordingEntity.create(
        name: _generateIosName(),
        filePath: path,
        folderId: _extractFolderId(path),
        format: _iosFormat,
        duration: duration,
        fileSize: fileSize,
        sampleRate: _iosSampleRate,
      );

      _iosRecordingPath = null;
      _iosRecordingStartTime = null;
      _iosPausedDuration = Duration.zero;
      _iosPauseStartTime = null;

      debugPrint('✅ Registrazione fermata${raw ? " (raw WAV)" : ""}: ${recording.name} (${duration.inMilliseconds}ms)');
      return recording;
    }

    // Fallback non-iOS
    // return await _recordingService.stopRecording();
    return null;
  }

  @override
  Future<bool> pauseRecording() async {
    if (_useNativeEngine && _iosNativeActive && _engineService != null) {
      final result = await _engineService!.pauseRecording();
      if (result) {
        _iosPauseStartTime = DateTime.now();
        _cleanupEngineAmplitudeStream();
      }
      return result;
    }
    // return await _recordingService.pauseRecording();
    return false;
  }

  @override
  Future<bool> resumeRecording() async {
    if (_useNativeEngine && _iosNativeActive && _engineService != null) {
      final result = await _engineService!.resumeRecording();
      if (result) {
        if (_iosPauseStartTime != null) {
          _iosPausedDuration += DateTime.now().difference(_iosPauseStartTime!);
          _iosPauseStartTime = null;
        }
        _setupEngineAmplitudeStream();
      }
      return result;
    }
    // return await _recordingService.resumeRecording();
    return false;
  }

  @override
  Future<bool> cancelRecording() async {
    if (_useNativeEngine && _iosNativeActive && _engineService != null) {
      await _engineService!.cancelRecording();
      _iosNativeActive = false;
      _cleanupEngineAmplitudeStream();
      _iosRecordingPath = null;
      _iosRecordingStartTime = null;
      _iosPausedDuration = Duration.zero;
      _iosPauseStartTime = null;
      return true;
    }
    // return await _recordingService.cancelRecording();
    return false;
  }

  @override
  Future<bool> isRecording() async {
    if (_useNativeEngine) {
      return _iosNativeActive &&
          (_engineService?.isRecording ?? false) &&
          !(_engineService?.isRecordingPaused ?? false);
    }
    // return await _recordingService.isRecording();
    return false;
  }

  @override
  Future<bool> isRecordingPaused() async {
    if (_useNativeEngine) return _engineService?.isRecordingPaused ?? false;
    // return await _recordingService.isRecordingPaused();
    return false;
  }

  @override
  Future<Duration> getCurrentRecordingDuration() async {
    if (_useNativeEngine && _iosNativeActive) return _calculateIosDuration();
    // return await _recordingService.getCurrentRecordingDuration();
    return Duration.zero;
  }

  @override
  Stream<double> getRecordingAmplitudeStream() =>
      _amplitudeController?.stream ?? const Stream.empty();

  @override
  Stream<double>? get amplitudeStream => _amplitudeController?.stream;

  @override
  Stream<Duration>? get durationStream => _positionController?.stream;

  @override
  Future<double> getCurrentAmplitude() async {
    if (_useNativeEngine && _iosNativeActive && _engineService != null) {
      return await _engineService!.getCurrentAmplitude();
    }
    // return await _recordingService.getCurrentAmplitude();
    return 0.0;
  }

  // ==== PLAYBACK OPERATIONS ====

  @override
  Future<bool> startPlaying(String filePath, {Duration? initialPosition}) async {
    try {
      if (!_isInitialized) {
        final ok = await initialize();
        if (!ok) return false;
      }

      // Durante registrazione nativa in pausa (iOS/macOS), il file finale (.m4a) non
      // esiste ancora: solo i segmenti WAV interni esistono.
      // Il motore nativo gestisce startPlaybackFromSegments automaticamente.
      if (_useNativeEngine && _iosNativeActive && _engineService != null) {
        final resolvedPath = await _resolvePath(filePath);
        final success = await _engineService!.startPlayback(resolvedPath);
        if (success) {
          if (initialPosition != null && initialPosition > Duration.zero) {
            await _engineService!.seekTo(initialPosition);
          }
          _nativePlaybackActive = true;
          _setupNativePlaybackStreams();
          debugPrint('✅ AudioServiceCoordinator: playback nativo avviato (registrazione in pausa)');
        }
        return success;
      }

      if (!_playbackService.isServiceReady) {
        final ok = await _playbackService.initialize();
        if (!ok) return false;
      }

      final resolvedPath = await _resolvePath(filePath);
      final success = await _playbackService.startPlaying(
        resolvedPath,
        initialPosition: initialPosition,
      );
      if (success) {
        _activePlayer = _playbackService;
        _setupPlaybackStreams();
        debugPrint('✅ AudioServiceCoordinator: playback avviato');
      }
      return success;
    } catch (e) {
      debugPrint('❌ AudioServiceCoordinator: errore playback: $e');
      return false;
    }
  }

  @override
  Future<bool> stopPlaying() async {
    if (_nativePlaybackActive && _engineService != null) {
      await _engineService!.stopPlayback();
      _nativePlaybackActive = false;
      _cleanupNativePlaybackStreams();
      return true;
    }
    if (_activePlayer == null) return false;
    final result = await _activePlayer!.stopPlaying();
    _activePlayer = null;
    _cleanupPlaybackStreams();
    return result;
  }

  @override
  Future<bool> pausePlaying() async =>
      _activePlayer == null ? false : await _activePlayer!.pausePlaying();

  @override
  Future<bool> resumePlaying() async =>
      _activePlayer == null ? false : await _activePlayer!.resumePlaying();

  @override
  Future<bool> seekTo(Duration position) async =>
      _activePlayer == null ? false : await _activePlayer!.seekTo(position);

  Future<bool> seekToWithRecordingDuration(
      Duration position, Duration recordingDuration) async {
    if (_activePlayer == null) return false;
    if (position.isNegative || position > recordingDuration) return false;
    return await (_activePlayer as AudioPlayerService)
        .seekToWithRecordingDuration(position, recordingDuration);
  }

  @override
  Future<bool> setPlaybackSpeed(double speed) async =>
      _activePlayer == null ? false : await _activePlayer!.setPlaybackSpeed(speed);

  @override
  Future<bool> setVolume(double volume) async =>
      _activePlayer == null ? false : await _activePlayer!.setVolume(volume);

  @override
  Future<bool> isPlaying() async {
    if (_nativePlaybackActive) {
      return await _engineService?.checkIsPlayingNative() ?? false;
    }
    return _activePlayer == null ? false : await _activePlayer!.isPlaying();
  }

  @override
  Future<bool> isPlaybackPaused() async =>
      _activePlayer == null ? false : await _activePlayer!.isPlaybackPaused();

  @override
  Future<Duration> getCurrentPlaybackPosition() async =>
      _activePlayer == null ? Duration.zero : await _activePlayer!.getCurrentPlaybackPosition();

  @override
  Future<Duration> getCurrentPlaybackDuration() async =>
      _activePlayer == null ? Duration.zero : await _activePlayer!.getCurrentPlaybackDuration();

  @override
  Stream<Duration> getPlaybackPositionStream() =>
      _positionController?.stream ?? const Stream.empty();

  @override
  Stream<void> getPlaybackCompletionStream() =>
      _completionController?.stream ?? const Stream.empty();

  // ==== AUDIO FILE OPERATIONS ====

  @override
  Future<AudioFileInfo?> getAudioFileInfo(String filePath) =>
      _recordingService.getAudioFileInfo(filePath);

  @override
  Future<String?> convertAudioFile({
    required String inputPath,
    required String outputPath,
    required AudioFormat targetFormat,
    int? targetSampleRate,
    int? targetBitRate,
  }) async {
    // Su iOS usa il motore nativo per la conversione WAV → formato finale
    if (_useNativeEngine && _engineService != null) {
      final result = await _engineService!.convertAudio(
        wavPath: inputPath,
        outputPath: outputPath,
        format: targetFormat.fileExtension.substring(1),
      );
      return result?['path'] as String?;
    }
    return _recordingService.convertAudioFile(
      inputPath: inputPath,
      outputPath: outputPath,
      targetFormat: targetFormat,
      targetSampleRate: targetSampleRate,
      targetBitRate: targetBitRate,
    );
  }

  @override
  Future<String?> trimAudioFile({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
  }) => _recordingService.trimAudioFile(
        inputPath: inputPath,
        outputPath: outputPath,
        startTime: startTime,
        endTime: endTime,
      );

  @override
  Future<String?> mergeAudioFiles({
    required List<String> inputPaths,
    required String outputPath,
    required AudioFormat outputFormat,
  }) => _recordingService.mergeAudioFiles(
        inputPaths: inputPaths,
        outputPath: outputPath,
        outputFormat: outputFormat,
      );

  @override
  Future<List<double>> getWaveformData(String filePath, {int sampleCount = 100}) =>
      _recordingService.getWaveformData(filePath, sampleCount: sampleCount);

  // ==== DEVICE & PERMISSIONS ====

  @override
  Future<bool> hasMicrophonePermission() =>
      _recordingService.hasMicrophonePermission();

  @override
  Future<bool> requestMicrophonePermission() =>
      _recordingService.requestMicrophonePermission();

  @override
  Future<bool> hasMicrophone() => _recordingService.hasMicrophone();

  @override
  Future<List<AudioInputDevice>> getAudioInputDevices() =>
      _recordingService.getAudioInputDevices();

  @override
  Future<bool> setAudioInputDevice(String deviceId) =>
      _recordingService.setAudioInputDevice(deviceId);

  @override
  Future<List<AudioFormat>> getSupportedFormats() =>
      _recordingService.getSupportedFormats();

  @override
  Future<List<int>> getSupportedSampleRates(AudioFormat format) =>
      _recordingService.getSupportedSampleRates(format);

  // ==== SETTINGS ====

  @override
  Future<bool> setAudioSessionCategory(AudioSessionCategory category) async {
    return await _playbackService.setAudioSessionCategory(category);
  }

  @override
  Future<bool> enableBackgroundRecording() async => true;

  @override
  Future<bool> disableBackgroundRecording() async => true;

  // ==== CACHE / PRELOAD ====

  Future<bool> preloadAudioSource(String filePath) async {
    if (!_isInitialized) return false;
    if (!_playbackService.isServiceReady) {
      final ok = await _playbackService.initialize();
      if (!ok) return false;
    }
    return await _playbackService.preloadAudioSource(filePath);
  }

  void clearAudioCache() => _playbackService.clearCache();

  Map<String, dynamic> getAudioCacheStats() => _playbackService.getCacheStats();

  // ==== PRIVATE HELPERS ====

  void _setupEngineAmplitudeStream() {
    _engineAmplitudeSubscription?.cancel();
    _engineAmplitudeSubscription = _engineService?.amplitudeStream.listen(
      (amp) => _amplitudeController?.add(amp),
    );
  }

  void _cleanupEngineAmplitudeStream() {
    _engineAmplitudeSubscription?.cancel();
    _engineAmplitudeSubscription = null;
    _amplitudeController?.add(0.0);
  }

  // // package record stream helpers — mantenuti commentati
  // void _setupRecordingStreams() { ... }
  // void _cleanupRecordingStreams() { ... }

  /// Configura gli stream di posizione e completion per il playback nativo
  /// (durante registrazione in pausa su iOS/macOS).
  void _setupNativePlaybackStreams() {
    _playbackPositionSubscription?.cancel();
    _playbackPositionSubscription = _engineService!.positionStream.listen(
      (pos) => _positionController?.add(pos),
    );

    // Il motore nativo non ha uno stream di completion: poll ogni 200ms
    _nativeCompletionTimer?.cancel();
    _nativeCompletionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final stillPlaying = await _engineService?.checkIsPlayingNative() ?? false;
      if (!stillPlaying && _nativePlaybackActive) {
        _nativeCompletionTimer?.cancel();
        _nativeCompletionTimer = null;
        _nativePlaybackActive = false;
        _playbackPositionSubscription?.cancel();
        _playbackPositionSubscription = null;
        _completionController?.add(null);
      }
    });
  }

  void _cleanupNativePlaybackStreams() {
    _nativeCompletionTimer?.cancel();
    _nativeCompletionTimer = null;
    _playbackPositionSubscription?.cancel();
    _playbackPositionSubscription = null;
  }

  void _setupPlaybackStreams() {
    _playbackPositionSubscription =
        _playbackService.getPlaybackPositionStream().listen(
              (pos) => _positionController?.add(pos),
            );
    _playbackCompletionSubscription =
        _playbackService.getPlaybackCompletionStream().listen(
              (_) => _completionController?.add(null),
            );
  }

  void _cleanupPlaybackStreams() {
    _playbackPositionSubscription?.cancel();
    _playbackCompletionSubscription?.cancel();
    _playbackPositionSubscription = null;
    _playbackCompletionSubscription = null;
  }

  Duration _calculateIosDuration() {
    if (_iosRecordingStartTime == null) return Duration.zero;
    final elapsed = DateTime.now().difference(_iosRecordingStartTime!);
    var paused = _iosPausedDuration;
    if (_iosPauseStartTime != null) {
      paused += DateTime.now().difference(_iosPauseStartTime!);
    }
    return elapsed - paused;
  }

  String _generateIosName() {
    final now = DateTime.now();
    return 'Recording '
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
  }

  String _extractFolderId(String filePath) {
    try {
      final parts = filePath.split('/');
      if (parts.length >= 2) {
        final folder = parts[parts.length - 2];
        if (folder.isNotEmpty && RegExp(r'^\d+$').hasMatch(folder)) return folder;
      }
    } catch (_) {}
    return 'all_recordings';
  }

  Future<String> _resolvePath(String path) async {
    if (path.startsWith('/')) return path;
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$path';
  }
}
