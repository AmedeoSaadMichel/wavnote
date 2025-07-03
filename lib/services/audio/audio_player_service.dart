// File: services/audio/audio_player_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../domain/repositories/i_audio_service_repository.dart';
import '../../domain/entities/recording_entity.dart';
import '../../core/enums/audio_format.dart';
import 'audio_state_manager.dart';

/// Audio playback service using just_audio
///
/// Provides complete audio playback functionality for the voice memo app.
/// Focused specifically on playback operations while implementing the full
/// IAudioServiceRepository interface for compatibility.
/// 
/// Now includes expansion logic and state management previously in AudioPlayerManager.
class AudioPlayerService implements IAudioServiceRepository {

  // Singleton instance
  static AudioPlayerService? _instance;
  static AudioPlayerService get instance => _instance ??= AudioPlayerService._internal();
  
  AudioPlayerService._internal();

  // Core audio player
  AudioPlayer? _audioPlayer;

  // Service state
  bool _isServiceInitialized = false;
  String? _currentlyPlayingFile;

  // Expansion state (from AudioPlayerManager)
  String? _expandedRecordingId;
  bool _isLoading = false;
  bool _hasCompletedCurrentPlayback = false;
  
  // AudioStateManager for optimized UI updates
  AudioStateManager? _audioStateManager;
  
  // Callback for expansion state changes
  VoidCallback? _onExpansionChanged;

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
  
  // Timer for throttled updates (from AudioPlayerManager)
  Timer? _positionUpdateTimer;
  static const Duration _updateInterval = Duration(milliseconds: 100); // 10fps
  
  // Performance optimization: throttle position updates
  DateTime _lastPositionUpdate = DateTime(0);
  static const Duration _positionUpdateInterval = Duration(milliseconds: 500); // 2 updates per second

  // Amplitude simulation
  Timer? _amplitudeSimulationTimer;

  // ==== SERVICE LIFECYCLE ====

