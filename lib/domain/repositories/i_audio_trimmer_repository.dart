// File: domain/repositories/i_audio_trimmer_repository.dart
abstract class IAudioTrimmerRepository {
  Future<void> trimAudio({
    required String filePath,
    required int durationMs,
    required String format,
    required String outputPath,
  });

  Future<void> concatenateAudio({
    required String basePath,
    required String appendPath,
    required String outputPath,
    required String format,
  });
}
