// File: services/audio/audio_service_coordinator.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_audio_service_repository.dart';
import '../../core/enums/audio_format.dart';
import 'audio_recorder_service.dart';
import 'audio_player_service.dart';
import 'audio_engine_service.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failure_types/audio_failures.dart';

enum AudioClockMode { idle, recording, playback }

sealed class ClockTick {
  const ClockTick();
}

final class RecordingClockTick extends ClockTick {
  const RecordingClockTick({required this.position, required this.amplitude});
  final Duration position;
  final double amplitude;
}

final class PlaybackClockTick extends ClockTick {
  const PlaybackClockTick({
    required this.position,
    required this.totalDuration,
  });
  final Duration position;
  final Duration totalDuration;
}

class AudioServiceCoordinator implements IAudioServiceRepository {
  static const MethodChannel _audioTrimmerChannel = MethodChannel(
    'wavnote/audio_trimmer',
  );
  late final AudioRecorderService _recordingService;
  late final AudioPlayerService _playbackService;
  AudioEngineService? _engineService;

  bool get _useNativeEngine => Platform.isIOS || Platform.isMacOS;

  // Stato nativo ripristinato
  bool _iosNativeActive = false;
  String? _iosRecordingPath;
  AudioFormat _iosFormat = AudioFormat.m4a;
  int _iosSampleRate = 44100;

  bool _isInitialized = false;
  Duration _lastRecordingDuration = Duration.zero;

  StreamController<double>? _amplitudeController;
  StreamController<Duration>? _positionController;
  StreamController<void>? _completionController;
  StreamController<ClockTick>? _clockController;

  StreamSubscription<RecordingTick>? _engineAmplitudeSubscription;
  StreamSubscription<double>? _recordingAmplitudeSubscription;
  StreamSubscription<Duration>? _recordingPositionSubscription;
  StreamSubscription<PlaybackTick>? _nativePlaybackPositionSubscription;
  StreamSubscription<Duration>? _playbackPositionSubscription;
  StreamSubscription<void>? _playbackCompletionSubscription;

  AudioServiceCoordinator() {
    _recordingService = AudioRecorderService();
    _playbackService = AudioPlayerService.instance;
  }

  @override
  bool get needsDisposal => true;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _amplitudeController = StreamController<double>.broadcast();
      _positionController = StreamController<Duration>.broadcast();
      _completionController = StreamController<void>.broadcast();
      _clockController = StreamController<ClockTick>.broadcast();

      final playbackInit = await _playbackService.initialize();

