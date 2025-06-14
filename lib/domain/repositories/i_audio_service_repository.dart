// File: domain/repositories/i_audio_service_repository.dart
import '../entities/recording_entity.dart';
import '../../core/enums/audio_format.dart';

/// Repository interface for audio recording and playback operations
///
/// Defines the contract for audio services while keeping the domain
/// layer independent of specific audio library implementations.
abstract class IAudioServiceRepository {

  // ==== RECORDING OPERATIONS ====

  /// Start recording audio with specified settings
  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
  });

  /// Stop current recording and return recording details
  Future<RecordingEntity?> stopRecording();

  /// Pause current recording
  Future<bool> pauseRecording();

  /// Resume paused recording
  Future<bool> resumeRecording();

  /// Cancel current recording (discard file)
  Future<bool> cancelRecording();

  /// Check if currently recording
  Future<bool> isRecording();

  /// Check if recording is paused
  Future<bool> isRecordingPaused();

  /// Get current recording duration
  Future<Duration> getCurrentRecordingDuration();

  /// Get current recording amplitude (for visualization)
  Stream<double> getRecordingAmplitudeStream();

  // ==== PLAYBACK OPERATIONS ====

  /// Start playing an audio file
  Future<bool> startPlaying(String filePath);

  /// Stop current playback
  Future<bool> stopPlaying();

  /// Pause current playback
  Future<bool> pausePlaying();

  /// Resume paused playback
  Future<bool> resumePlaying();

  /// Seek to specific position in playback
  Future<bool> seekTo(Duration position);

  /// Set playback speed (0.5x - 2.0x)
  Future<bool> setPlaybackSpeed(double speed);

  /// Set playback volume (0.0 - 1.0)
  Future<bool> setVolume(double volume);

  /// Check if currently playing
  Future<bool> isPlaying();

  /// Check if playback is paused
  Future<bool> isPlaybackPaused();

  /// Get current playback position
  Future<Duration> getCurrentPlaybackPosition();

  /// Get total duration of current audio file
  Future<Duration> getCurrentPlaybackDuration();

  /// Get playback position stream for real-time updates
  Stream<Duration> getPlaybackPositionStream();

  /// Get playback completion stream
  Stream<void> getPlaybackCompletionStream();

  // ==== AUDIO FILE OPERATIONS ====

  /// Get audio file information
  Future<AudioFileInfo?> getAudioFileInfo(String filePath);

  /// Convert audio file to different format
  Future<String?> convertAudioFile({
    required String inputPath,
    required String outputPath,
    required AudioFormat targetFormat,
    int? targetSampleRate,
    int? targetBitRate,
  });

  /// Trim audio file
  Future<String?> trimAudioFile({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
  });

  /// Merge multiple audio files
  Future<String?> mergeAudioFiles({
    required List<String> inputPaths,
    required String outputPath,
    required AudioFormat outputFormat,
  });

  /// Get audio file waveform data
  Future<List<double>> getWaveformData(String filePath, {int sampleCount = 100});

  // ==== DEVICE & PERMISSIONS ====

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission();

  /// Request microphone permission
  Future<bool> requestMicrophonePermission();

  /// Check if device has microphone
  Future<bool> hasMicrophone();

  /// Get available audio input devices
  Future<List<AudioInputDevice>> getAudioInputDevices();

  /// Set audio input device
  Future<bool> setAudioInputDevice(String deviceId);

  /// Get supported audio formats
  Future<List<AudioFormat>> getSupportedFormats();

  /// Get supported sample rates for format
  Future<List<int>> getSupportedSampleRates(AudioFormat format);

  // ==== SETTINGS & CONFIGURATION ====

  /// Initialize audio service
  Future<bool> initialize();

  /// Release audio service resources
  Future<void> dispose();

  /// Set audio session category (iOS)
  Future<bool> setAudioSessionCategory(AudioSessionCategory category);

  /// Enable background audio recording
  Future<bool> enableBackgroundRecording();

  /// Disable background audio recording
  Future<bool> disableBackgroundRecording();
}

/// Audio file information
class AudioFileInfo {
  final String filePath;
  final AudioFormat format;
  final Duration duration;
  final int fileSize;
  final int sampleRate;
  final int bitRate;
  final int channels;
  final DateTime createdAt;

  const AudioFileInfo({
    required this.filePath,
    required this.format,
    required this.duration,
    required this.fileSize,
    required this.sampleRate,
    required this.bitRate,
    required this.channels,
    required this.createdAt,
  });

  /// File size in human-readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Duration in human-readable format
  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Audio quality description
  String get qualityDescription {
    if (sampleRate >= 48000) return 'High Quality';
    if (sampleRate >= 44100) return 'CD Quality';
    if (sampleRate >= 22050) return 'Good Quality';
    return 'Basic Quality';
  }
}

/// Audio input device information
class AudioInputDevice {
  final String id;
  final String name;
  final bool isDefault;
  final bool isAvailable;

  const AudioInputDevice({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.isAvailable,
  });
}

/// Audio session categories (iOS)
enum AudioSessionCategory {
  ambient,
  soloAmbient,
  playback,
  record,
  playAndRecord,
  multiRoute,
}

/// Recording states for state management
enum RecordingState {
  idle,
  recording,
  paused,
  stopping,
  error,
}

/// Playback states for state management
enum PlaybackState {
  idle,
  loading,
  playing,
  paused,
  stopped,
  completed,
  error,
}

/// Audio service events
abstract class AudioServiceEvent {
  const AudioServiceEvent();
}

/// Recording events
class RecordingStartedEvent extends AudioServiceEvent {
  final String filePath;
  const RecordingStartedEvent(this.filePath);
}

class RecordingPausedEvent extends AudioServiceEvent {
  const RecordingPausedEvent();
}

class RecordingResumedEvent extends AudioServiceEvent {
  const RecordingResumedEvent();
}

class RecordingStoppedEvent extends AudioServiceEvent {
  final RecordingEntity recording;
  const RecordingStoppedEvent(this.recording);
}

class RecordingCancelledEvent extends AudioServiceEvent {
  const RecordingCancelledEvent();
}

class RecordingErrorEvent extends AudioServiceEvent {
  final String message;
  const RecordingErrorEvent(this.message);
}

/// Playback events
class PlaybackStartedEvent extends AudioServiceEvent {
  final String filePath;
  const PlaybackStartedEvent(this.filePath);
}

class PlaybackPausedEvent extends AudioServiceEvent {
  const PlaybackPausedEvent();
}

class PlaybackResumedEvent extends AudioServiceEvent {
  const PlaybackResumedEvent();
}

class PlaybackStoppedEvent extends AudioServiceEvent {
  const PlaybackStoppedEvent();
}

class PlaybackCompletedEvent extends AudioServiceEvent {
  const PlaybackCompletedEvent();
}

class PlaybackPositionChangedEvent extends AudioServiceEvent {
  final Duration position;
  const PlaybackPositionChangedEvent(this.position);
}

class PlaybackErrorEvent extends AudioServiceEvent {
  final String message;
  const PlaybackErrorEvent(this.message);
}