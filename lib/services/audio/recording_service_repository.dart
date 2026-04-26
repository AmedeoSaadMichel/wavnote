// File: lib/services/audio/recording_service_repository.dart
import '../../core/enums/audio_format.dart';
import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_audio_service_repository.dart';
import 'audio_service_coordinator.dart';

/// Adapter pubblico per il layer dominio.
///
/// Espone solo le capacità di registrazione/file ops del coordinator.
/// Le vecchie API di playback restano intenzionalmente non supportate:
/// il playback passa dal `RecordingPlaybackCoordinator`.
class RecordingServiceRepository implements IAudioServiceRepository {
  final AudioServiceCoordinator _coordinator;

  const RecordingServiceRepository({
    required AudioServiceCoordinator coordinator,
  }) : _coordinator = coordinator;

  Never _unsupportedPlayback() {
    throw UnsupportedError(
      'Il playback non è più supportato via IAudioServiceRepository. '
      'Usare RecordingPlaybackCoordinator/IAudioPlaybackEngine.',
    );
  }

  @override
  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
  }) => _coordinator.startRecording(
    filePath: filePath,
    format: format,
    sampleRate: sampleRate,
    bitRate: bitRate,
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
  Stream<double> getRecordingAmplitudeStream() =>
      _coordinator.getRecordingAmplitudeStream();

  @override
  Stream<double>? get amplitudeStream => _coordinator.amplitudeStream;

  @override
  Stream<Duration>? get durationStream => _coordinator.durationStream;

  @override
  Future<double> getCurrentAmplitude() => _coordinator.getCurrentAmplitude();

  @override
  Future<bool> startPlaying(
    String filePath, {
    Duration? initialPosition,
  }) async => _unsupportedPlayback();

  @override
  Future<bool> stopPlaying() async => _unsupportedPlayback();

  @override
  Future<bool> pausePlaying() async => _unsupportedPlayback();

  @override
  Future<bool> resumePlaying() async => _unsupportedPlayback();

  @override
  Future<bool> seekTo(Duration position) async => _unsupportedPlayback();

  @override
  Future<bool> setPlaybackSpeed(double speed) async => _unsupportedPlayback();

  @override
  Future<bool> setVolume(double volume) async => _unsupportedPlayback();

  @override
  Future<bool> isPlaying() async => _unsupportedPlayback();

  @override
  Future<bool> isPlaybackPaused() async => _unsupportedPlayback();

  @override
  Future<Duration> getCurrentPlaybackPosition() async => _unsupportedPlayback();

  @override
  Future<Duration> getCurrentPlaybackDuration() async => _unsupportedPlayback();

  @override
  Stream<Duration> getPlaybackPositionStream() => _unsupportedPlayback();

  @override
  Stream<void> getPlaybackCompletionStream() => _unsupportedPlayback();

  @override
  Future<AudioFileInfo?> getAudioFileInfo(String filePath) =>
      _coordinator.getAudioFileInfo(filePath);

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
  Future<String?> trimAudioFile({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
  }) => _coordinator.trimAudioFile(
    inputPath: inputPath,
    outputPath: outputPath,
    startTime: startTime,
    endTime: endTime,
  );

  @override
  Future<String?> mergeAudioFiles({
    required List<String> inputPaths,
    required String outputPath,
    required AudioFormat outputFormat,
  }) => _coordinator.mergeAudioFiles(
    inputPaths: inputPaths,
    outputPath: outputPath,
    outputFormat: outputFormat,
  );

  @override
  Future<List<double>> getWaveformData(
    String filePath, {
    int sampleCount = 100,
  }) => _coordinator.getWaveformData(filePath, sampleCount: sampleCount);

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

  @override
  Future<List<AudioInputDevice>> getAudioInputDevices() =>
      _coordinator.getAudioInputDevices();

  @override
  Future<bool> setAudioInputDevice(String deviceId) =>
      _coordinator.setAudioInputDevice(deviceId);

  @override
  Future<List<AudioFormat>> getSupportedFormats() =>
      _coordinator.getSupportedFormats();

  @override
  Future<List<int>> getSupportedSampleRates(AudioFormat format) =>
      _coordinator.getSupportedSampleRates(format);

  @override
  Future<bool> initialize() => _coordinator.initialize();

  @override
  bool get needsDisposal => _coordinator.needsDisposal;

  @override
  Future<void> dispose() => _coordinator.dispose();

  @override
  Future<bool> setAudioSessionCategory(AudioSessionCategory category) =>
      _coordinator.setAudioSessionCategory(category);

  @override
  Future<bool> enableBackgroundRecording() =>
      _coordinator.enableBackgroundRecording();

  @override
  Future<bool> disableBackgroundRecording() =>
      _coordinator.disableBackgroundRecording();
}
