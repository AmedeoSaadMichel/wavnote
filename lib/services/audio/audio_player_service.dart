// File: services/audio/audio_player_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/repositories/i_audio_service_repository.dart';
import '../../domain/entities/recording_entity.dart';
import '../../core/enums/audio_format.dart';

/// Audio playback service using just_audio
///
/// Provides complete audio playback functionality for the voice memo app.
/// Focused specifically on playback operations while implementing the full
/// IAudioServiceRepository interface for compatibility.
class AudioPlayerService implements IAudioServiceRepository {

  // Core audio player
  AudioPlayer? _audioPlayer;

  // Service state
  bool _isServiceInitialized = false;
  String? _currentlyPlayingFile;

  // Playback state
  bool _playbackActive = false;
  bool _playbackPaused = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  double _playbackVolume = 1.0;

  // LRU Cache for preloaded audio sources
  final Map<String, AudioSource> _preloadedSources = {};
  final List<String> _accessOrder = [];
  static const int _maxCacheSize = 5; // Keep 5 most recent sources

  // Stream management
  StreamController<Duration>? _positionStreamController;
  StreamController<void>? _completionStreamController;
  StreamController<double>? _amplitudeStreamController;

  // Subscriptions
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  // Amplitude simulation
  Timer? _amplitudeSimulationTimer;

  // ==== SERVICE LIFECYCLE ====

  @override
  Future<bool> initialize() async {
    try {
      // Clean up any existing instance
      if (_isServiceInitialized) {
        await dispose();
      }

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
      debugPrint('❌ Failed to initialize audio player service: $e');
      _isServiceInitialized = false;
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      // Stop any active playback
      if (_playbackActive) {
        await stopPlaying();
      }

      // Cancel all subscriptions
      await _positionSubscription?.cancel();
      await _stateSubscription?.cancel();
      await _durationSubscription?.cancel();
      _amplitudeSimulationTimer?.cancel();

      // Close stream controllers
      await _positionStreamController?.close();
      await _completionStreamController?.close();
      await _amplitudeStreamController?.close();

      // Dispose audio player
      await _audioPlayer?.dispose();

      // Clear cache
      _preloadedSources.clear();
      _accessOrder.clear();

      // Reset state
      _audioPlayer = null;
      _isServiceInitialized = false;
      _playbackActive = false;
      _playbackPaused = false;
      _currentlyPlayingFile = null;

      debugPrint('✅ Audio player service disposed');

    } catch (e) {
      debugPrint('❌ Error disposing audio player service: $e');
    }
  }

  /// Initialize audio player event listeners
  Future<void> _initializePlayerListeners() async {
    if (_audioPlayer == null) return;

    try {
      // Position tracking
      _positionSubscription = _audioPlayer!.positionStream.listen(
            (position) {
          _playbackPosition = position;
          _positionStreamController?.add(position);
        },
        onError: (error) => debugPrint('❌ Position stream error: $error'),
      );

      // State changes
      _stateSubscription = _audioPlayer!.playerStateStream.listen(
            (state) => _handlePlayerStateChange(state),
        onError: (error) => debugPrint('❌ Player state error: $error'),
      );

      // Duration updates
      _durationSubscription = _audioPlayer!.durationStream.listen(
            (duration) {
          if (duration != null) {
            _playbackDuration = duration;
          }
        },
        onError: (error) => debugPrint('❌ Duration stream error: $error'),
      );

    } catch (e) {
      debugPrint('❌ Error setting up player listeners: $e');
    }
  }

  /// Handle audio player state changes
  void _handlePlayerStateChange(PlayerState state) {
    switch (state.processingState) {
      case ProcessingState.completed:
        _playbackActive = false;
        _playbackPaused = false;
        _stopAmplitudeSimulation();
        _completionStreamController?.add(null);
        debugPrint('🎵 Playback completed');
        break;

      case ProcessingState.ready:
        if (state.playing) {
          _playbackActive = true;
          _playbackPaused = false;
          _startAmplitudeSimulation();
          debugPrint('🎵 Playback active');
        } else {
          _playbackActive = false;
          _playbackPaused = true;
          _stopAmplitudeSimulation();
          debugPrint('🎵 Playback paused');
        }
        break;

      case ProcessingState.idle:
        _playbackActive = false;
        _playbackPaused = false;
        _stopAmplitudeSimulation();
        break;

      case ProcessingState.loading:
      case ProcessingState.buffering:
      // Keep current state during loading
        break;
    }
  }

  // ==== PLAYBACK OPERATIONS ====

