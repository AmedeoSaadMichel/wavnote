// File: services/audio/impl/audio_player_impl.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/utils/file_utils.dart';

/// Core audio playback implementation using [just_audio].
///
/// Handles playback operations separately from recording.
/// Exposes streams for position and completion events.
class AudioPlayerImpl {

  final AudioPlayer _player = AudioPlayer();

  StreamController<Duration>? _positionController;
  StreamController<void>? _completionController;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isPlaybackPaused = false;

  // ==== INITIALIZATION ====

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _positionController = StreamController<Duration>.broadcast();
      _completionController = StreamController<void>.broadcast();

      // Forward just_audio position updates
      _positionSubscription = _player.positionStream.listen(
        (pos) => _positionController?.add(pos),
        onError: (_) {},
      );

      // Detect playback completion
      _stateSubscription = _player.playerStateStream.listen(
        (state) {
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _isPlaybackPaused = false;
            _completionController?.add(null);
          }
        },
        onError: (_) {},
      );

      _isInitialized = true;
      debugPrint('✅ AudioPlayerImpl initialized');
      return true;

    } catch (e) {
      debugPrint('❌ AudioPlayerImpl init failed: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    try {
      if (_isPlaying) await stopPlaying();
      _positionSubscription?.cancel();
      _stateSubscription?.cancel();
      await _player.dispose();
      await _positionController?.close();
      await _completionController?.close();
      _isInitialized = false;
      debugPrint('✅ AudioPlayerImpl disposed');
    } catch (e) {
      debugPrint('❌ AudioPlayerImpl dispose error: $e');
    }
  }

  // ==== PLAYBACK ====

  Future<bool> startPlaying(String filePath) async {
    if (!_isInitialized) return false;
    try {
      final absolutePath = await FileUtils.getAbsolutePath(filePath);
      if (!await FileUtils.fileExists(absolutePath)) {
        debugPrint('❌ AudioPlayerImpl: file not found — $absolutePath');
        return false;
      }

      await _player.setFilePath(absolutePath);
      await _player.play();
      _isPlaying = true;
      _isPlaybackPaused = false;

      debugPrint('▶️ AudioPlayerImpl: playback started — $absolutePath');
      return true;

    } catch (e) {
      debugPrint('❌ AudioPlayerImpl: startPlaying failed: $e');
      return false;
    }
  }

  Future<bool> stopPlaying() async {
    if (!_isPlaying) return false;
    try {
      await _player.stop();
      _isPlaying = false;
      _isPlaybackPaused = false;
      debugPrint('⏹️ AudioPlayerImpl: stopped');
      return true;
    } catch (e) {
      debugPrint('❌ AudioPlayerImpl: stopPlaying failed: $e');
      return false;
    }
  }

  Future<bool> pausePlaying() async {
    if (!_isPlaying || _isPlaybackPaused) return false;
    try {
      await _player.pause();
      _isPlaybackPaused = true;
      debugPrint('⏸️ AudioPlayerImpl: paused');
      return true;
    } catch (e) {
      debugPrint('❌ AudioPlayerImpl: pause failed: $e');
      return false;
    }
  }

  Future<bool> resumePlaying() async {
    if (!_isPlaybackPaused) return false;
    try {
      await _player.play();
      _isPlaybackPaused = false;
      debugPrint('▶️ AudioPlayerImpl: resumed');
      return true;
    } catch (e) {
      debugPrint('❌ AudioPlayerImpl: resume failed: $e');
      return false;
    }
  }

  Future<bool> seekTo(Duration position) async {
    try {
      await _player.seek(position);
      return true;
    } catch (e) {
      debugPrint('❌ AudioPlayerImpl: seek failed: $e');
      return false;
    }
  }

  Future<bool> setPlaybackSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      return true;
    } catch (e) {
      debugPrint('❌ AudioPlayerImpl: setSpeed failed: $e');
      return false;
    }
  }

  Future<bool> setVolume(double volume) async {
    try {
      await _player.setVolume(volume);
      return true;
    } catch (e) {
      debugPrint('❌ AudioPlayerImpl: setVolume failed: $e');
      return false;
    }
  }

  // ==== STATE ====

  bool get isPlaying => _isPlaying && !_isPlaybackPaused;
  bool get isPlaybackPaused => _isPlaybackPaused;
  bool get isInitialized => _isInitialized;

  Future<Duration> getCurrentPlaybackPosition() async =>
      _player.position;

  Future<Duration> getCurrentPlaybackDuration() async =>
      _player.duration ?? Duration.zero;

  // ==== STREAMS ====

  Stream<Duration> get positionStream =>
      _positionController?.stream ?? const Stream.empty();

  Stream<void> get completionStream =>
      _completionController?.stream ?? const Stream.empty();
}