  /// Initialize audio player with expansion callback
  @override
  Future<bool> initialize([VoidCallback? onStateChanged]) async {
    try {
      debugPrint('🔧 AUDIO_SVC: Initialize called, isInitialized: $_isServiceInitialized');
      
      // If already initialized, only update callback if provided
      if (_isServiceInitialized) {
        debugPrint('✅ AUDIO_SVC: Service already initialized, updating callback only');
        if (onStateChanged != null) {
          setExpansionCallback(onStateChanged);
        }
        return true;
      }

      // Create new audio player instance
      _audioPlayer = AudioPlayer();
      
      // Initialize AudioStateManager
      _audioStateManager = AudioStateManager();

      // Initialize stream controllers
      _positionStreamController = StreamController<Duration>.broadcast();
      _completionStreamController = StreamController<void>.broadcast();
      _amplitudeStreamController = StreamController<double>.broadcast();
      
      // Setup expansion callback
      if (onStateChanged != null) {
        debugPrint('🔧 AUDIO_SVC: Setting up expansion callback');
        _audioStateManager!.addListener(onStateChanged);
        _onExpansionChanged = onStateChanged;
      } else {
        debugPrint('⚠️ AUDIO_SVC: No expansion callback provided');
      }

      // Setup audio player listeners
      await _initializePlayerListeners();

      _isServiceInitialized = true;
      debugPrint('✅ Audio player service initialized successfully with callback: ${_onExpansionChanged != null}');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to initialize audio player service: $e');
      _isServiceInitialized = false;
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    debugPrint('🔧 Audio player service: Starting disposal...');
    
    // Stop any active playback first
    try {
      if (_playbackActive) {
        await stopPlaying();
      }
    } catch (e) {
      debugPrint('⚠️ Error stopping playback during disposal: $e');
    }

    // Cancel all subscriptions with guaranteed cleanup
    try {
      await _positionSubscription?.cancel();
    } catch (e) {
      debugPrint('⚠️ Error cancelling position subscription: $e');
    } finally {
      _positionSubscription = null;
    }

    try {
      await _stateSubscription?.cancel();
    } catch (e) {
      debugPrint('⚠️ Error cancelling state subscription: $e');
    } finally {
      _stateSubscription = null;
    }

    try {
      await _durationSubscription?.cancel();
    } catch (e) {
      debugPrint('⚠️ Error cancelling duration subscription: $e');
    } finally {
      _durationSubscription = null;
    }

    try {
      _amplitudeSimulationTimer?.cancel();
    } catch (e) {
      debugPrint('⚠️ Error cancelling amplitude timer: $e');
    } finally {
      _amplitudeSimulationTimer = null;
    }

    // Close stream controllers with guaranteed cleanup
    try {
      await _positionStreamController?.close();
    } catch (e) {
      debugPrint('⚠️ Error closing position stream controller: $e');
    } finally {
      _positionStreamController = null;
    }

    try {
      await _completionStreamController?.close();
    } catch (e) {
      debugPrint('⚠️ Error closing completion stream controller: $e');
    } finally {
      _completionStreamController = null;
    }

    try {
      await _amplitudeStreamController?.close();
    } catch (e) {
      debugPrint('⚠️ Error closing amplitude stream controller: $e');
    } finally {
      _amplitudeStreamController = null;
    }

    // Dispose audio player with guaranteed cleanup
    try {
      await _audioPlayer?.dispose();
    } catch (e) {
      debugPrint('⚠️ Error disposing audio player: $e');
    } finally {
      _audioPlayer = null;
    }

    // Dispose AudioStateManager
    try {
      _audioStateManager?.dispose();
    } catch (e) {
      debugPrint('⚠️ Error disposing audio state manager: $e');
    } finally {
      _audioStateManager = null;
    }
    
    // Cancel position update timer
    try {
      _positionUpdateTimer?.cancel();
    } catch (e) {
      debugPrint('⚠️ Error cancelling position timer: $e');
    } finally {
      _positionUpdateTimer = null;
    }

    // Clear cache and reset state (guaranteed to execute)
    _preloadedSources.clear();
    _accessOrder.clear();
    _isServiceInitialized = false;
    _playbackActive = false;
    _playbackPaused = false;
    _currentlyPlayingFile = null;
    _playbackPosition = Duration.zero;
    _playbackDuration = Duration.zero;
    _lastPositionUpdate = DateTime(0);
    _expandedRecordingId = null;
    _isLoading = false;
    _hasCompletedCurrentPlayback = false;
    _onExpansionChanged = null;

    debugPrint('✅ Audio player service disposed successfully');
  }

  /// Initialize audio player event listeners (enhanced from AudioPlayerManager)
  Future<void> _initializePlayerListeners() async {
    if (_audioPlayer == null || _audioStateManager == null) return;

    try {
      // OPTIMIZED: Throttled position updates (10fps instead of 60fps)
      _positionSubscription = _audioPlayer!.positionStream.listen((position) {
        // Skip processing if already completed to prevent unnecessary rebuilds
        if (_hasCompletedCurrentPlayback && !_audioStateManager!.isPlaying) {
          return;
        }
        
        // Handle position overrun by forcing completion
        if (_audioStateManager!.duration.inMilliseconds > 0 && position.inMilliseconds > _audioStateManager!.duration.inMilliseconds) {
          if (!_hasCompletedCurrentPlayback) {
            debugPrint('⚠️ Position overrun detected: ${position.inMilliseconds}ms > ${_audioStateManager!.duration.inMilliseconds}ms, forcing completion');
            _audioStateManager!.updatePosition(_audioStateManager!.duration); // Cap at 100%
            _audioStateManager!.updatePlaybackState(isPlaying: false);
            _hasCompletedCurrentPlayback = true;
            
            // Force stop the audio player to prevent continuous overrun
            _audioPlayer!.pause().then((_) {
              _audioPlayer!.seek(Duration.zero);
              _audioStateManager!.updatePosition(Duration.zero); // Update position to 0 after seek
              debugPrint('🔚 Audio forcibly stopped due to overrun, position reset to 0');
            });
          }
          return; // Don't process further or trigger more rebuilds
        }
        
        // OPTIMIZED: Update position via AudioStateManager (no setState)
        _audioStateManager!.updatePosition(position);
        _playbackPosition = position;
        
        // Emit position for legacy stream consumers
        final now = DateTime.now();
        if (now.difference(_lastPositionUpdate) >= _positionUpdateInterval) {
          _positionStreamController?.add(position);
          _lastPositionUpdate = now;
        }
        
        if (_audioStateManager!.duration.inMilliseconds > 0) {
          final percentage = (position.inMilliseconds / _audioStateManager!.duration.inMilliseconds * 100);
          debugPrint('🕒 Position: ${_formatTime(position)} (${position.inMilliseconds}ms) / ${_formatTime(_audioStateManager!.duration)} (${_audioStateManager!.duration.inMilliseconds}ms) = ${percentage.toStringAsFixed(1)}%');
          
          // Check for near-completion to trigger natural completion handling
          if (percentage >= 99.5 && _audioStateManager!.isPlaying && !_hasCompletedCurrentPlayback) {
            debugPrint('🔚 Audio approaching completion at ${percentage.toStringAsFixed(1)}% (${position.inMilliseconds}ms/${_audioStateManager!.duration.inMilliseconds}ms)');
            _hasCompletedCurrentPlayback = true;
            _audioStateManager!.updatePlaybackState(isPlaying: false);
            _audioStateManager!.updatePosition(_audioStateManager!.duration); // Set to 100% completion
          }
        } else {
          debugPrint('🕒 Position: ${_formatTime(position)} (${position.inMilliseconds}ms) / ${_formatTime(_audioStateManager!.duration)} (${_audioStateManager!.duration.inMilliseconds}ms) - duration not set');
        }
      }, onError: (error) => debugPrint('❌ Position stream error: $error'));

      _durationSubscription = _audioPlayer!.durationStream.listen((duration) {
        if (duration != null && duration > Duration.zero) {
          final oldDuration = _audioStateManager!.duration;
          _audioStateManager!.updateDuration(duration); // OPTIMIZED: Update via AudioStateManager
          _playbackDuration = duration;
          debugPrint('🕒 Duration updated from audio player:');
          debugPrint('   Old: ${_formatTime(oldDuration)} (${oldDuration.inMilliseconds}ms)');
          debugPrint('   New: ${_formatTime(duration)} (${duration.inMilliseconds}ms)');
          debugPrint('   Difference: ${(duration.inMilliseconds - oldDuration.inMilliseconds)}ms');
        } else if (duration != null) {
          debugPrint('🕒 Audio player reported zero duration, keeping current: ${_formatTime(_audioStateManager!.duration)} (${_audioStateManager!.duration.inMilliseconds}ms)');
        }
      }, onError: (error) => debugPrint('❌ Duration stream error: $error'));

      _stateSubscription = _audioPlayer!.playerStateStream.listen((state) {
        // OPTIMIZED: Update playing state via AudioStateManager
        _audioStateManager!.updatePlaybackState(
          isPlaying: state.playing,
          isBuffering: state.processingState == ProcessingState.buffering,
        );
        _playbackActive = state.playing;
        _playbackPaused = !state.playing && state.processingState == ProcessingState.ready;
        
        // Trigger UI rebuild when playback state changes
        _onExpansionChanged?.call();
        
        debugPrint('🎵 Player state changed: playing=${state.playing}, processingState=${state.processingState}');
        
        // Handle natural completion
        if (state.processingState == ProcessingState.completed && !_hasCompletedCurrentPlayback) {
          debugPrint('🔚 Audio completed naturally at 100%');
          _audioStateManager!.updatePlaybackState(isPlaying: false);
          _audioStateManager!.updatePosition(_audioStateManager!.duration); // Set to full duration for 100% completion
          _hasCompletedCurrentPlayback = true;
          _playbackActive = false;
          _playbackPaused = false;
          _completionStreamController?.add(null);
          
          // DON'T auto-reset - let the user decide when to restart
          // Position will be reset when user clicks play again via togglePlayback()
          debugPrint('🔚 Audio completed, staying at end position - no auto-restart');
        }
        
        // Debug all state changes
        debugPrint('🎵 Audio state: playing=${state.playing}, processing=${state.processingState}');
      }, onError: (error) => debugPrint('❌ Player state error: $error'));

    } catch (e) {
      debugPrint('❌ Error setting up player listeners: $e');
    }
  }

  // This method is now integrated into _initializePlayerListeners()

  // ==== EXPANSION AND RECORDING OPERATIONS (from AudioPlayerManager) ====
  
  /// Expand/collapse recording
  Future<void> expandRecording(RecordingEntity recording) async {
    debugPrint('🎯 AUDIO_SVC: expandRecording called for: ${recording.name} (ID: ${recording.id}), current expanded: $_expandedRecordingId');
    
    if (_expandedRecordingId == recording.id) {
      // Collapse current recording
      debugPrint('🎯 AUDIO_SVC: Collapsing recording: ${recording.name}');
      await stopPlaying();
      _expandedRecordingId = null;
      _audioStateManager?.reset(); // OPTIMIZED: Reset all state via AudioStateManager
      debugPrint('🎯 AUDIO_SVC: Calling _onExpansionChanged to trigger UI rebuild');
      _onExpansionChanged?.call(); // Notify UI of expansion change
    } else {
      // Expand new recording (stop any current playback first)
      debugPrint('🎯 AUDIO_SVC: Expanding recording: ${recording.name} (ID: ${recording.id})');
      if (_expandedRecordingId != null) {
        debugPrint('🎯 AUDIO_SVC: Stopping previous recording (ID: $_expandedRecordingId) before expanding new one');
        await stopPlaying();
      }
      await setupAudioForRecording(recording);
    }
  }
  
  /// Reset expansion state - call this when UI state gets out of sync
  void resetExpansionState() {
    debugPrint('🎯 AUDIO_SVC: Resetting expansion state');
    _expandedRecordingId = null;
    _audioStateManager?.reset();
    _onExpansionChanged?.call();
  }
  
  /// Update expansion callback without full re-initialization
  void setExpansionCallback(VoidCallback? callback) {
    debugPrint('🔧 AUDIO_SVC: Setting expansion callback: ${callback != null}');
    _onExpansionChanged = callback;
    if (callback != null && _audioStateManager != null) {
      _audioStateManager!.addListener(callback);
    }
  }
  
  /// Reset audio state without disposing the service
  void resetAudioState() {
    debugPrint('🔄 AUDIO_SVC: Resetting audio state without disposal');
    _expandedRecordingId = null;
    _isLoading = false;
    _hasCompletedCurrentPlayback = false;
    _currentlyPlayingFile = null;
    _playbackPosition = Duration.zero;
    _playbackDuration = Duration.zero;
    _playbackActive = false;
    _playbackPaused = false;
    _audioStateManager?.reset();
  }
  
  /// Setup audio for a recording
  Future<void> setupAudioForRecording(RecordingEntity recording) async {
    _isLoading = true;
    _audioStateManager?.updateError(null); // Clear any previous errors

    try {
      // STEP 1: Check if file exists, if not try to find it in current app directory
      String workingFilePath = recording.filePath;
      File file = File(workingFilePath);
      
      if (!await file.exists()) {
        // Try to migrate path to current app container
        workingFilePath = await _tryMigrateFilePath(recording.filePath);
        file = File(workingFilePath);
        
        if (!await file.exists()) {
          throw Exception('Recording file not found: ${recording.filePath}');
        }
        
        debugPrint('📁 Migrated file path: ${recording.filePath} -> $workingFilePath');
      }
      
      // STEP 2: Validate file size
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('Recording file is empty: $workingFilePath');
      }
      
      debugPrint('📁 Validating file: $workingFilePath');
      debugPrint('📦 File size: $fileSize bytes');
      debugPrint('🎵 Expected format: ${recording.format.name}');

      // STEP 3: Setup audio player with working file path
      debugPrint('🔧 Setting up audio player...');
      await _audioPlayer!.setFilePath(workingFilePath);
      
      // STEP 4: Get actual audio properties from player
      final playerDuration = _audioPlayer!.duration;
      debugPrint('🎵 Audio file analysis:');
      debugPrint('   Player duration: ${playerDuration != null ? _formatTime(playerDuration) : 'null'} ${playerDuration != null ? '(${playerDuration.inMilliseconds}ms)' : ''}');
      debugPrint('   Metadata duration: ${_formatTime(recording.duration)} (${recording.duration.inMilliseconds}ms)');
      debugPrint('   Duration difference: ${playerDuration != null ? (playerDuration.inMilliseconds - recording.duration.inMilliseconds) : 'unknown'}ms');
      debugPrint('   Sample rate: ${recording.sampleRate} Hz');
      debugPrint('   Audio format: ${recording.format.name}');
      debugPrint('   File size: $fileSize bytes');

      _expandedRecordingId = recording.id;
      _currentlyPlayingFile = workingFilePath;
      _audioStateManager?.updateCurrentRecording(recording.id);
      _audioStateManager?.updatePosition(Duration.zero);
      // Start with recording duration, but audio player will update with actual duration
      _audioStateManager?.updateDuration(recording.duration);
      _audioStateManager?.updatePlaybackState(isPlaying: false, isBuffering: false);
      _isLoading = false;
      _hasCompletedCurrentPlayback = false; // Reset completion flag for new recording
      debugPrint('🎯 AUDIO_SVC: Calling _onExpansionChanged to trigger UI rebuild');
      if (_onExpansionChanged != null) {
        debugPrint('🔄 AUDIO_SVC: Executing expansion callback');
        _onExpansionChanged?.call();
      } else {
        debugPrint('❌ AUDIO_SVC: No expansion callback set!');
      }

      debugPrint('✅ Audio setup complete for: ${recording.name}');
      debugPrint('📁 Working file path: $workingFilePath');
      debugPrint('📦 File size: $fileSize bytes');
      debugPrint('🕒 Initial duration: ${_formatTime(_audioStateManager?.duration ?? Duration.zero)} (${_audioStateManager?.duration.inMilliseconds ?? 0}ms)');
      debugPrint('🕒 Recording metadata duration: ${_formatTime(recording.duration)} (${recording.duration.inMilliseconds}ms)');
      
      // If there's a significant difference, we might want to update the metadata
      if (playerDuration != null && (playerDuration.inMilliseconds - recording.duration.inMilliseconds).abs() > 500) {
        debugPrint('⚠️ Significant duration mismatch detected (>500ms difference)');
        debugPrint('   Player duration: ${playerDuration.inMilliseconds}ms');
        debugPrint('   Metadata duration: ${recording.duration.inMilliseconds}ms');
        debugPrint('   Consider updating recording metadata for accuracy');
      }
      
    } catch (e) {
      debugPrint('❌ Error setting up audio: $e');
      debugPrint('📁 Failed file path: ${recording.filePath}');
      
      _isLoading = false;
      _audioStateManager?.updateError(e.toString());
      
      // Return error message for UI to handle
      throw e;
    }
  }
  
