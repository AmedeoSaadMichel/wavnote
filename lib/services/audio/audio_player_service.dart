// File: services/audio/audio_player_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/repositories/i_audio_service_repository.dart';
import '../../domain/entities/recording_entity.dart';
import '../../core/enums/audio_format.dart';
import 'audio_state_manager.dart';
import 'audio_cache_manager.dart';

/// Service for handling audio playback using just_audio.
///
/// Focused specifically on playback operations while implementing the full
/// IAudioServiceRepository interface for compatibility.
/// Stripped of UI logic and caching (now handled by AudioCacheManager and Presentation layer).
class AudioPlayerService implements IAudioServiceRepository {
  // Singleton instance
  static AudioPlayerService? _instance;
  static AudioPlayerService get instance =>
      _instance ??= AudioPlayerService._internal();

  AudioPlayerService._internal() {
    _cacheManager = AudioCacheManager();
  }

  // Core audio player
  AudioPlayer? _audioPlayer;

  // Cache manager
  late final AudioCacheManager _cacheManager;

  // Service state
  bool _isServiceInitialized = false;
  String? _currentlyPlayingFile;

  // Expansion state (UI convenience — used by presentation layer)
  String? _expandedRecordingId;
  bool _isLoading = false;
  bool _hasCompletedCurrentPlayback = false;
  AudioStateManager? _audioStateManager;
  VoidCallback? _onExpansionChanged;

  // Playback state
  bool _playbackActive = false;
  bool _playbackPaused = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  double _playbackVolume = 1.0;

  // Stream management
  StreamController<Duration>? _positionStreamController;
  StreamController<void>? _completionStreamController;
  StreamController<double>? _amplitudeStreamController;

  // Subscriptions
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _uiPositionSubscription;
  StreamSubscription<void>? _uiCompletionSubscription;

  // Amplitude simulation
  Timer? _amplitudeSimulationTimer;

  // ==== SERVICE LIFECYCLE ====

  @override
  bool get needsDisposal => true;

