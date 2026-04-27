// File: lib/services/audio/audio_service_coordinator.dart
//
// Audio Service Coordinator - Service Layer
// ==========================================
//
// Coordinator per le operazioni di registrazione e file audio in WavNote.
// Il playback UI passa esclusivamente da RecordingPlaybackCoordinator/IAudioPlaybackEngine.
// Su iOS/macOS usa AudioEngineService (AVAudioEngine nativo) per la registrazione.
// Il codice del package `record` è mantenuto come fallback per non-iOS.
//
// Regole:
// - Responsabilità limitata alla registrazione e agli helper file/audio
// - initialize() idempotente tramite _isInitialized
// - Stream di registrazione unificati per il layer di presentazione

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/recording_entity.dart';
import '../../domain/entities/audio_types.dart';
import '../../core/enums/audio_format.dart';
import 'audio_recorder_service.dart';
import 'audio_engine_service.dart';

enum AudioClockMode { idle, recording, playback }

sealed class ClockTick {
  const ClockTick();
}

final class RecordingClockTick extends ClockTick {
  const RecordingClockTick({required this.position, required this.amplitude});
  final Duration position;
  final double amplitude;
}

class AudioServiceCoordinator {
  static const MethodChannel _audioTrimmerChannel = MethodChannel(
    'wavnote/audio_trimmer',
  );
  late final AudioRecorderService _recordingService;

  AudioEngineService? _engineService;
  final AudioEngineService? _injectedEngine;

  bool get _useNativeEngine => Platform.isIOS || Platform.isMacOS;

  // Stato registrazione nativa
  bool _iosNativeActive = false;
  String? _iosRecordingPath;
  AudioFormat _iosFormat = AudioFormat.m4a;
  int _iosSampleRate = 44100;
  DateTime? _iosRecordingStartTime;
  Duration _iosPausedDuration = Duration.zero;
  DateTime? _iosPauseStartTime;

  bool _isInitialized = false;

  StreamController<double>? _amplitudeController;
  StreamController<Duration>? _positionController;
  StreamController<ClockTick>? _clockController;

  StreamSubscription<RecordingTick>? _engineAmplitudeSubscription;
  StreamSubscription<double>? _recordingAmplitudeSubscription;
  StreamSubscription<Duration>? _recordingPositionSubscription;

  AudioServiceCoordinator({AudioEngineService? engineService})
      : _injectedEngine = engineService {
    _recordingService = AudioRecorderService();
  }

  // ==== INITIALIZATION ====

  bool get needsDisposal => true;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _amplitudeController = StreamController<double>.broadcast();
      _positionController = StreamController<Duration>.broadcast();
      _clockController = StreamController<ClockTick>.broadcast();

