// File: services/audio/audio_service_coordinator.dart
//
// Audio Service Coordinator - Service Layer
// ==========================================
//
// Central coordinator for all audio operations in WavNote.
// Coordinates between AudioRecorderService and AudioPlayerService,
// providing a single unified IAudioServiceRepository interface.
//
// Coordination rules:
// - Only one service active at a time (recording OR playback)
// - Idempotent initialize() guarded by _isInitialized flag
// - Streams unified and multiplexed for the presentation layer

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_audio_service_repository.dart';
import '../../core/enums/audio_format.dart';
import 'audio_recorder_service.dart';
import 'audio_player_service.dart';

/// Coordinator that delegates recording to [AudioRecorderService] and
/// playback to [AudioPlayerService], unifying their streams.
class AudioServiceCoordinator implements IAudioServiceRepository {
  late final AudioRecorderService _recordingService;
  late final AudioPlayerService _playbackService;

  IAudioServiceRepository? _activeRecorder;
  IAudioServiceRepository? _activePlayer;

  bool _isInitialized = false;

  StreamController<double>? _amplitudeController;
  StreamController<Duration>? _positionController;
  StreamController<void>? _completionController;

  StreamSubscription<double>? _recordingAmplitudeSubscription;
  StreamSubscription<Duration>? _recordingPositionSubscription;
  StreamSubscription<void>? _recordingCompletionSubscription;
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

      final recordingInit = await _recordingService.initialize();
      final playbackInit = await _playbackService.initialize();

