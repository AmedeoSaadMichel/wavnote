// File: domain/repositories/i_audio_recording_repository.dart
import '../entities/recording_entity.dart';
import '../entities/recording_external_control_action.dart';
import '../../core/enums/audio_format.dart';

/// Contratto per le operazioni di registrazione audio.
///
/// Usato da [RecordingBloc] e dal layer di presentazione.
/// Le operazioni di playback passano da [IAudioPlaybackEngine] / [RecordingPlaybackCoordinator].
abstract class IAudioRecordingRepository {
  Future<bool> initialize();
  bool get needsDisposal;
  Future<void> dispose();

  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
    Duration initialElapsedOffset = Duration.zero,
  });

  Future<RecordingEntity?> stopRecording({bool raw = false});
  Future<bool> pauseRecording();
  Future<bool> resumeRecording();
  Future<bool> cancelRecording();
  Future<bool> isRecording();
  Future<bool> isRecordingPaused();
  Future<Duration> getCurrentRecordingDuration();

  Stream<double> getRecordingAmplitudeStream();
  Stream<Duration>? get durationStream;
  Stream<RecordingExternalControlAction> get externalControlStream;

  Future<String?> convertAudioFile({
    required String inputPath,
    required String outputPath,
    required AudioFormat targetFormat,
    int? targetSampleRate,
    int? targetBitRate,
  });

  Future<Duration> getAudioDuration(String filePath);

  Future<bool> hasMicrophonePermission();
  Future<bool> requestMicrophonePermission();
  Future<bool> hasMicrophone();
}
