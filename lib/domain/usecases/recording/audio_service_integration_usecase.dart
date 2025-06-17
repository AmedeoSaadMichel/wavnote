// File: domain/usecases/recording/audio_service_integration_usecase.dart
import 'dart:async';
import '../../../core/enums/audio_format.dart';
import '../../../services/audio/audio_service_factory.dart';
import '../../repositories/i_audio_service_repository.dart';
import '../../entities/recording_entity.dart';

/// Use case for managing audio service lifecycle and operations
///
/// Provides a clean interface between the UI layer and audio services,
/// handling initialization, cleanup, and coordinating audio operations
/// while maintaining proper error handling and state management.
class AudioServiceIntegrationUseCase {

  // Private fields
  IAudioServiceRepository? _audioService;
  bool _isInitialized = false;
  String? _lastError;
  final List<StreamSubscription> _subscriptions = [];

  // ==== PUBLIC API ====

  /// Initialize the audio service
  Future<bool> initialize() async {
    try {
      if (_isInitialized) {
        await dispose();
      }

      // Create audio service using factory
      _audioService = AudioServiceFactory.createFromConfig();

      // Initialize the service
      final success = await _audioService!.initialize();

      if (success) {
        _isInitialized = true;
        _lastError = null;
        await _setupEventListeners();
        print('✅ Audio service integration initialized');
      } else {
        _lastError = 'Failed to initialize audio service';
        print('❌ Audio service initialization failed');
      }

      return success;
    } catch (e) {
      _lastError = 'Initialization error: ${e.toString()}';
      print('❌ Error initializing audio service: $e');
      return false;
    }
  }

  /// Dispose the audio service and cleanup resources
  Future<void> dispose() async {
    try {
      // Cancel all subscriptions
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();

      // Dispose audio service
      if (_audioService != null) {
        await _audioService!.dispose();
        _audioService = null;
      }

      _isInitialized = false;
      _lastError = null;

      print('✅ Audio service integration disposed');
    } catch (e) {
      print('❌ Error disposing audio service: $e');
    }
  }

  // ==== RECORDING OPERATIONS ====

  /// Start recording with specified parameters
  Future<bool> startRecording({
    required String filePath,
    AudioFormat format = AudioFormat.m4a,
    int sampleRate = 44100,
    int bitRate = 128000,
  }) async {
    if (!_ensureReady()) return false;

    try {
      final success = await _audioService!.startRecording(
        filePath: filePath,
        format: format,
        sampleRate: sampleRate,
        bitRate: bitRate,
      );

      if (!success) {
        _lastError = 'Failed to start recording';
      }

      return success;
    } catch (e) {
      _lastError = 'Recording start error: ${e.toString()}';
      print('❌ Error starting recording: $e');
      return false;
    }
  }

  /// Stop current recording
  Future<RecordingEntity?> stopRecording() async {
    if (!_ensureReady()) return null;

    try {
      return await _audioService!.stopRecording();
    } catch (e) {
      _lastError = 'Recording stop error: ${e.toString()}';
      print('❌ Error stopping recording: $e');
      return null;
    }
  }

  /// Pause current recording
  Future<bool> pauseRecording() async {
    if (!_ensureReady()) return false;

    try {
      final success = await _audioService!.pauseRecording();
      if (!success) {
        _lastError = 'Failed to pause recording';
      }
      return success;
    } catch (e) {
      _lastError = 'Recording pause error: ${e.toString()}';
      print('❌ Error pausing recording: $e');
      return false;
    }
  }

  /// Resume paused recording
  Future<bool> resumeRecording() async {
    if (!_ensureReady()) return false;

    try {
      final success = await _audioService!.resumeRecording();
      if (!success) {
        _lastError = 'Failed to resume recording';
      }
      return success;
    } catch (e) {
      _lastError = 'Recording resume error: ${e.toString()}';
      print('❌ Error resuming recording: $e');
      return false;
    }
  }

  /// Cancel current recording
  Future<bool> cancelRecording() async {
    if (!_ensureReady()) return false;

    try {
      final success = await _audioService!.cancelRecording();
      if (!success) {
        _lastError = 'Failed to cancel recording';
      }
      return success;
    } catch (e) {
      _lastError = 'Recording cancel error: ${e.toString()}';
      print('❌ Error cancelling recording: $e');
      return false;
    }
  }

  // ==== PLAYBACK OPERATIONS ====