      if (_useNativeEngine) {
        _engineService = AudioEngineService();
        final engineInit = await _engineService!.initialize();
        if (!engineInit)
          throw const AudioPlaybackException(
            message: 'Engine Init Failed',
            errorType: AudioPlaybackErrorType.playbackInitializationFailed,
          );
        _isInitialized = playbackInit;
      } else {
        final recordingInit = await _recordingService.initialize();
        _isInitialized = recordingInit && playbackInit;
      }
      return _isInitialized;
    } catch (e) {
      throw AudioPlaybackException(
        message: 'Failed to init: $e',
        errorType: AudioPlaybackErrorType.playbackInitializationFailed,
        originalError: e,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _engineAmplitudeSubscription?.cancel();
    _nativePlaybackPositionSubscription?.cancel();
    await _playbackPositionSubscription?.cancel();
    await _playbackCompletionSubscription?.cancel();
    if (_useNativeEngine)
      await _engineService?.dispose();
    else
      await _recordingService.dispose();
    await _playbackService.dispose();
    await _amplitudeController?.close();
    await _positionController?.close();
    await _completionController?.close();
    await _clockController?.close();
    _clockController = null;
    _isInitialized = false;
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
    if (await _playbackService.isPlaying())
      await _playbackService.stopPlaying();

    if (_useNativeEngine && _engineService != null) {
      _iosRecordingPath = filePath;
      _iosFormat = format;
      _iosSampleRate = sampleRate;
      _iosNativeActive = true;
      _lastRecordingDuration = Duration.zero;

      // Setup clock subscriptions to forward ticks to controllers
      _engineAmplitudeSubscription = _engineService!.recordingTickStream.listen(
        (tick) {
          _lastRecordingDuration = tick.position;
          _amplitudeController?.add(tick.amplitude);
          _positionController?.add(tick.position);
        },
      );

      return await _engineService!.startRecording(
        path: filePath,
        format: format.fileExtension,
        sampleRate: sampleRate,
        bitRate: bitRate,
      );
    }
    return await _recordingService.startRecording(
      filePath: filePath,
      format: format,
      sampleRate: sampleRate,
      bitRate: bitRate,
    );
  }

  @override
  Future<RecordingEntity?> stopRecording({bool raw = false}) async {
    if (_useNativeEngine && _engineService != null && _iosNativeActive) {
      _iosNativeActive = false;

      // Cancel clock subscription
      _engineAmplitudeSubscription?.cancel();
      _engineAmplitudeSubscription = null;

      final result = await _engineService!.stopRecording(raw: raw);
      debugPrint('🔍 AudioServiceCoordinator stopRecording result: $result');
      if (result == null) return null;
      // Mappatura robusta da Map a RecordingEntity
      return RecordingEntity(
        id:
            result['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: result['name']?.toString() ?? 'Recording',
        filePath:
            result['path']?.toString() ?? result['filePath']?.toString() ?? '',
        folderId: result['folderId']?.toString() ?? 'all_recordings',
        format: AudioFormat.values[(result['format'] as num?)?.toInt() ?? 0],
        duration: Duration(
          milliseconds:
              (result['duration'] as num?)?.toInt() ??
              (result['durationMs'] as num?)?.toInt() ??
              0,
        ),
        fileSize: (result['fileSize'] as num?)?.toInt() ?? 0,
        sampleRate: (result['sampleRate'] as num?)?.toInt() ?? 44100,
        createdAt:
            DateTime.tryParse(result['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
    }
    return await _recordingService.stopRecording(raw: raw);
  }

  @override
  Future<bool> pauseRecording() async {
    if (_useNativeEngine && _engineService != null && _iosNativeActive)
      return await _engineService!.pauseRecording();
    return await _recordingService.pauseRecording();
  }

  @override
  Future<bool> resumeRecording() async {
    if (_useNativeEngine && _engineService != null && _iosNativeActive)
      return await _engineService!.resumeRecording();
    return await _recordingService.resumeRecording();
  }

  @override
  Future<bool> cancelRecording() async {
    if (_useNativeEngine && _engineService != null && _iosNativeActive) {
      _iosNativeActive = false;
      return await _engineService!.cancelRecording();
    }
    return await _recordingService.cancelRecording();
  }

  @override
  Future<bool> isRecording() async {
    if (_useNativeEngine && _engineService != null)
      return _engineService!.isRecording;
    return await _recordingService.isRecording();
  }

  @override
  Future<bool> isRecordingPaused() async {
    if (_useNativeEngine && _engineService != null)
      return _engineService!.isRecordingPaused;
    return await _recordingService.isRecordingPaused();
  }

  @override
  Future<Duration> getCurrentRecordingDuration() async {
    if (_useNativeEngine && _engineService != null)
      return _lastRecordingDuration; // Usare la variabile invece di Duration.zero
    return await _recordingService.getCurrentRecordingDuration();
  }

  @override
  Stream<double> getRecordingAmplitudeStream() {
    if (_useNativeEngine) {
      return _amplitudeController?.stream ?? const Stream.empty();
    }
    return _recordingService.getRecordingAmplitudeStream();
  }

  @override
  Stream<double>? get amplitudeStream => _amplitudeController?.stream;

  @override
  Stream<Duration>? get durationStream => _positionController?.stream;

  @override
  Future<double> getCurrentAmplitude() async =>
      _recordingService.getCurrentAmplitude();

  // ==== PLAYBACK OPERATIONS (Legacy - Contrassegnati come Deprecated) ====
  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Future<bool> startPlaying(
    String filePath, {
    Duration? initialPosition,
  }) async =>
      _playbackService.startPlaying(filePath, initialPosition: initialPosition);

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Future<bool> stopPlaying() async => _playbackService.stopPlaying();

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Future<bool> pausePlaying() async => _playbackService.pausePlaying();

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Future<bool> resumePlaying() async => _playbackService.resumePlaying();

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Future<bool> seekTo(Duration position) async =>
      _playbackService.seekTo(position);

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Future<bool> setPlaybackSpeed(double speed) async =>
      _playbackService.setPlaybackSpeed(speed);

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Future<bool> setVolume(double volume) async =>
      _playbackService.setVolume(volume);

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Future<bool> isPlaying() async => _playbackService.isPlaying();

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Future<bool> isPlaybackPaused() async => _playbackService.isPlaybackPaused();

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Future<Duration> getCurrentPlaybackPosition() async =>
      _playbackService.getCurrentPlaybackPosition();

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Future<Duration> getCurrentPlaybackDuration() async =>
      _playbackService.getCurrentPlaybackDuration();

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Stream<Duration> getPlaybackPositionStream() =>
      _playbackService.getPlaybackPositionStream();

  @override
  @Deprecated('Use RecordingPlaybackCoordinator')
  Stream<void> getPlaybackCompletionStream() =>
      _playbackService.getPlaybackCompletionStream();

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
  }) => _recordingService.convertAudioFile(
    inputPath: inputPath,
    outputPath: outputPath,
    targetFormat: targetFormat,
  );

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
  Future<List<double>> getWaveformData(
    String filePath, {
    int sampleCount = 100,
  }) => _recordingService.getWaveformData(filePath, sampleCount: sampleCount);

  @override
  Future<Duration> getAudioDuration(String filePath) =>
      _recordingService.getAudioDuration(filePath);

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
  Future<List<int>> getSupportedSampleRates(AudioFormat format) async => [];

  @override
  Future<bool> setAudioSessionCategory(dynamic category) =>
      _playbackService.setAudioSessionCategory(category);

  @override
  Future<bool> enableBackgroundRecording() =>
      _recordingService.enableBackgroundRecording();

  @override
  Future<bool> disableBackgroundRecording() =>
      _recordingService.disableBackgroundRecording();
}
