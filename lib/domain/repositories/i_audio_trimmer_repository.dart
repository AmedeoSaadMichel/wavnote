// File: domain/repositories/i_audio_trimmer_repository.dart
abstract class IAudioTrimmerRepository {
  Future<void> trimAudio({
    required String filePath,
    required Duration startTime,
    required Duration endTime,
    required String format,
    required String outputPath,
  });

  Future<void> concatenateAudio({
    required String basePath,
    required String appendPath,
    required String outputPath,
    required String format,
  });

  Future<void> overwriteAudioSegment({
    required String originalPath,
    required String insertionPath,
    required Duration startTime,
    required Duration overwriteDuration,
    required String outputPath,
    required String format,
  });
}