  /// Start playing an audio file
  Future<bool> startPlayback(String filePath) async {
    if (!_ensureReady()) return false;

    try {
      final success = await _audioService!.startPlaying(filePath);
      if (!success) {
        _lastError = 'Failed to start playback';
      }
      return success;
    } catch (e) {
      _lastError = 'Playback start error: ${e.toString()}';
      print('❌ Error starting playback: $e');
      return false;
    }
  }

  /// Stop current playback
  Future<bool> stopPlayback() async {
    if (!_ensureReady()) return false;

    try {
      final success = await _audioService!.stopPlaying();
      if (!success) {
        _lastError = 'Failed to stop playback';
      }
      return success;
    } catch (e) {
      _lastError = 'Playback stop error: ${e.toString()}';
      print('❌ Error stopping playback: $e');
      return false;
    }
  }

  /// Pause current playback
  Future<bool> pausePlayback() async {
    if (!_ensureReady()) return false;

    try {
      final success = await _audioService!.pausePlaying();
      if (!success) {
        _lastError = 'Failed to pause playback';
      }
      return success;
    } catch (e) {
      _lastError = 'Playback pause error: ${e.toString()}';
      print('❌ Error pausing playback: $e');
      return false;
    }
  }

  /// Resume paused playback
  Future<bool> resumePlayback() async {
    if (!_ensureReady()) return false;

    try {
      final success = await _audioService!.resumePlaying();
      if (!success) {
        _lastError = 'Failed to resume playback';
      }
      return success;
    } catch (e) {
      _lastError = 'Playback resume error: ${e.toString()}';
      print('❌ Error resuming playback: $e');
      return false;
    }
  }

  /// Seek to specific position
  Future<bool> seekTo(Duration position) async {
    if (!_ensureReady()) return false;

    try {
      final success = await _audioService!.seekTo(position);
      if (!success) {
        _lastError = 'Failed to seek to position';
      }
      return success;
    } catch (e) {
      _lastError = 'Seek error: ${e.toString()}';
      print('❌ Error seeking: $e');
      return false;
    }
  }

  /// Set playback speed
  Future<bool> setPlaybackSpeed(double speed) async {
    if (!_ensureReady()) return false;

    try {
      final success = await _audioService!.setPlaybackSpeed(speed);
      if (!success) {
        _lastError = 'Failed to set playback speed';
      }
      return success;
    } catch (e) {
      _lastError = 'Speed control error: ${e.toString()}';
      print('❌ Error setting playback speed: $e');
      return false;
    }
  }

  /// Set volume
  Future<bool> setVolume(double volume) async {
    if (!_ensureReady()) return false;

    try {
      final success = await _audioService!.setVolume(volume);
      if (!success) {
        _lastError = 'Failed to set volume';
      }
      return success;
    } catch (e) {
      _lastError = 'Volume control error: ${e.toString()}';
      print('❌ Error setting volume: $e');
      return false;
    }
  }

  // ==== STATE QUERIES ====

  /// Check if service is ready
  bool get isReady => _isInitialized && _audioService != null;

  /// Check if currently recording
  Future<bool> get isRecording async {
    if (!isReady) return false;
    try {
      return await _audioService!.isRecording();
    } catch (e) {
      print('❌ Error checking recording state: $e');
      return false;
    }
  }

  /// Check if recording is paused
  Future<bool> get isRecordingPaused async {
    if (!isReady) return false;
    try {
      return await _audioService!.isRecordingPaused();
    } catch (e) {
      print('❌ Error checking recording pause state: $e');
      return false;
    }
  }

  /// Check if currently playing
  Future<bool> get isPlaying async {
    if (!isReady) return false;
    try {
      return await _audioService!.isPlaying();
    } catch (e) {
      print('❌ Error checking playing state: $e');
      return false;
    }
  }

  /// Check if playback is paused
  Future<bool> get isPlaybackPaused async {
    if (!isReady) return false;
    try {
      return await _audioService!.isPlaybackPaused();
    } catch (e) {
      print('❌ Error checking playback pause state: $e');
      return false;
    }
  }

  /// Get current recording duration
  Future<Duration> get recordingDuration async {
    if (!isReady) return Duration.zero;
    try {
      return await _audioService!.getCurrentRecordingDuration();
    } catch (e) {
      print('❌ Error getting recording duration: $e');
      return Duration.zero;
    }
  }