  /// Try to migrate file path to current app container
  Future<String> _tryMigrateFilePath(String oldPath) async {
    try {
      // Get current app documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final currentDocumentsPath = documentsDir.path;
      
      // Extract the relative path from old path (everything after /Documents/)
      final documentsIndex = oldPath.indexOf('/Documents/');
      if (documentsIndex == -1) {
        return oldPath; // Return original if can't parse
      }
      
      final relativePath = oldPath.substring(documentsIndex + '/Documents/'.length);
      final newPath = path.join(currentDocumentsPath, relativePath);
      
      debugPrint('🔄 Attempting path migration:');
      debugPrint('   Old: $oldPath');
      debugPrint('   New: $newPath');
      debugPrint('   Relative: $relativePath');
      
      return newPath;
    } catch (e) {
      debugPrint('❌ Error migrating path: $e');
      return oldPath; // Return original on error
    }
  }
  
  /// Format time helper
  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  /// Get the currently expanded recording
  RecordingEntity? getCurrentlyExpandedRecording(List<RecordingEntity> recordings) {
    if (_expandedRecordingId == null) return null;
    
    try {
      return recordings.firstWhere((recording) => recording.id == _expandedRecordingId);
    } catch (e) {
      // Recording not found in current list - reset expansion state
      debugPrint('⚠️ AUDIO_SVC: Expanded recording ID $_expandedRecordingId not found in current recordings, resetting state');
      _expandedRecordingId = null;
      _audioStateManager?.reset();
      return null;
    }
  }
  