  @override
  Future<bool> startPlaying(String filePath) async {
    if (!_ensureInitialized()) return false;

    try {
      debugPrint('🎵 AudioPlayerService: Starting playback for $filePath');

      // Validate file
      if (!await _validateAudioFile(filePath)) {
        debugPrint('❌ Invalid audio file: $filePath');
        return false;
      }

      // Stop current playback if any
      if (_playbackActive) {
        await stopPlaying();
      }

      // Check if source is already cached
      AudioSource? audioSource = _getCachedSource(filePath);
      
      if (audioSource != null) {
        debugPrint('✅ Using cached audio source for $filePath');
        await _audioPlayer!.setAudioSource(audioSource);
      } else {
        debugPrint('🔄 Loading and caching new audio source for $filePath');
        audioSource = AudioSource.file(filePath);
        await _audioPlayer!.setAudioSource(audioSource);
        _cacheSource(filePath, audioSource);
      }

      await _audioPlayer!.setSpeed(_playbackSpeed);
      await _audioPlayer!.setVolume(_playbackVolume);
      
      // CRITICAL: Update state BEFORE calling play()
      _currentlyPlayingFile = filePath;
      _playbackActive = true;
      _playbackPaused = false;
      
      await _audioPlayer!.play();
      
      // Start amplitude simulation for waveform
      _startAmplitudeSimulation();

      debugPrint('✅ AudioPlayerService: Started playing $filePath');
      return true;

    } catch (e) {
      debugPrint('❌ AudioPlayerService: Failed to start playback: $e');
      _playbackActive = false;
      _currentlyPlayingFile = null;
      return false;
    }
  }

  @override
  Future<bool> stopPlaying() async {
    if (!_ensureInitialized()) return false;

    try {
      await _audioPlayer!.stop();
      
      // CRITICAL: Update state after stopping
      _currentlyPlayingFile = null;
      _playbackPosition = Duration.zero;
      _playbackActive = false;
      _playbackPaused = false;
      _stopAmplitudeSimulation();

      debugPrint('✅ AudioPlayerService: Playback stopped');
      return true;

    } catch (e) {
      debugPrint('❌ AudioPlayerService: Failed to stop playback: $e');
      return false;
    }
  }

  @override
  Future<bool> pausePlaying() async {
    if (!_ensureInitialized() || !_playbackActive) return false;

    try {
      await _audioPlayer!.pause();
      
      // CRITICAL: Update state after pausing
      _playbackPaused = true;
      _stopAmplitudeSimulation();
      
      debugPrint('✅ AudioPlayerService: Playback paused');
      return true;

    } catch (e) {
      debugPrint('❌ AudioPlayerService: Failed to pause playback: $e');
      return false;
    }
  }

  @override
  Future<bool> resumePlaying() async {
    if (!_ensureInitialized() || !_playbackPaused) return false;

    try {
      await _audioPlayer!.play();
      
      // CRITICAL: Update state after resuming
      _playbackPaused = false;
      _startAmplitudeSimulation();
      
      debugPrint('✅ AudioPlayerService: Playback resumed');
      return true;

    } catch (e) {
      debugPrint('❌ AudioPlayerService: Failed to resume playback: $e');
      return false;
    }
  }

