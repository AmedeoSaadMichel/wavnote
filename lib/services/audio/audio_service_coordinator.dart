// File: services/audio/audio_service_coordinator.dart
// 
// Audio Service Coordinator - Service Layer
// ========================================
//
// Central coordinator for all audio operations in the WavNote app. This service
// implements the Coordinator pattern to manage complex interactions between
// recording and playback services while providing a unified interface.
//
// Architecture Pattern:
// - Implements IAudioServiceRepository interface (Clean Architecture)
// - Coordinates specialized services without tight coupling
// - Manages service lifecycle and resource allocation
// - Provides unified event streams for the presentation layer
//
// Key Responsibilities:
// - Initialize and manage AudioRecorderService and AudioPlayerService
// - Coordinate between recording and playback operations
// - Unify event streams (amplitude, position, completion) 
// - Handle service state transitions and conflicts
// - Manage resource cleanup and disposal
//
// Service Coordination Rules:
// - Only one service can be active at a time (recording OR playback)
// - Automatic cleanup when switching between services
// - Unified error handling and state management
// - Stream multiplexing for consistent event delivery
//
// Performance Features:
// - Lazy initialization of stream controllers
// - Efficient subscription management
// - Memory leak prevention through proper disposal
// - Resource pooling for optimal memory usage

import 'dart:async';
import 'package:flutter/foundation.dart';

// Domain imports
import '../../domain/entities/recording_entity.dart';       // Recording business entity
import '../../domain/repositories/i_audio_service_repository.dart'; // Audio service interface
import '../../core/enums/audio_format.dart';                // Audio format definitions

// Specialized service imports
import 'audio_recorder_service.dart';  // Handles audio recording operations
import 'audio_player_service.dart';    // Handles audio playback operations

/// Audio service coordinator that manages both recording and playback
///
/// Coordinates between specialized recording and playback services
/// while implementing the full IAudioServiceRepository interface.
/// Provides a unified interface for all audio operations.
///
/// Example usage:
/// ```dart
/// final coordinator = AudioServiceCoordinator();
/// await coordinator.initialize();
/// 
/// // Start recording
/// await coordinator.startRecording('/path/to/file.m4a');
/// 
/// // Later, stop recording and play it back
/// await coordinator.stopRecording();
/// await coordinator.startPlayback('/path/to/file.m4a');
/// ```
class AudioServiceCoordinator implements IAudioServiceRepository {

  // Specialized services
  late final AudioRecorderService _recordingService;
  late final AudioPlayerService _playbackService;

  // Active service state
  IAudioServiceRepository? _activeRecorder;
  IAudioServiceRepository? _activePlayer;

  // Service state
  bool _isInitialized = false;

  // Stream controllers for unified streams
  StreamController<double>? _amplitudeController;
  StreamController<Duration>? _positionController;
  StreamController<void>? _completionController;

