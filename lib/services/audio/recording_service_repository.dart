// File: lib/services/audio/recording_service_repository.dart
import '../../core/enums/audio_format.dart';
import '../../domain/entities/recording_entity.dart';
import '../../domain/entities/recording_external_control_action.dart';
import '../../domain/entities/recording_waveform_bucket_batch.dart';
import '../../domain/repositories/i_audio_recording_repository.dart';
import 'audio_service_coordinator.dart';

/// Adapter pubblico per il layer dominio.
///
/// Espone le capacità di registrazione e helper file del coordinator
/// attraverso il contratto [IAudioRecordingRepository].
/// Il playback passa esclusivamente dal [RecordingPlaybackCoordinator].
class RecordingServiceRepository implements IAudioRecordingRepository {
  final AudioServiceCoordinator _coordinator;

  const RecordingServiceRepository({
    required AudioServiceCoordinator coordinator,
  }) : _coordinator = coordinator;

  @override
  Future<bool> initialize() => _coordinator.initialize();

  @override
  bool get needsDisposal => _coordinator.needsDisposal;

  @override
  Future<void> dispose() => _coordinator.dispose();

  @override
  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
    Duration initialElapsedOffset = Duration.zero,
  }) => _coordinator.startRecording(
    filePath: filePath,
    format: format,
    sampleRate: sampleRate,
    bitRate: bitRate,
    initialElapsedOffset: initialElapsedOffset,
  );

  @override
  Future<RecordingEntity?> stopRecording({bool raw = false}) =>
      _coordinator.stopRecording(raw: raw);

  @override
  Future<bool> pauseRecording() => _coordinator.pauseRecording();

  @override
  Future<bool> resumeRecording() => _coordinator.resumeRecording();

  @override
  Future<bool> cancelRecording() => _coordinator.cancelRecording();

  @override
  Future<bool> isRecording() => _coordinator.isRecording();

  @override
  Future<bool> isRecordingPaused() => _coordinator.isRecordingPaused();

  @override
  Future<Duration> getCurrentRecordingDuration() =>
      _coordinator.getCurrentRecordingDuration();

  @override
  Future<void> syncNativeRecordingStatus() =>
      _coordinator.syncNativeRecordingStatus();

  @override
  Stream<double> getRecordingAmplitudeStream() =>
      _coordinator.getRecordingAmplitudeStream();

  @override
  Stream<RecordingWaveformBucketBatch> getRecordingWaveformBucketStream() =>
      _coordinator.getRecordingWaveformBucketStream();

  @override
  Stream<Duration>? get durationStream => _coordinator.durationStream;

  @override
  Stream<RecordingExternalControlEvent> get externalControlStream =>
      _coordinator.externalControlStream;

  @override
  Future<String?> convertAudioFile({
    required String inputPath,
    required String outputPath,
    required AudioFormat targetFormat,
    int? targetSampleRate,
    int? targetBitRate,
  }) => _coordinator.convertAudioFile(
    inputPath: inputPath,
    outputPath: outputPath,
    targetFormat: targetFormat,
    targetSampleRate: targetSampleRate,
    targetBitRate: targetBitRate,
  );

  @override
  Future<Duration> getAudioDuration(String filePath) =>
      _coordinator.getAudioDuration(filePath);

  @override
  Future<bool> hasMicrophonePermission() =>
      _coordinator.hasMicrophonePermission();

  @override
  Future<bool> requestMicrophonePermission() =>
      _coordinator.requestMicrophonePermission();

  @override
  Future<bool> hasMicrophone() => _coordinator.hasMicrophone();
}
