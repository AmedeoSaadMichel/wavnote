// File: lib/services/audio/i_audio_playback_engine.dart

import 'audio_playback_state.dart';

abstract class IAudioPlaybackEngine {
  Future<bool> initialize();
  Future<void> load(String filePath, {Duration? initialPosition});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);

  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<AudioPlaybackState> get playbackStateStream;
  Stream<void> get completionStream;
  Stream<double>
  get amplitudeStream; // Aggiunto per coerenza con il codice esistente

  Duration get currentPosition;
  Duration get currentDuration;
  String? get currentFilePath;
  bool get isLoaded;
  bool get isPlaying; // Aggiunto per coerenza con il codice esistente
  bool get isPlaybackPaused; // Aggiunto per coerenza con il codice esistente

  Future<void> dispose();
}