  @override
  Future<bool> seekTo(Duration position) async {
    if (!_ensureInitialized()) return false;

    try {
      // Validate seek position - use player duration if available
      if (position.isNegative ||
          (_playbackDuration > Duration.zero && position > _playbackDuration)) {
        debugPrint('❌ Invalid seek position: $position');
        return false;
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

  /// Seek to position with custom duration validation (for waveform seeking)
  Future<bool> seekToWithRecordingDuration(Duration position, Duration recordingDuration) async {
    if (!_ensureInitialized()) return false;

    try {
      // Validate against recording duration instead of player duration
      if (position.isNegative || position > recordingDuration) {
        debugPrint('❌ Invalid seek position: $position (max: $recordingDuration)');
        return false;
      }

      await _audioPlayer!.seek(position);
      _playbackPosition = position;
      debugPrint('🎵 Seeked to waveform position: $position');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to seek to waveform position: $e');
      return false;
    }
  }

  @override
  Future<bool> setPlaybackSpeed(double speed) async {
    if (!_ensureInitialized()) return false;

    try {
      // Validate speed range
      if (speed < 0.25 || speed > 3.0) {
        debugPrint('❌ Invalid playback speed: $speed');
        return false;
      }

      await _audioPlayer!.setSpeed(speed);
      _playbackSpeed = speed;
      debugPrint('🎵 Playback speed set: ${speed}x');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to set playback speed: $e');
      return false;
    }
  }

  @override
  Future<bool> setVolume(double volume) async {
    if (!_ensureInitialized()) return false;

    try {
      // Validate volume range
      if (volume < 0.0 || volume > 1.0) {
        debugPrint('❌ Invalid volume: $volume');
        return false;
      }

      await _audioPlayer!.setVolume(volume);
      _playbackVolume = volume;
      debugPrint('🎵 Volume set: $volume');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to set volume: $e');
      return false;
    }
  }

  // ==== STATE QUERIES ====

  @override
  Future<bool> isPlaying() async => _playbackActive;

  @override
  Future<bool> isPlaybackPaused() async => _playbackPaused;

  @override
  Future<Duration> getCurrentPlaybackPosition() async => _playbackPosition;

  @override
  Future<Duration> getCurrentPlaybackDuration() async => _playbackDuration;

  // ==== STREAM GETTERS ====

  @override
  Stream<Duration> getPlaybackPositionStream() =>
      _positionStreamController?.stream ?? const Stream.empty();

  @override
  Stream<void> getPlaybackCompletionStream() =>
      _completionStreamController?.stream ?? const Stream.empty();

  // ==== RECORDING OPERATIONS (Not Supported) ====

  @override
  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
  }) async {
    debugPrint('❌ Recording not supported in player service');
    return false;
  }

  @override
  Future<RecordingEntity?> stopRecording() async {
    debugPrint('❌ Recording not supported in player service');
    return null;
  }

  @override
  Future<bool> pauseRecording() async {
    debugPrint('❌ Recording not supported in player service');
    return false;
  }

  @override
  Future<bool> resumeRecording() async {
    debugPrint('❌ Recording not supported in player service');
    return false;
  }

  @override
  Future<bool> cancelRecording() async {
    debugPrint('❌ Recording not supported in player service');
    return false;
  }

  @override
  Future<bool> isRecording() async => false;

  @override
  Future<bool> isRecordingPaused() async => false;

  @override
  Future<Duration> getCurrentRecordingDuration() async => Duration.zero;

  @override
  Stream<double> getRecordingAmplitudeStream() => const Stream.empty();

  // ==== AUDIO FILE OPERATIONS ====

  @override
  Future<AudioFileInfo?> getAudioFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final stats = await file.stat();
      final format = _detectAudioFormat(filePath);
      if (format == null) return null;

      // Basic file information
      // TODO: For production, implement proper audio metadata extraction
      return AudioFileInfo(
        filePath: filePath,
        format: format,
        duration: const Duration(seconds: 60), // Placeholder
        fileSize: stats.size,
        sampleRate: 44100, // Default
        bitRate: 128000, // Default
        channels: 2, // Default
        createdAt: stats.modified,
      );

    } catch (e) {
      debugPrint('❌ Error getting audio file info: $e');
      return null;
    }
  }

  @override
  Future<String?> convertAudioFile({
    required String inputPath,
    required String outputPath,
    required AudioFormat targetFormat,
    int? targetSampleRate,
    int? targetBitRate,
  }) async {
    // TODO: Implement audio conversion
    debugPrint('⚠️ Audio conversion not yet implemented');
    return null;
  }

  @override
  Future<String?> trimAudioFile({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
  }) async {
    // TODO: Implement audio trimming
    debugPrint('⚠️ Audio trimming not yet implemented');
    return null;
  }

  @override
  Future<String?> mergeAudioFiles({
    required List<String> inputPaths,
    required String outputPath,
    required AudioFormat outputFormat,
  }) async {
    // TODO: Implement audio merging
    debugPrint('⚠️ Audio merging not yet implemented');
    return null;
  }

  @override
  Future<List<double>> getWaveformData(String filePath, {int sampleCount = 100}) async {
    // TODO: Implement waveform extraction
    debugPrint('⚠️ Waveform extraction not yet implemented');
    return [];
  }

  // ==== DEVICE & PERMISSIONS ====

  @override
  Future<bool> hasMicrophonePermission() async => true; // Not needed for playback

  @override
  Future<bool> requestMicrophonePermission() async => true; // Not needed for playback

  @override
  Future<bool> hasMicrophone() async => true; // Not relevant for playback

  @override
  Future<List<AudioInputDevice>> getAudioInputDevices() async => []; // Not needed for playback

  @override
  Future<bool> setAudioInputDevice(String deviceId) async => true; // Not needed for playback

  @override
  Future<List<AudioFormat>> getSupportedFormats() async {
    return [AudioFormat.wav, AudioFormat.m4a, AudioFormat.flac];
  }

  @override
  Future<List<int>> getSupportedSampleRates(AudioFormat format) async {
    return [22050, 44100, 48000, 96000];
  }

  // ==== SETTINGS & CONFIGURATION ====

  @override
  Future<bool> setAudioSessionCategory(AudioSessionCategory category) async {
    // TODO: Implement platform-specific audio session management
    debugPrint('⚠️ Audio session management not yet implemented');
    return true;
  }

  @override
  Future<bool> enableBackgroundRecording() async => true; // Not relevant for playback

  @override
  Future<bool> disableBackgroundRecording() async => true; // Not relevant for playback

  // ==== HELPER METHODS ====

  /// Ensure service is initialized
  bool _ensureInitialized() {
    if (!_isServiceInitialized || _audioPlayer == null) {
      debugPrint('❌ Audio player service not initialized');
      return false;
    }
    return true;
  }

  /// Validate audio file exists and is accessible
  Future<bool> _validateAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists() && await file.length() > 0;
    } catch (e) {
      return false;
    }
  }

  /// Detect audio format from file extension
  AudioFormat? _detectAudioFormat(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'wav':
        return AudioFormat.wav;
      case 'm4a':
      case 'mp4':
        return AudioFormat.m4a;
      case 'flac':
        return AudioFormat.flac;
      default:
        return null;
    }
  }

  /// Start amplitude simulation for visual effects
  void _startAmplitudeSimulation() {
    _stopAmplitudeSimulation();

    _amplitudeSimulationTimer = Timer.periodic(
      const Duration(milliseconds: 100),
          (timer) {
        if (!_playbackActive) {
          timer.cancel();
          return;
        }

        // Generate realistic amplitude simulation
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

  // ==== PUBLIC GETTERS (No conflicts with interface) ====

  /// Current playback speed
  double get playbackSpeed => _playbackSpeed;

  /// Current volume level
  double get volumeLevel => _playbackVolume;

  /// Currently playing file path
  String? get currentFile => _currentlyPlayingFile;

  /// Service initialization status
  bool get isServiceReady => _isServiceInitialized;

  // ==== CACHE MANAGEMENT METHODS ====

  /// Get cached audio source and update access order
  AudioSource? _getCachedSource(String filePath) {
    if (_preloadedSources.containsKey(filePath)) {
      // Move to end of access order (most recently used)
      _accessOrder.remove(filePath);
      _accessOrder.add(filePath);
      return _preloadedSources[filePath];
    }
    return null;
  }

  /// Cache audio source with LRU eviction
  void _cacheSource(String filePath, AudioSource audioSource) {
    // If already cached, just update access order
    if (_preloadedSources.containsKey(filePath)) {
      _accessOrder.remove(filePath);
      _accessOrder.add(filePath);
      return;
    }

    // If cache is full, remove least recently used
    if (_preloadedSources.length >= _maxCacheSize) {
      final lruFilePath = _accessOrder.removeAt(0);
      _preloadedSources.remove(lruFilePath);
      debugPrint('🗑️ Evicted LRU audio source: $lruFilePath');
    }

    // Add new source to cache
    _preloadedSources[filePath] = audioSource;
    _accessOrder.add(filePath);
    debugPrint('💾 Cached audio source: $filePath (cache size: ${_preloadedSources.length})');
  }

  /// Preload an audio source without playing it
  Future<bool> preloadAudioSource(String filePath) async {
    if (!_ensureInitialized()) return false;

    try {
      // Check if already cached
      if (_preloadedSources.containsKey(filePath)) {
        debugPrint('✅ Audio source already cached: $filePath');
        // Update access order
        _accessOrder.remove(filePath);
        _accessOrder.add(filePath);
        return true;
      }

      // Validate file
      if (!await _validateAudioFile(filePath)) {
        debugPrint('❌ Invalid audio file for preload: $filePath');
        return false;
      }

      // Create audio source and cache it
      final audioSource = AudioSource.file(filePath);
      _cacheSource(filePath, audioSource);
      
      debugPrint('✅ Preloaded audio source: $filePath');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to preload audio source: $e');
      return false;
    }
  }

  /// Clear all cached sources
  void clearCache() {
    _preloadedSources.clear();
    _accessOrder.clear();
    debugPrint('🗑️ Cleared audio source cache');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _preloadedSources.length,
      'maxSize': _maxCacheSize,
      'files': _accessOrder.toList(),
    };
  }
}