  /// Get current playback position
  Future<Duration> get playbackPosition async {
    if (!isReady) return Duration.zero;
    try {
      return await _audioService!.getCurrentPlaybackPosition();
    } catch (e) {
      print('❌ Error getting playback position: $e');
      return Duration.zero;
    }
  }

  /// Get total playback duration
  Future<Duration> get playbackDuration async {
    if (!isReady) return Duration.zero;
    try {
      return await _audioService!.getCurrentPlaybackDuration();
    } catch (e) {
      print('❌ Error getting playback duration: $e');
      return Duration.zero;
    }
  }

  /// Get last error message
  String? get lastError => _lastError;

  // ==== STREAM ACCESS ====

  /// Get amplitude stream for visualization
  Stream<double> get amplitudeStream {
    if (!isReady) return const Stream.empty();
    return _audioService!.getRecordingAmplitudeStream();
  }

  /// Get playback position stream
  Stream<Duration> get positionStream {
    if (!isReady) return const Stream.empty();
    return _audioService!.getPlaybackPositionStream();
  }

  /// Get playback completion stream
  Stream<void> get playbackCompletionStream {
    if (!isReady) return const Stream.empty();
    return _audioService!.getPlaybackCompletionStream();
  }

  // ==== PERMISSION HELPERS ====

  /// Check microphone permission
  Future<bool> hasMicrophonePermission() async {
    if (!isReady) return false;
    try {
      return await _audioService!.hasMicrophonePermission();
    } catch (e) {
      print('❌ Error checking microphone permission: $e');
      return false;
    }
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    if (!isReady) return false;
    try {
      return await _audioService!.requestMicrophonePermission();
    } catch (e) {
      print('❌ Error requesting microphone permission: $e');
      return false;
    }
  }

  // ==== AUDIO FILE OPERATIONS ====

  /// Get supported audio formats
  Future<List<AudioFormat>> getSupportedFormats() async {
    if (!isReady) return [];
    try {
      return await _audioService!.getSupportedFormats();
    } catch (e) {
      print('❌ Error getting supported formats: $e');
      return [AudioFormat.m4a, AudioFormat.wav]; // Fallback
    }
  }

  /// Get supported sample rates for a format
  Future<List<int>> getSupportedSampleRates(AudioFormat format) async {
    if (!isReady) return [];
    try {
      return await _audioService!.getSupportedSampleRates(format);
    } catch (e) {
      print('❌ Error getting supported sample rates: $e');
      return [44100, 48000]; // Fallback
    }
  }

  // ==== PRIVATE METHODS ====

  /// Ensure service is ready for operations
  bool _ensureReady() {
    if (!isReady) {
      _lastError = 'Audio service not initialized';
      print('❌ Audio service not ready for operation');
      return false;
    }
    return true;
  }

  /// Setup event listeners for audio service
  Future<void> _setupEventListeners() async {
    if (_audioService == null) return;

    try {
      // Listen to amplitude changes for recording visualization
      _subscriptions.add(
        _audioService!.getRecordingAmplitudeStream().listen(
              (amplitude) {
            // Handle amplitude updates if needed
          },
          onError: (error) {
            print('❌ Amplitude stream error: $error');
          },
        ),
      );

      // Listen to position changes for playback progress
      _subscriptions.add(
        _audioService!.getPlaybackPositionStream().listen(
              (position) {
            // Handle position updates if needed
          },
          onError: (error) {
            print('❌ Position stream error: $error');
          },
        ),
      );

      // Listen to playback completion
      _subscriptions.add(
        _audioService!.getPlaybackCompletionStream().listen(
              (_) {
            print('📻 Playback completed');
            // Handle playback completion if needed
          },
          onError: (error) {
            print('❌ Completion stream error: $error');
          },
        ),
      );

      print('✅ Audio service event listeners setup complete');
    } catch (e) {
      print('❌ Error setting up event listeners: $e');
    }
  }

  /// Clear last error
  void clearError() {
    _lastError = null;
  }

  /// Check if a specific audio format is supported
  Future<bool> isFormatSupported(AudioFormat format) async {
    if (!isReady) return false;

    try {
      final supportedFormats = await getSupportedFormats();
      return supportedFormats.contains(format);
    } catch (e) {
      print('❌ Error checking format support: $e');
      // Fallback to basic format support
      return [AudioFormat.m4a, AudioFormat.wav, AudioFormat.flac].contains(format);
    }
  }
}