  /// Initialize audio player
  @override
  Future<bool> initialize() async {
    try {
      debugPrint(
        '🔧 AUDIO_SVC: Initialize called, isInitialized: $_isServiceInitialized',
      );

      if (_isServiceInitialized) return true;

      // Create new audio player instance
      _audioPlayer = AudioPlayer();

      // Initialize stream controllers
      _positionStreamController = StreamController<Duration>.broadcast();
      _completionStreamController = StreamController<void>.broadcast();
      _amplitudeStreamController = StreamController<double>.broadcast();

      // Setup audio player listeners
      await _initializePlayerListeners();

      _isServiceInitialized = true;
      debugPrint('✅ Audio player service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Audio player service initialization failed: $e');
      _isServiceInitialized = false;
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    debugPrint('🛑 Disposing audio player service...');

    // Stop playback if active
    if (_playbackActive) {
      try {
        await stopPlaying();
      } catch (e) {
        debugPrint('⚠️ Error stopping playback during dispose: $e');
      }
    }

    _stopAmplitudeSimulation();

    await _uiPositionSubscription?.cancel();
    await _uiCompletionSubscription?.cancel();
    _uiPositionSubscription = null;
    _uiCompletionSubscription = null;

    // Close stream controllers
    await _positionStreamController?.close();
    await _completionStreamController?.close();
    await _amplitudeStreamController?.close();

    _positionStreamController = null;
    _completionStreamController = null;
    _amplitudeStreamController = null;

    // Cancel subscriptions
    await _positionSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _uiPositionSubscription?.cancel();
    await _uiCompletionSubscription?.cancel();

    _positionSubscription = null;
    _stateSubscription = null;
    _durationSubscription = null;
    _uiPositionSubscription = null;
    _uiCompletionSubscription = null;

    // Dispose audio player
    try {
      await _audioPlayer?.dispose();
    } catch (e) {
      debugPrint('⚠️ Error disposing audio player: $e');
    } finally {
      _audioPlayer = null;
    }

    _cacheManager.dispose();

    _isServiceInitialized = false;
    _playbackActive = false;
    _playbackPaused = false;
    _currentlyPlayingFile = null;
    _playbackPosition = Duration.zero;
    _playbackDuration = Duration.zero;

    debugPrint('✅ Audio player service disposed successfully');
  }

  /// Initialize audio player event listeners
  Future<void> _initializePlayerListeners() async {
    if (_audioPlayer == null) return;

    try {
      _positionSubscription = _audioPlayer!.positionStream.listen((position) {
        _playbackPosition = position;
        _positionStreamController?.add(position);
      }, onError: (error) => debugPrint('❌ Position stream error: $error'));

      _durationSubscription = _audioPlayer!.durationStream.listen((duration) {
        if (duration != null && duration > Duration.zero) {
          _playbackDuration = duration;
        }
      }, onError: (error) => debugPrint('❌ Duration stream error: $error'));

      _stateSubscription = _audioPlayer!.playerStateStream.listen((state) {
        _playbackActive = state.playing;
        _playbackPaused =
            !state.playing &&
            state.processingState != ProcessingState.completed &&
            state.processingState != ProcessingState.idle;

        // Handle natural completion
        if (state.processingState == ProcessingState.completed) {
          debugPrint('🔚 Audio completed naturally');
          _playbackActive = false;
          _playbackPaused = false;
          _hasCompletedCurrentPlayback = true;
          _playbackPosition = Duration.zero;
          _completionStreamController?.add(null);
          _onExpansionChanged?.call();
        }
      }, onError: (error) => debugPrint('❌ Player state error: $error'));
    } catch (e) {
      debugPrint('❌ Error setting up player listeners: $e');
    }
  }

  // ==== PLAYBACK OPERATIONS ====

  @override
  Future<bool> startPlaying(
    String filePath, {
    Duration? initialPosition,
  }) async {
    if (!_ensureInitialized()) return false;

    try {
      debugPrint(
        '🎵 AudioPlayerService: Starting playback for $filePath'
        '${initialPosition != null ? ' from ${initialPosition.inMilliseconds}ms' : ''}',
      );

      // Validate file
      if (!await _validateAudioFile(filePath)) {
        debugPrint('❌ Invalid audio file: $filePath');
        return false;
      }

      // Stop current playback if any
      if (_playbackActive || _currentlyPlayingFile != filePath) {
        await stopPlaying();
      }

      // Check if source is already cached
      AudioSource? audioSource = _cacheManager.getCachedSource(filePath);

      if (audioSource != null) {
        debugPrint('✅ Using cached audio source for $filePath');
        await _audioPlayer!.setAudioSource(
          audioSource,
          initialPosition: initialPosition,
        );
      } else {
        debugPrint('🔄 Loading and caching new audio source for $filePath');
        audioSource = AudioSource.file(filePath);
        await _audioPlayer!.setAudioSource(
          audioSource,
          initialPosition: initialPosition,
        );
        _cacheManager.cacheSource(filePath, audioSource);
      }

      await _audioPlayer!.setSpeed(_playbackSpeed);
      await _audioPlayer!.setVolume(_playbackVolume);

      _currentlyPlayingFile = filePath;
      _playbackActive = true;
      _playbackPaused = false;

      // Start actual playback
      await _audioPlayer!.play();

      // Start amplitude simulation for visualizations
      _startAmplitudeSimulation();

      return true;
    } catch (e) {
      debugPrint('❌ Failed to start playing: $e');
      _playbackActive = false;
      _currentlyPlayingFile = null;
      return false;
    }
  }

  @override
  Future<bool> stopPlaying() async {
    if (!_ensureInitialized()) return false;

    try {
      debugPrint('🛑 Stopping playback...');
      await _audioPlayer!.stop();

      _stopAmplitudeSimulation();

      _playbackActive = false;
      _playbackPaused = false;
      _currentlyPlayingFile = null;

      // Reset position to beginning
      await _audioPlayer!.seek(Duration.zero);
      _playbackPosition = Duration.zero;

      debugPrint('✅ Playback stopped successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to stop playing: $e');
      return false;
    }
  }

  @override
  Future<bool> pausePlaying() async {
    if (!_ensureInitialized()) return false;
    if (!_playbackActive || _playbackPaused) return true;

    try {
      await _audioPlayer!.pause();
      _playbackPaused = true;
      _stopAmplitudeSimulation();
      return true;
    } catch (e) {
      debugPrint('❌ Failed to pause: $e');
      return false;
    }
  }

  @override
  Future<bool> resumePlaying() async {
    if (!_ensureInitialized()) return false;
    if (!_playbackPaused) return true;

    try {
      await _audioPlayer!.play();
      _playbackPaused = false;
      _playbackActive = true;
      _startAmplitudeSimulation();
      return true;
    } catch (e) {
      debugPrint('❌ Failed to resume: $e');
      return false;
    }
  }

  @override
  Future<bool> seekTo(Duration position) async {
    if (!_ensureInitialized()) return false;

    try {
      // Enforce bounds
      if (position < Duration.zero) {
        position = Duration.zero;
      } else if (_playbackDuration > Duration.zero &&
          position > _playbackDuration) {
        position = _playbackDuration;
      }

      await _audioPlayer!.seek(position);
      _playbackPosition = position;
      debugPrint('🎵 Seeked to: $position');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to seek: $e');
      return false;
    }
  }

  Future<bool> seekToWithRecordingDuration(
    Duration position,
    Duration recordingDuration,
  ) async {
    if (!_ensureInitialized()) return false;

    try {
      final maxDuration = recordingDuration.inMilliseconds;
      if (position < Duration.zero) {
        position = Duration.zero;
      } else if (maxDuration > 0 && position.inMilliseconds > maxDuration) {
        position = Duration(milliseconds: maxDuration);
      }

      await _audioPlayer!.seek(position);
      _playbackPosition = position;
      debugPrint('🎵 Seeked to: $position using recording duration limit');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to seek: $e');
      return false;
    }
  }

  @override
  Future<bool> setPlaybackSpeed(double speed) async {
    if (!_ensureInitialized()) return false;
    try {
      final validSpeed = speed.clamp(0.5, 2.0);
      await _audioPlayer!.setSpeed(validSpeed);
      _playbackSpeed = validSpeed;
      return true;
    } catch (e) {
      debugPrint('❌ Failed to set speed: $e');
      return false;
    }
  }

  @override
  Future<bool> setVolume(double volume) async {
    if (!_ensureInitialized()) return false;
    try {
      final validVolume = volume.clamp(0.0, 1.0);
      await _audioPlayer!.setVolume(validVolume);
      _playbackVolume = validVolume;
      return true;
    } catch (e) {
      debugPrint('❌ Failed to set volume: $e');
      return false;
    }
  }

  // ==== CACHE DELEGATION ====

  Future<bool> preloadAudioSource(String filePath) async {
    if (!_ensureInitialized()) return false;
    return await _cacheManager.preloadAudioSource(filePath);
  }

  void clearCache() {
    _cacheManager.clearCache();
  }

  Map<String, dynamic> getCacheStats() {
    return _cacheManager.getCacheStats();
  }

  // ==== PRIVATE HELPERS ====

  bool _ensureInitialized() {
    if (!_isServiceInitialized || _audioPlayer == null) {
      debugPrint('⚠️ AudioPlayerService not initialized');
      return false;
    }
    return true;
  }

  Future<bool> _validateAudioFile(String path) async {
    try {
      if (path.isEmpty) return false;
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('❌ Audio file does not exist: $path');
        return false;
      }
      final size = await file.length();
      if (size == 0) {
        debugPrint('❌ Audio file is empty: $path');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error validating audio file: $e');
      return false;
    }
  }

  /// Simulate amplitude for waveforms during playback
  void _startAmplitudeSimulation() {
    _amplitudeSimulationTimer?.cancel();
    _amplitudeSimulationTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) {
        if (!_playbackActive || _playbackPaused) {
          _amplitudeStreamController?.add(0.0);
          return;
        }

        final random = math.Random();
        final baseAmplitude = 0.2 + (random.nextDouble() * 0.6);
        final variation = (random.nextDouble() - 0.5) * 0.2;
        final amplitude = (baseAmplitude + variation).clamp(0.0, 1.0);

        _amplitudeStreamController?.add(amplitude);
      },
    );
  }

  /// Stop amplitude simulation
  void _stopAmplitudeSimulation() {
    _amplitudeSimulationTimer?.cancel();
    _amplitudeSimulationTimer = null;
    _amplitudeStreamController?.add(0.0);
  }

  // ==== PUBLIC GETTERS ====

  @override
  Future<bool> isPlaying() async => _playbackActive && !_playbackPaused;

  @override
  Future<bool> isPlaybackPaused() async => _playbackPaused;

  @override
  Future<Duration> getCurrentPlaybackPosition() async => _playbackPosition;

  @override
  Future<Duration> getCurrentPlaybackDuration() async => _playbackDuration;

  @override
  Stream<Duration> getPlaybackPositionStream() =>
      _positionStreamController?.stream ?? const Stream.empty();

  @override
  Stream<void> getPlaybackCompletionStream() =>
      _completionStreamController?.stream ?? const Stream.empty();

  /// Currently playing file path
  String? get currentFile => _currentlyPlayingFile;

  /// Service initialization status
  bool get isServiceReady => _isServiceInitialized;

  /// Audio player instance (for direct access if needed)
  AudioPlayer? get audioPlayer => _audioPlayer;

  /// Current playback speed
  double get playbackSpeed => _playbackSpeed;

  // ==== EXPANSION / UI CONVENIENCE API ====
  // Used by recording_list_logic.dart and recording_list_screen.dart

  /// Get the expanded recording ID
  String? get expandedRecordingId => _expandedRecordingId;

  /// Whether a recording is currently loading
  bool get isLoading => _isLoading;

  /// Whether audio is actively playing (sync getter for UI)
  bool get isCurrentlyPlaying => _playbackActive && !_playbackPaused;

  /// Current position (sync getter for UI)
  Duration get position => _playbackPosition;

  /// Current duration (sync getter for UI)
  Duration get duration => _playbackDuration;

  /// AudioStateManager for optimized UI updates
  AudioStateManager? get audioState => _audioStateManager;

  /// Set callback for expansion state changes
  void setExpansionCallback(VoidCallback? callback) {
    final previousCallback = _onExpansionChanged;
    _onExpansionChanged = callback;
    _audioStateManager ??= AudioStateManager();
    if (previousCallback != null) {
      _audioStateManager!.removeListener(previousCallback);
    }
    if (callback != null) {
      _audioStateManager!.addListener(callback);
    }
  }

  /// Get the currently expanded recording from a list
  RecordingEntity? getCurrentlyExpandedRecording(
    List<RecordingEntity> recordings,
  ) {
    if (_expandedRecordingId == null) return null;
    try {
      return recordings.firstWhere((r) => r.id == _expandedRecordingId);
    } catch (_) {
      return null;
    }
  }

  /// Reset expansion state
  void resetExpansionState() {
    _uiPositionSubscription?.cancel();
    _uiCompletionSubscription?.cancel();
    _uiPositionSubscription = null;
    _uiCompletionSubscription = null;
    _expandedRecordingId = null;
    _isLoading = false;
    _hasCompletedCurrentPlayback = false;
    _audioStateManager?.reset();
    _onExpansionChanged?.call();
  }

  /// Expand a recording (load and optionally play)
  Future<void> expandRecording(RecordingEntity recording) async {
    // If same recording, toggle collapse
    if (_expandedRecordingId == recording.id) {
      await stopPlaying();
      resetExpansionState();
      return;
    }

    // Stop current playback
    if (_playbackActive) {
      await stopPlaying();
    }

    _isLoading = true;
    _expandedRecordingId = recording.id;
    _hasCompletedCurrentPlayback = false;
    _audioStateManager?.updateExpandedRecording(recording.id);
    _onExpansionChanged?.call();

    try {} catch (e) {
      _isLoading = false;
      debugPrint('❌ Error expanding recording: $e');
      _onExpansionChanged?.call();
      rethrow;
    }
  }

  /// Toggle play/pause for current recording
  Future<void> togglePlayback() async {
    if (_expandedRecordingId == null) return;

    if (_playbackActive && !_playbackPaused) {
      await pausePlaying();
      _audioStateManager?.updatePlaybackState(isPlaying: false);
    } else if (_playbackPaused) {
      await resumePlaying();
      _audioStateManager?.updatePlaybackState(isPlaying: true);
    } else if (_hasCompletedCurrentPlayback && _currentlyPlayingFile != null) {
      // Restart from beginning after completion (non dipendere da _playbackPaused)
      await seekTo(Duration.zero);
      try {
        await _audioPlayer?.play();
        _playbackActive = true;
        _playbackPaused = false;
        _startAmplitudeSimulation();
      } catch (e) {
        debugPrint('❌ Failed to restart playback: $e');
      }
      _hasCompletedCurrentPlayback = false;
      _audioStateManager?.updatePlaybackState(isPlaying: true);
    }
    _onExpansionChanged?.call();
  }

  /// Seek to a percentage position (0.0 - 1.0)
  void seekToPosition(double percent) {
    if (_playbackDuration.inMilliseconds == 0) return;
    final position = Duration(
      milliseconds: (_playbackDuration.inMilliseconds * percent).round(),
    );
    seekTo(position);
    _audioStateManager?.updatePosition(position);
  }

  /// Skip backward by 10 seconds
  void skipBackward() {
    final newPosition = _playbackPosition - const Duration(seconds: 10);
    final clamped = newPosition < Duration.zero ? Duration.zero : newPosition;
    seekTo(clamped);
    _audioStateManager?.updatePosition(clamped);
  }

  /// Skip forward by 10 seconds
  void skipForward() {
    final newPosition = _playbackPosition + const Duration(seconds: 10);
    final clamped = newPosition > _playbackDuration
        ? _playbackDuration
        : newPosition;
    seekTo(clamped);
    _audioStateManager?.updatePosition(clamped);
  }

  // ==== STUBS FOR RECORDING (IAudioServiceRepository) ====
  @override
  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
  }) async => false;

  @override
  Future<RecordingEntity?> stopRecording({bool raw = false}) async => null;

  @override
  Future<bool> pauseRecording() async => false;

  @override
  Future<bool> resumeRecording() async => false;

  @override
  Future<bool> cancelRecording() async => false;

  @override
  Future<bool> isRecording() async => false;

  @override
  Future<bool> isRecordingPaused() async => false;

  @override
  Future<Duration> getCurrentRecordingDuration() async => Duration.zero;

  @override
  Stream<double> getRecordingAmplitudeStream() => const Stream.empty();

  @override
  Stream<double>? get amplitudeStream => null;

  @override
  Stream<Duration>? get durationStream => null;

  @override
  Future<double> getCurrentAmplitude() async => 0.0;

  @override
  Future<AudioFileInfo?> getAudioFileInfo(String filePath) async => null;

  @override
  Future<String?> convertAudioFile({
    required String inputPath,
    required String outputPath,
    required AudioFormat targetFormat,
    int? targetSampleRate,
    int? targetBitRate,
  }) async => null;

  @override
  Future<String?> trimAudioFile({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
  }) async => null;

  @override
  Future<String?> mergeAudioFiles({
    required List<String> inputPaths,
    required String outputPath,
    required AudioFormat outputFormat,
  }) async => null;

  @override
  Future<List<double>> getWaveformData(
    String filePath, {
    int sampleCount = 100,
  }) async => [];

  @override
  Future<Duration> getAudioDuration(String filePath) async {
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(filePath);
      return duration ?? Duration.zero;
    } catch (e) {
      return Duration.zero;
    } finally {
      player.dispose();
    }
  }

  @override
  Future<bool> hasMicrophonePermission() async => false;

  @override
  Future<bool> requestMicrophonePermission() async => false;

  @override
  Future<bool> hasMicrophone() async => false;

  @override
  Future<List<AudioInputDevice>> getAudioInputDevices() async => [];

  @override
  Future<bool> setAudioInputDevice(String deviceId) async => false;

  @override
  Future<List<AudioFormat>> getSupportedFormats() async => [];

  @override
  Future<List<int>> getSupportedSampleRates(AudioFormat format) async => [];

  @override
  Future<bool> setAudioSessionCategory(dynamic category) async => false;

  @override
  Future<bool> enableBackgroundRecording() async => false;

  @override
  Future<bool> disableBackgroundRecording() async => false;
}