      if (recordingInit && playbackInit) {
        _isInitialized = true;
        debugPrint('✅ AudioServiceCoordinator initialized');
        return true;
      }
      debugPrint('❌ Failed to initialize audio services');
      return false;
    } catch (e) {
      debugPrint('❌ Failed to initialize AudioServiceCoordinator: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _recordingAmplitudeSubscription?.cancel();
      await _recordingPositionSubscription?.cancel();
      await _recordingCompletionSubscription?.cancel();
      await _playbackPositionSubscription?.cancel();
      await _playbackCompletionSubscription?.cancel();

      await _recordingService.dispose();
      await _playbackService.dispose();

      await _amplitudeController?.close();
      await _positionController?.close();
      await _completionController?.close();

      _isInitialized = false;
      debugPrint('✅ AudioServiceCoordinator disposed');
    } catch (e) {
      debugPrint('❌ Error disposing AudioServiceCoordinator: $e');
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

    final success = await _recordingService.startRecording(
      filePath: filePath,
      format: format,
      sampleRate: sampleRate,
      bitRate: bitRate,
    );

    if (success) {
      _activeRecorder = _recordingService;
      _setupRecordingStreams();
    }
    return success;
  }

  @override
  Future<RecordingEntity?> stopRecording() async {
    if (_activeRecorder == null) return null;
    final result = await _activeRecorder!.stopRecording();
    _activeRecorder = null;
    _cleanupRecordingStreams();
    return result;
  }

  @override
  Future<bool> pauseRecording() async =>
      _activeRecorder == null ? false : await _activeRecorder!.pauseRecording();

  @override
  Future<bool> resumeRecording() async => _activeRecorder == null
      ? false
      : await _activeRecorder!.resumeRecording();

  @override
  Future<bool> cancelRecording() async => _activeRecorder == null
      ? false
      : await _activeRecorder!.cancelRecording();

  @override
  Future<bool> isRecording() async =>
      _activeRecorder == null ? false : await _activeRecorder!.isRecording();

  @override
  Future<bool> isRecordingPaused() async => _activeRecorder == null
      ? false
      : await _activeRecorder!.isRecordingPaused();

  @override
  Future<Duration> getCurrentRecordingDuration() async => _activeRecorder == null
      ? Duration.zero
      : await _activeRecorder!.getCurrentRecordingDuration();

  @override
  Stream<double> getRecordingAmplitudeStream() =>
      _amplitudeController?.stream ?? const Stream.empty();

  @override
  Stream<double>? get amplitudeStream => _amplitudeController?.stream;

  @override
  Stream<Duration>? get durationStream => _positionController?.stream;

  // ==== PLAYBACK OPERATIONS ====

  @override
  Future<bool> startPlaying(String filePath) async {
    try {
      if (!_isInitialized) {
        final ok = await initialize();
        if (!ok) return false;
      }

      if (!_playbackService.isServiceReady) {
        final ok = await _playbackService.initialize();
        if (!ok) return false;
      }

      if (await _recordingService.isRecording()) {
        await _recordingService.stopRecording();
      }

      final success = await _playbackService.startPlaying(filePath);
      if (success) {
        _activePlayer = _playbackService;
        _setupPlaybackStreams();
        debugPrint('✅ AudioServiceCoordinator: playback started');
      }
      return success;
    } catch (e) {
      debugPrint('❌ AudioServiceCoordinator: error starting playback: $e');
      return false;
    }
  }

  @override
  Future<bool> stopPlaying() async {
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

  /// Seek with validation against [recordingDuration] instead of player duration.
  Future<bool> seekToWithRecordingDuration(
      Duration position, Duration recordingDuration) async {
    if (_activePlayer == null) return false;
    if (position.isNegative || position > recordingDuration) {
      debugPrint('❌ Invalid seek position: $position (max: $recordingDuration)');
      return false;
    }
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
  Future<bool> isPlaying() async =>
      _activePlayer == null ? false : await _activePlayer!.isPlaying();

  @override
  Future<bool> isPlaybackPaused() async =>
      _activePlayer == null ? false : await _activePlayer!.isPlaybackPaused();

  @override
  Future<Duration> getCurrentPlaybackPosition() async =>
      _activePlayer == null
          ? Duration.zero
          : await _activePlayer!.getCurrentPlaybackPosition();

  @override
  Future<Duration> getCurrentPlaybackDuration() async =>
      _activePlayer == null
          ? Duration.zero
          : await _activePlayer!.getCurrentPlaybackDuration();

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
  }) => _recordingService.convertAudioFile(
        inputPath: inputPath,
        outputPath: outputPath,
        targetFormat: targetFormat,
        targetSampleRate: targetSampleRate,
        targetBitRate: targetBitRate,
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
  Future<List<double>> getWaveformData(String filePath,
      {int sampleCount = 100}) =>
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
    final r = await _recordingService.setAudioSessionCategory(category);
    final p = await _playbackService.setAudioSessionCategory(category);
    return r && p;
  }

  @override
  Future<bool> enableBackgroundRecording() =>
      _recordingService.enableBackgroundRecording();

  @override
  Future<bool> disableBackgroundRecording() =>
      _recordingService.disableBackgroundRecording();

  // ==== CACHE / PRELOAD ====

  /// Preload an audio source for faster first-play latency.
  Future<bool> preloadAudioSource(String filePath) async {
    if (!_isInitialized) return false;
    if (!_playbackService.isServiceReady) {
      final ok = await _playbackService.initialize();
      if (!ok) return false;
    }
    return await _playbackService.preloadAudioSource(filePath);
  }

  /// Clear the internal audio source cache.
  void clearAudioCache() => _playbackService.clearCache();

  /// Return cache hit/miss statistics.
  Map<String, dynamic> getAudioCacheStats() => _playbackService.getCacheStats();

  // ==== PRIVATE STREAM HELPERS ====

  void _setupRecordingStreams() {
    _recordingAmplitudeSubscription =
        _recordingService.getRecordingAmplitudeStream().listen(
              (amp) => _amplitudeController?.add(amp),
            );
    _recordingPositionSubscription =
        _recordingService.getPlaybackPositionStream().listen(
              (pos) => _positionController?.add(pos),
            );
    _recordingCompletionSubscription =
        _recordingService.getPlaybackCompletionStream().listen(
              (_) => _completionController?.add(null),
            );
  }

  void _cleanupRecordingStreams() {
    _recordingAmplitudeSubscription?.cancel();
    _recordingPositionSubscription?.cancel();
    _recordingCompletionSubscription?.cancel();
    _recordingAmplitudeSubscription = null;
    _recordingPositionSubscription = null;
    _recordingCompletionSubscription = null;
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
}
