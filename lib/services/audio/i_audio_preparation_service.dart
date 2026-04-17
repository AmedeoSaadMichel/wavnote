// File: lib/services/audio/i_audio_preparation_service.dart
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'audio_preparation_result.dart';

abstract class IAudioPreparationService {
  Future<AudioPreparationResult> prepare(RecordingEntity recording);
  bool isPrepared(String filePath);
  Future<void> clearPrepared(String filePath);
  Future<void> clearAll();
  Future<void> dispose(); // Per gestire la lifecycle del servizio
}
