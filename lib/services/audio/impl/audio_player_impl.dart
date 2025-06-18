// File: services/audio/impl/audio_player_impl.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../../core/utils/file_utils.dart';

/// Core audio playback implementation using flutter_sound
///
/// Handles audio playback operations separately from recording.
/// Focused on playback functionality only.
class AudioPlayerImpl {

  // Flutter Sound player
  FlutterSoundPlayer? _player;

  // Stream controllers
  StreamController<Duration>? _positionController;
  StreamController<void>? _completionController;

  // Playback state
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isPlaybackPaused = false;
  Timer? _positionTimer;

  // ==== INITIALIZATION ====

  Future<bool> initialize() async {
    try {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();

      _positionController = StreamController<Duration>.broadcast();
      _completionController = StreamController<void>.broadcast();

      _isInitialized = true;
      debugPrint('✅ Audio player initialized');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to initialize audio player: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    try {
      if (_isPlaying) {
        await stopPlaying();
      }

      _positionTimer?.cancel();
      await _player?.closePlayer();
      await _positionController?.close();
      await _completionController?.close();

      _isInitialized = false;
      debugPrint('✅ Audio player disposed');

    } catch (e) {
      debugPrint('❌ Error disposing audio player: $e');
    }
  }

  // ==== PLAYBACK OPERATIONS ====

  Future<bool> startPlaying(String filePath) async {
    if (!_isInitialized || _player == null) {
      return false;
    }

    try {
      final absolutePath = await FileUtils.getAbsolutePath(filePath);

      if (!await FileUtils.fileExists(absolutePath)) {
        debugPrint('❌ Audio file not found: $absolutePath');
        return false;
      }

      await _player!.startPlayer(
        fromURI: absolutePath,
        whenFinished: () {
          _isPlaying = false;
          _isPlaybackPaused = false;
          _positionTimer?.cancel();
          _completionController?.add(null);
        },
      );

      _isPlaying = true;
      _isPlaybackPaused = false;

      // Start position monitoring
      _startPositionMonitoring();

      debugPrint('▶️ Playback started: $absolutePath');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to start playback: $e');
      return false;
    }
  }

  Future<bool> stopPlaying() async {
    if (!_isPlaying || _player == null) {
      return false;
    }

    try {
      await _player!.stopPlayer();

      _isPlaying = false;
      _isPlaybackPaused = false;
      _positionTimer?.cancel();

      debugPrint('⏹️ Playback stopped');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to stop playback: $e');
      return false;
    }
  }

  Future<bool> pausePlaying() async {
    if (!_isPlaying || _isPlaybackPaused || _player == null) {
      return false;
    }

    try {
      await _player!.pausePlayer();
      _isPlaybackPaused = true;

      debugPrint('⏸️ Playback paused');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to pause playback: $e');
      return false;
    }
  }

  Future<bool> resumePlaying() async {
    if (!_isPlaying || !_isPlaybackPaused || _player == null) {
      return false;
    }

    try {
      await _player!.resumePlayer();
      _isPlaybackPaused = false;

      debugPrint('▶️ Playback resumed');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to resume playback: $e');
      return false;
    }
  }

  Future<bool> seekTo(Duration position) async {
    if (!_isPlaying || _player == null) {
      return false;
    }

    try {
      await _player!.seekToPlayer(position);
      return true;
    } catch (e) {
      debugPrint('❌ Failed to seek: $e');
      return false;
    }
  }

  Future<bool> setPlaybackSpeed(double speed) async {
    if (!_isPlaying || _player == null) {
      return false;
    }

    try {
      await _player!.setSpeed(speed);
      return true;
    } catch (e) {
      debugPrint('❌ Failed to set playback speed: $e');
      return false;
    }
  }

  Future<bool> setVolume(double volume) async {
    if (_player == null) {
      return false;
    }

    try {
      await _player!.setVolume(volume);
      return true;
    } catch (e) {
      debugPrint('❌ Failed to set volume: $e');
      return false;
    }
  }

  // ==== STATE GETTERS ====

  bool get isPlaying => _isPlaying && !_isPlaybackPaused;
  bool get isPlaybackPaused => _isPlaybackPaused;
  bool get isInitialized => _isInitialized;

  Future<Duration> getCurrentPlaybackPosition() async {
    if (_player == null) return Duration.zero;

    try {
      // Simplified for now - in real implementation use player position
      return Duration.zero;
    } catch (e) {
      return Duration.zero;
    }
  }

  Future<Duration> getCurrentPlaybackDuration() async {
    if (_player == null) return Duration.zero;

    try {
      // Simplified for now - in real implementation use audio file duration
      return const Duration(minutes: 1);
    } catch (e) {
      return Duration.zero;
    }
  }

  // ==== STREAMS ====

  Stream<Duration> get positionStream =>
      _positionController?.stream ?? const Stream.empty();

  Stream<void> get completionStream =>
      _completionController?.stream ?? const Stream.empty();

  // ==== PRIVATE HELPERS ====

  void _startPositionMonitoring() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }

      try {
        // Simplified position monitoring
        _positionController?.add(Duration.zero);
      } catch (e) {
        // Ignore position errors
      }
    });
  }
}