      if (_useNativeEngine) {
        _engineService = _injectedEngine ?? AudioEngineService();
        final engineInit = await _engineService!.initialize();
        if (engineInit) {
          debugPrint('✅ AudioServiceCoordinator: AVAudioEngine inizializzato');
        } else {
          debugPrint('❌ AudioServiceCoordinator: AVAudioEngine fallito');
          return false;
        }
        _isInitialized = true;
      } else {
        final recordingInit = await _recordingService.initialize();
        _isInitialized = recordingInit;
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

  Future<void> dispose() async {
    try {
      _engineAmplitudeSubscription?.cancel();

      if (_useNativeEngine) {
        await _engineService?.dispose();
      } else {
        await _recordingService.dispose();
      }

      await _amplitudeController?.close();
      await _positionController?.close();
      await _clockController?.close();
      _clockController = null;

      _isInitialized = false;
      _iosNativeActive = false;
      debugPrint('✅ AudioServiceCoordinator disposed');
    } catch (e) {
      debugPrint('❌ AudioServiceCoordinator dispose: $e');
    }
  }

  // ==== RECORDING OPERATIONS ====

  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
  }) async {
    if (!_isInitialized) return false;

    if (_useNativeEngine && _engineService != null) {
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

    final success = await _recordingService.startRecording(
      filePath: filePath,
      format: format,
      sampleRate: sampleRate,
      bitRate: bitRate,
    );
    if (success) {
      _setupRecordingStreams();
    }
    return success;
  }

  Future<RecordingEntity?> stopRecording({bool raw = false}) async {
    if (_useNativeEngine && _iosNativeActive && _engineService != null) {
      final rawResult = await _engineService!.stopRecording(raw: raw);
      _iosNativeActive = false;
      _cleanupEngineAmplitudeStream();

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

      debugPrint(
        '✅ Registrazione fermata${raw ? " (raw WAV)" : ""}: ${recording.name} (${duration.inMilliseconds}ms)',
      );
      return recording;
    }

    final result = await _recordingService.stopRecording(raw: raw);
    _cleanupRecordingStreams();
    return result;
  }

  Future<bool> pauseRecording() async {
    if (_useNativeEngine && _iosNativeActive && _engineService != null) {
      final result = await _engineService!.pauseRecording();
      if (result) {
        _iosPauseStartTime = DateTime.now();
        _cleanupEngineAmplitudeStream();
      }
      return result;
    }
    return await _recordingService.pauseRecording();
  }

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
    return await _recordingService.resumeRecording();
  }

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
    final result = await _recordingService.cancelRecording();
    _cleanupRecordingStreams();
    return result;
  }

  Future<bool> isRecording() async {
    if (_useNativeEngine) {
      return _iosNativeActive &&
          (_engineService?.isRecording ?? false) &&
          !(_engineService?.isRecordingPaused ?? false);
    }
    return await _recordingService.isRecording();
  }

  Future<bool> isRecordingPaused() async {
    if (_useNativeEngine) return _engineService?.isRecordingPaused ?? false;
    return await _recordingService.isRecordingPaused();
  }

  Future<Duration> getCurrentRecordingDuration() async {
    if (_useNativeEngine && _iosNativeActive) return _calculateIosDuration();
    return await _recordingService.getCurrentRecordingDuration();
  }

  Stream<ClockTick> get activeClockStream =>
      _clockController?.stream ?? const Stream.empty();

  Stream<double> getRecordingAmplitudeStream() =>
      _amplitudeController?.stream ?? const Stream.empty();

  Stream<double>? get amplitudeStream => _amplitudeController?.stream;

  Stream<Duration>? get durationStream => _positionController?.stream;

  Future<double> getCurrentAmplitude() async {
    if (_useNativeEngine && _iosNativeActive && _engineService != null) {
      return await _engineService!.getCurrentAmplitude();
    }
    return await _recordingService.getCurrentAmplitude();
  }

  // ==== AUDIO FILE OPERATIONS ====

  Future<AudioFileInfo?> getAudioFileInfo(String filePath) =>
      _recordingService.getAudioFileInfo(filePath);

  Future<String?> convertAudioFile({
    required String inputPath,
    required String outputPath,
    required AudioFormat targetFormat,
    int? targetSampleRate,
    int? targetBitRate,
  }) async {
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

  Future<String?> trimAudioFile({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
  }) async {
    if (_useNativeEngine) {
      try {
        final durationMs = (endTime - startTime).inMilliseconds;
        if (durationMs <= 0) {
          debugPrint('❌ AudioServiceCoordinator: Invalid trim duration.');
          return null;
        }
        await _audioTrimmerChannel.invokeMethod('trimAudio', {
          'filePath': inputPath,
          'startTimeMs': startTime.inMilliseconds,
          'durationMs': durationMs,
          'outputPath': outputPath,
          'format': 'm4a',
        });
        debugPrint('✅ Audio trim nativo completato: $outputPath');
        return outputPath;
      } on PlatformException catch (e) {
        debugPrint('❌ Errore trim audio nativo: ${e.message}');
        return null;
      }
    }
    return _recordingService.trimAudioFile(
      inputPath: inputPath,
      outputPath: outputPath,
      startTime: startTime,
      endTime: endTime,
    );
  }

  Future<String?> mergeAudioFiles({
    required List<String> inputPaths,
    required String outputPath,
    required AudioFormat outputFormat,
  }) => _recordingService.mergeAudioFiles(
    inputPaths: inputPaths,
    outputPath: outputPath,
    outputFormat: outputFormat,
  );

  Future<List<double>> getWaveformData(
    String filePath, {
    int sampleCount = 100,
  }) => _recordingService.getWaveformData(filePath, sampleCount: sampleCount);

  Future<Duration> getAudioDuration(String filePath) async {
    if (_useNativeEngine && _engineService != null) {
      final resolvedPath = await _resolvePath(filePath);
      return await _engineService!.getAudioDuration(resolvedPath);
    }
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(filePath);
      return duration ?? Duration.zero;
    } catch (_) {
      return Duration.zero;
    } finally {
      await player.dispose();
    }
  }

  // ==== DEVICE & PERMISSIONS ====

  Future<bool> hasMicrophonePermission() =>
      _recordingService.hasMicrophonePermission();

  Future<bool> requestMicrophonePermission() =>
      _recordingService.requestMicrophonePermission();

  Future<bool> hasMicrophone() => _recordingService.hasMicrophone();

  Future<List<AudioInputDevice>> getAudioInputDevices() =>
      _recordingService.getAudioInputDevices();

  Future<bool> setAudioInputDevice(String deviceId) =>
      _recordingService.setAudioInputDevice(deviceId);

  Future<List<AudioFormat>> getSupportedFormats() =>
      _recordingService.getSupportedFormats();

  Future<List<int>> getSupportedSampleRates(AudioFormat format) =>
      _recordingService.getSupportedSampleRates(format);

  // ==== SETTINGS ====

  Future<bool> setAudioSessionCategory(AudioSessionCategory category) async =>
      _useNativeEngine
      ? (await _engineService?.setAudioSessionCategory(category.name) ?? false)
      : true;

  Future<bool> enableBackgroundRecording() async => true;

  Future<bool> disableBackgroundRecording() async => true;

  // ==== PRIVATE HELPERS ====

  void _setupEngineAmplitudeStream() {
    _engineAmplitudeSubscription?.cancel();
    _engineAmplitudeSubscription = _engineService?.recordingTickStream.listen((
      tick,
    ) {
      _amplitudeController?.add(tick.amplitude);
      _positionController?.add(tick.position);
      _clockController?.add(
        RecordingClockTick(position: tick.position, amplitude: tick.amplitude),
      );
    });
  }

  void _cleanupEngineAmplitudeStream() {
    _engineAmplitudeSubscription?.cancel();
    _engineAmplitudeSubscription = null;
    _amplitudeController?.add(0.0);
  }

  void _setupRecordingStreams() {
    _recordingAmplitudeSubscription?.cancel();
    _recordingAmplitudeSubscription = _recordingService
        .getRecordingAmplitudeStream()
        .listen((amp) => _amplitudeController?.add(amp));

    _recordingPositionSubscription?.cancel();
    _recordingPositionSubscription = _recordingService.durationStream?.listen(
      (pos) => _positionController?.add(pos),
    );
  }

  void _cleanupRecordingStreams() {
    _recordingAmplitudeSubscription?.cancel();
    _recordingAmplitudeSubscription = null;
    _recordingPositionSubscription?.cancel();
    _recordingPositionSubscription = null;
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
        if (folder.isNotEmpty && RegExp(r'^\d+$').hasMatch(folder)) {
          return folder;
        }
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