  // Stream subscriptions
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
    try {
      // Initialize stream controllers
      _amplitudeController = StreamController<double>.broadcast();
      _positionController = StreamController<Duration>.broadcast();
      _completionController = StreamController<void>.broadcast();

      // Initialize both services
      final recordingInit = await _recordingService.initialize();
      final playbackInit = await _playbackService.initialize();

      if (recordingInit && playbackInit) {
        _isInitialized = true;
        debugPrint('✅ Audio service coordinator initialized');
        return true;
      } else {
        debugPrint('❌ Failed to initialize audio services');
        return false;
      }

    } catch (e) {
      debugPrint('❌ Failed to initialize audio service coordinator: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      // Cancel subscriptions
      await _recordingAmplitudeSubscription?.cancel();
      await _recordingPositionSubscription?.cancel();
      await _recordingCompletionSubscription?.cancel();
      await _playbackPositionSubscription?.cancel();
      await _playbackCompletionSubscription?.cancel();

      // Dispose services
      await _recordingService.dispose();
      await _playbackService.dispose();

      // Close stream controllers
      await _amplitudeController?.close();
      await _positionController?.close();
      await _completionController?.close();

      _isInitialized = false;
      debugPrint('✅ Audio service coordinator disposed');

    } catch (e) {
      debugPrint('❌ Error disposing audio service coordinator: $e');
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
    if (!_isInitialized) {
      debugPrint('❌ Audio service coordinator not initialized');
      return false;
    }

    // Stop any active playback
    if (await _playbackService.isPlaying()) {
      await _playbackService.stopPlaying();
    }

    // Start recording
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
    if (_activeRecorder == null) {
      return null;
    }

    final result = await _activeRecorder!.stopRecording();
    _activeRecorder = null;
    _cleanupRecordingStreams();

    return result;
  }

  @override
  Future<bool> pauseRecording() async {
    if (_activeRecorder == null) {
      return false;
    }
    return await _activeRecorder!.pauseRecording();
  }

  @override
  Future<bool> resumeRecording() async {
    if (_activeRecorder == null) {
      return false;
    }
    return await _activeRecorder!.resumeRecording();
  }

  @override
  Future<bool> cancelRecording() async {
    if (_activeRecorder == null) {
      return false;
    }
    return await _activeRecorder!.cancelRecording();
  }

  @override
  Future<bool> isRecording() async {
    if (_activeRecorder == null) {
      return false;
    }
    return await _activeRecorder!.isRecording();
  }

  @override
  Future<bool> isRecordingPaused() async {
    if (_activeRecorder == null) {
      return false;
    }
    return await _activeRecorder!.isRecordingPaused();
  }

  @override
  Future<Duration> getCurrentRecordingDuration() async {
    if (_activeRecorder == null) {
      return Duration.zero;
    }
    return await _activeRecorder!.getCurrentRecordingDuration();
  }

  @override
  Stream<double> getRecordingAmplitudeStream() {
    return _amplitudeController?.stream ?? const Stream.empty();
  }

  @override
  Stream<double>? get amplitudeStream => _amplitudeController?.stream;

  @override
  Stream<Duration>? get durationStream => _positionController?.stream;

  // ==== PLAYBACK OPERATIONS ====

// FIXED: AudioServiceCoordinator startPlaying method

  @override
  Future<bool> startPlaying(String filePath) async {
    try {
      debugPrint('🎵 AudioServiceCoordinator: Starting playback for $filePath');

      // Ensure initialization
      if (!_isInitialized) {
        debugPrint('🔄 AudioServiceCoordinator: Auto-initializing...');
        final initSuccess = await initialize();
        if (!initSuccess) {
          debugPrint('❌ AudioServiceCoordinator: Auto-initialization failed');
          return false;
        }
      }

      // Ensure playback service is ready (avoid redundant initialization)
      if (!_playbackService.isServiceReady) {
        debugPrint('🔄 AudioServiceCoordinator: Initializing playback service...');
        final playbackInit = await _playbackService.initialize();
        if (!playbackInit) {
          debugPrint('❌ AudioServiceCoordinator: Failed to initialize playback service');
          return false;
        }
      } else {
        debugPrint('✅ AudioServiceCoordinator: Playback service already ready');
      }

      // Stop any active recording
      if (await _recordingService.isRecording()) {
        debugPrint('🛑 AudioServiceCoordinator: Stopping active recording');
        await _recordingService.stopRecording();
      }

      // Start playback through the specialized service
      final success = await _playbackService.startPlaying(filePath);

      if (success) {
        _activePlayer = _playbackService;
        _setupPlaybackStreams();
        debugPrint('✅ AudioServiceCoordinator: Playback started successfully');
      } else {
        debugPrint('❌ AudioServiceCoordinator: Playback failed');
      }

      return success;

    } catch (e) {
      debugPrint('❌ AudioServiceCoordinator: Error starting playback: $e');
      return false;
    }
  }

  @override
  Future<bool> stopPlaying() async {
    if (_activePlayer == null) {
      return false;
    }

    final result = await _activePlayer!.stopPlaying();
    _activePlayer = null;
    _cleanupPlaybackStreams();

    return result;
  }

  @override
  Future<bool> pausePlaying() async {
    if (_activePlayer == null) {
      return false;
    }
    return await _activePlayer!.pausePlaying();
  }

  @override
  Future<bool> resumePlaying() async {
    if (_activePlayer == null) {
      return false;
    }
    return await _activePlayer!.resumePlaying();
  }

  @override
  Future<bool> seekTo(Duration position) async {
    if (_activePlayer == null) {
      return false;
    }
    return await _activePlayer!.seekTo(position);
  }

  /// Seek to position with recording duration validation
  Future<bool> seekToWithRecordingDuration(Duration position, Duration recordingDuration) async {
    if (_activePlayer == null) {
      return false;
    }
    
    // Validate against recording duration instead of player duration
    if (position.isNegative || position > recordingDuration) {
      debugPrint('❌ Invalid seek position: $position (max: $recordingDuration)');
      return false;
    }
    
    return await (_activePlayer as AudioPlayerService).seekToWithRecordingDuration(position, recordingDuration);
  }

  /// Preload an audio source for faster playback
  Future<bool> preloadAudioSource(String filePath) async {
    if (!_isInitialized) {
      debugPrint('❌ Audio service coordinator not initialized');
      return false;
    }

    // Ensure playback service is ready
    if (!_playbackService.isServiceReady) {
      final playbackInit = await _playbackService.initialize();
      if (!playbackInit) {
        debugPrint('❌ Failed to initialize playback service for preload');
        return false;
      }
    }

    return await _playbackService.preloadAudioSource(filePath);
  }

  /// Clear the audio source cache
  void clearAudioCache() {
    _playbackService.clearCache();
  }

  /// Get cache statistics
  Map<String, dynamic> getAudioCacheStats() {
    return _playbackService.getCacheStats();
  }

  @override
  Future<bool> setPlaybackSpeed(double speed) async {
    if (_activePlayer == null) {
      return false;
    }
    return await _activePlayer!.setPlaybackSpeed(speed);
  }

  @override
  Future<bool> setVolume(double volume) async {
    if (_activePlayer == null) {
      return false;
    }
    return await _activePlayer!.setVolume(volume);
  }

  @override
  Future<bool> isPlaying() async {
    if (_activePlayer == null) {
      return false;
    }
    return await _activePlayer!.isPlaying();
  }

  @override
  Future<bool> isPlaybackPaused() async {
    if (_activePlayer == null) {
      return false;
    }
    return await _activePlayer!.isPlaybackPaused();
  }

  @override
  Future<Duration> getCurrentPlaybackPosition() async {
    if (_activePlayer == null) {
      return Duration.zero;
    }
    return await _activePlayer!.getCurrentPlaybackPosition();
  }

  @override
  Future<Duration> getCurrentPlaybackDuration() async {
    if (_activePlayer == null) {
      return Duration.zero;
    }
    return await _activePlayer!.getCurrentPlaybackDuration();
  }

  @override
  Stream<Duration> getPlaybackPositionStream() {
    return _positionController?.stream ?? const Stream.empty();
  }

  @override
  Stream<void> getPlaybackCompletionStream() {
    return _completionController?.stream ?? const Stream.empty();
  }

  // ==== AUDIO FILE OPERATIONS ====

  @override
  Future<AudioFileInfo?> getAudioFileInfo(String filePath) async {
    // Delegate to recording service for file analysis
    return await _recordingService.getAudioFileInfo(filePath);
  }

  @override
  Future<String?> convertAudioFile({
    required String inputPath,
    required String outputPath,
    required AudioFormat targetFormat,
    int? targetSampleRate,
    int? targetBitRate,
  }) async {
    // Delegate to recording service for file conversion
    return await _recordingService.convertAudioFile(
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
  }) async {
    // Delegate to recording service for file trimming
    return await _recordingService.trimAudioFile(
      inputPath: inputPath,
      outputPath: outputPath,
      startTime: startTime,
      endTime: endTime,
    );
  }

  @override
  Future<String?> mergeAudioFiles({
    required List<String> inputPaths,
    required String outputPath,
    required AudioFormat outputFormat,
  }) async {
    // Delegate to recording service for file merging
    return await _recordingService.mergeAudioFiles(
      inputPaths: inputPaths,
      outputPath: outputPath,
      outputFormat: outputFormat,
    );
  }

  @override
  Future<List<double>> getWaveformData(String filePath, {int sampleCount = 100}) async {
    // Delegate to recording service for waveform data
    return await _recordingService.getWaveformData(filePath, sampleCount: sampleCount);
  }

  // ==== DEVICE & PERMISSIONS ====

  @override
  Future<bool> hasMicrophonePermission() async {
    return await _recordingService.hasMicrophonePermission();
  }

  @override
  Future<bool> requestMicrophonePermission() async {
    return await _recordingService.requestMicrophonePermission();
  }

  @override
  Future<bool> hasMicrophone() async {
    return await _recordingService.hasMicrophone();
  }

  @override
  Future<List<AudioInputDevice>> getAudioInputDevices() async {
    return await _recordingService.getAudioInputDevices();
  }

  @override
  Future<bool> setAudioInputDevice(String deviceId) async {
    return await _recordingService.setAudioInputDevice(deviceId);
  }

  @override
  Future<List<AudioFormat>> getSupportedFormats() async {
    return await _recordingService.getSupportedFormats();
  }

  @override
  Future<List<int>> getSupportedSampleRates(AudioFormat format) async {
    return await _recordingService.getSupportedSampleRates(format);
  }

  // ==== SETTINGS & CONFIGURATION ====

  @override
  Future<bool> setAudioSessionCategory(AudioSessionCategory category) async {
    // Apply to both services
    final recordingResult = await _recordingService.setAudioSessionCategory(category);
    final playbackResult = await _playbackService.setAudioSessionCategory(category);
    return recordingResult && playbackResult;
  }

  @override
  Future<bool> enableBackgroundRecording() async {
    return await _recordingService.enableBackgroundRecording();
  }

  @override
  Future<bool> disableBackgroundRecording() async {
    return await _recordingService.disableBackgroundRecording();
  }

  // ==== PRIVATE HELPER METHODS ====

  /// Setup recording stream subscriptions
  void _setupRecordingStreams() {
    _recordingAmplitudeSubscription = _recordingService.getRecordingAmplitudeStream().listen(
          (amplitude) => _amplitudeController?.add(amplitude),
    );

    _recordingPositionSubscription = _recordingService.getPlaybackPositionStream().listen(
          (position) => _positionController?.add(position),
    );

    _recordingCompletionSubscription = _recordingService.getPlaybackCompletionStream().listen(
          (_) => _completionController?.add(null),
    );
  }

  /// Cleanup recording stream subscriptions
  void _cleanupRecordingStreams() {
    _recordingAmplitudeSubscription?.cancel();
    _recordingPositionSubscription?.cancel();
    _recordingCompletionSubscription?.cancel();

    _recordingAmplitudeSubscription = null;
    _recordingPositionSubscription = null;
    _recordingCompletionSubscription = null;
  }

  /// Setup playback stream subscriptions
  void _setupPlaybackStreams() {
    _playbackPositionSubscription = _playbackService.getPlaybackPositionStream().listen(
          (position) => _positionController?.add(position),
    );

    _playbackCompletionSubscription = _playbackService.getPlaybackCompletionStream().listen(
          (_) => _completionController?.add(null),
    );
  }

  /// Cleanup playback stream subscriptions
  void _cleanupPlaybackStreams() {
    _playbackPositionSubscription?.cancel();
    _playbackCompletionSubscription?.cancel();

    _playbackPositionSubscription = null;
    _playbackCompletionSubscription = null;
  }
}