  // ==== PLAYBACK OPERATIONS ====

  /// Toggle playback (from AudioPlayerManager)
  Future<void> togglePlayback() async {
    try {
      if (_audioPlayer!.playing) {
        await pausePlaying();
      } else {
        // Reset completion flag when starting new playback
        _hasCompletedCurrentPlayback = false;
        
        // Handle completed state
        if ((_audioStateManager?.position ?? Duration.zero) >= (_audioStateManager?.duration ?? Duration.zero) && 
            (_audioStateManager?.duration ?? Duration.zero) > Duration.zero) {
          await seekTo(Duration.zero);
        }
        await resumePlaying();
      }
    } catch (e) {
      debugPrint('❌ Error toggling playback: $e');
    }
  }
  
  /// Seek to position with percentage
  void seekToPosition(double percent) {
    // CRITICAL: Remember current playback state before seeking
    final wasPlaying = _audioStateManager?.isPlaying ?? false;
    final effectiveDuration = _audioStateManager?.duration ?? const Duration(seconds: 1);
    final target = Duration(milliseconds: (effectiveDuration.inMilliseconds * percent).round());
    
    debugPrint('🎯 Seeking to position: ${_formatTime(target)} of ${_formatTime(effectiveDuration)} (was playing: $wasPlaying)');
    
    // Reset completion flag since user is manually seeking
    _hasCompletedCurrentPlayback = false;
    
    // Perform the seek
    seekTo(target);
    _audioStateManager?.seekTo(target); // Update state immediately for responsive UI
    
    // CRITICAL: Preserve playback state - if wasn't playing before seek, ensure it stays paused
    if (!wasPlaying && _audioPlayer != null) {
      debugPrint('🎯 Ensuring audio stays paused after seek (was not playing before)');
      _audioPlayer!.pause().then((_) {
        _audioStateManager?.updatePlaybackState(isPlaying: false);
        _onExpansionChanged?.call(); // Update UI to reflect paused state
      });
    } else if (wasPlaying) {
      debugPrint('🎯 Audio was playing before seek, maintaining playback');
    }
  }
  
  /// Skip backward 10 seconds
  void skipBackward() {
    final currentPos = _audioStateManager?.position ?? Duration.zero;
    final duration = _audioStateManager?.duration ?? Duration.zero;
    final newPosition = Duration(milliseconds: (currentPos.inMilliseconds - 10000).clamp(0, duration.inMilliseconds));
    seekTo(newPosition);
    _audioStateManager?.seekTo(newPosition);
  }
  
  /// Skip forward 10 seconds
  void skipForward() {
    final currentPos = _audioStateManager?.position ?? Duration.zero;
    final duration = _audioStateManager?.duration ?? Duration.zero;
    final newPosition = Duration(milliseconds: (currentPos.inMilliseconds + 10000).clamp(0, duration.inMilliseconds));
    seekTo(newPosition);
    _audioStateManager?.seekTo(newPosition);
  }
  
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
      _audioStateManager?.updatePosition(position); // Update AudioStateManager
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

  @override
  Stream<double>? get amplitudeStream => null; // Player service doesn't record

  @override
  Stream<Duration>? get durationStream => null; // Player service doesn't record

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
    debugPrint('⚠️ Audio trimming not yet implemented');
    return null;
  }

  @override
  Future<String?> mergeAudioFiles({
    required List<String> inputPaths,
    required String outputPath,
    required AudioFormat outputFormat,
  }) async {
    debugPrint('⚠️ Audio merging not yet implemented');
    return null;
  }

  @override
  Future<List<double>> getWaveformData(String filePath, {int sampleCount = 100}) async {
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

  // ==== PUBLIC GETTERS (Enhanced from AudioPlayerManager) ====
  
  /// Current expansion state
  String? get expandedRecordingId => _expandedRecordingId;
  
  /// Current loading state
  bool get isLoading => _isLoading;
  
  /// Audio state manager for UI optimization
  AudioStateManager? get audioState => _audioStateManager;
  
  /// Current position (from AudioStateManager or fallback)
  Duration get position => _audioStateManager?.position ?? _playbackPosition;
  
  /// Current duration (from AudioStateManager or fallback)
  Duration get duration => _audioStateManager?.duration ?? _playbackDuration;
  
  /// Is currently playing (from AudioStateManager or fallback)
  bool get isCurrentlyPlaying => _audioStateManager?.isPlaying ?? _playbackActive;
  
  /// Audio player instance (for direct access if needed)
  AudioPlayer? get audioPlayer => _audioPlayer;

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