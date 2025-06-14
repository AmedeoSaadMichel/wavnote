// File: services/audio/audio_recorder_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';  // ✅ Added for debugPrint
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_audio_service_repository.dart';
import '../../core/enums/audio_format.dart';

/// Simplified audio recording service
///
/// Basic implementation without flutter_sound for now
/// This allows the app to compile and you can add flutter_sound later
class AudioRecorderService implements IAudioServiceRepository {
  StreamController<double>? _amplitudeController;
  StreamController<Duration>? _positionController;
  StreamController<void>? _completionController;

  Timer? _mockTimer;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  int _currentSampleRate = 44100; // ✅ Store sample rate

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isPlaying = false;

  // ==== INITIALIZATION ====

  @override
  Future<bool> initialize() async {
    try {
      // Initialize stream controllers
      _amplitudeController = StreamController<double>.broadcast();
      _positionController = StreamController<Duration>.broadcast();
      _completionController = StreamController<void>.broadcast();

      _isInitialized = true;
      debugPrint('✅ Audio service initialized (simplified mode)');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to initialize audio service: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      _mockTimer?.cancel();

      await _amplitudeController?.close();
      await _positionController?.close();
      await _completionController?.close();

      _isInitialized = false;
      debugPrint('✅ Audio service disposed');

    } catch (e) {
      debugPrint('❌ Error disposing audio service: $e');
    }
  }

  // ==== RECORDING OPERATIONS ====

  @override
  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
  }) async {
    if (!_isInitialized) {
      debugPrint('❌ Audio service not initialized');
      return false;
    }

    if (_isRecording) {
      debugPrint('❌ Already recording');
      return false;
    }

    try {
      // Create directory if it doesn't exist
      final file = File(await _getFullPath(filePath));
      await file.parent.create(recursive: true);

      // Create empty file (mock recording)
      await file.writeAsString('Mock recording data');

      _currentRecordingPath = file.path;
      _recordingStartTime = DateTime.now();
      _currentSampleRate = sampleRate; // ✅ Store sample rate
      _isRecording = true;

      // Start mock amplitude monitoring
      _startMockAmplitudeMonitoring();

      debugPrint('✅ Mock recording started: ${file.path}');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to start recording: $e');
      return false;
    }
  }

  @override
  Future<RecordingEntity?> stopRecording() async {
    if (!_isRecording || _currentRecordingPath == null) {
      debugPrint('❌ No active recording to stop');
      return null;
    }

    try {
      // Stop mock monitoring
      _stopMockAmplitudeMonitoring();
      _isRecording = false;

      // Get file info
      final file = File(_currentRecordingPath!);
      if (!await file.exists()) {
        debugPrint('❌ Recording file not found');
        return null;
      }

      final fileSize = await file.length();
      final duration = DateTime.now().difference(_recordingStartTime!);

      // Create recording entity
      final recording = RecordingEntity.create(
        name: _generateDefaultName(),
        filePath: _currentRecordingPath!,
        folderId: 'all_recordings',
        format: _getFormatFromPath(_currentRecordingPath!),
        duration: duration,
        fileSize: fileSize,
        sampleRate: _currentSampleRate, // ✅ Use stored sample rate
      );

      _currentRecordingPath = null;
      _recordingStartTime = null;

      debugPrint('✅ Mock recording stopped: ${recording.name}');
      return recording;

    } catch (e) {
      debugPrint('❌ Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  @override
  Future<bool> pauseRecording() async {
    if (!_isRecording) return false;
    _stopMockAmplitudeMonitoring();
    debugPrint('⏸️ Mock recording paused');
    return true;
  }

  @override
  Future<bool> resumeRecording() async {
    if (!_isRecording) return false;
    _startMockAmplitudeMonitoring();
    debugPrint('▶️ Mock recording resumed');
    return true;
  }

  @override
  Future<bool> cancelRecording() async {
    if (!_isRecording) return false;

    try {
      _stopMockAmplitudeMonitoring();
      _isRecording = false;

      // Delete the file
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _currentRecordingPath = null;
      _recordingStartTime = null;

      debugPrint('🚫 Mock recording cancelled');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to cancel recording: $e');
      return false;
    }
  }

  @override
  Future<bool> isRecording() async => _isRecording;

  @override
  Future<bool> isRecordingPaused() async => false; // Simplified

  @override
  Future<Duration> getCurrentRecordingDuration() async {
    if (!_isRecording || _recordingStartTime == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(_recordingStartTime!);
  }

  @override
  Stream<double> getRecordingAmplitudeStream() {
    return _amplitudeController?.stream ?? const Stream.empty();
  }

  // ==== PLAYBACK OPERATIONS (Simplified) ====

  @override
  Future<bool> startPlaying(String filePath) async {
    _isPlaying = true;
    debugPrint('▶️ Mock playback started');
    return true;
  }

  @override
  Future<bool> stopPlaying() async {
    _isPlaying = false;
    debugPrint('⏹️ Mock playback stopped');
    return true;
  }

  @override
  Future<bool> pausePlaying() async {
    debugPrint('⏸️ Mock playback paused');
    return true;
  }

  @override
  Future<bool> resumePlaying() async {
    debugPrint('▶️ Mock playback resumed');
    return true;
  }

  @override
  Future<bool> seekTo(Duration position) async => true;

  @override
  Future<bool> setPlaybackSpeed(double speed) async => true;

  @override
  Future<bool> setVolume(double volume) async => true;

  @override
  Future<bool> isPlaying() async => _isPlaying;

  @override
  Future<bool> isPlaybackPaused() async => false;

  @override
  Future<Duration> getCurrentPlaybackPosition() async => Duration.zero;

  @override
  Future<Duration> getCurrentPlaybackDuration() async => const Duration(minutes: 1);

  @override
  Stream<Duration> getPlaybackPositionStream() {
    return _positionController?.stream ?? const Stream.empty();
  }

  @override
  Stream<void> getPlaybackCompletionStream() {
    return _completionController?.stream ?? const Stream.empty();
  }

  // ==== PERMISSIONS & DEVICE ====

  @override
  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status == PermissionStatus.granted;
  }

  @override
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  @override
  Future<bool> hasMicrophone() async => true;

  @override
  Future<List<AudioInputDevice>> getAudioInputDevices() async {
    return [
      const AudioInputDevice(
        id: 'default',
        name: 'Default Microphone',
        isDefault: true,
        isAvailable: true,
      ),
    ];
  }

  @override
  Future<bool> setAudioInputDevice(String deviceId) async => true;

  @override
  Future<List<AudioFormat>> getSupportedFormats() async {
    if (Platform.isIOS) {
      return [AudioFormat.m4a, AudioFormat.wav];
    } else {
      return [AudioFormat.wav, AudioFormat.m4a];
    }
  }

  @override
  Future<List<int>> getSupportedSampleRates(AudioFormat format) async {
    return format.supportedSampleRates;
  }

  // ==== AUDIO FILE OPERATIONS (Stubs) ====

  @override
  Future<AudioFileInfo?> getAudioFileInfo(String filePath) async {
    try {
      final file = File(await _getFullPath(filePath));
      if (!await file.exists()) return null;

      final fileSize = await file.length();
      final format = _getFormatFromPath(filePath);
      final stat = await file.stat();

      return AudioFileInfo(
        filePath: filePath,
        format: format,
        duration: const Duration(minutes: 1),
        fileSize: fileSize,
        sampleRate: 44100,
        bitRate: 128000,
        channels: 1,
        createdAt: stat.changed,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> convertAudioFile({
    required String inputPath,
    required String outputPath,
    required AudioFormat targetFormat,
    int? targetSampleRate,
    int? targetBitRate,
  }) async => null;

  @override
  Future<String?> trimAudioFile({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
  }) async => null;

  @override
  Future<String?> mergeAudioFiles({
    required List<String> inputPaths,
    required String outputPath,
    required AudioFormat outputFormat,
  }) async => null;

  @override
  Future<List<double>> getWaveformData(String filePath, {int sampleCount = 100}) async {
    return List.generate(sampleCount, (index) => 0.5);
  }

  @override
  Future<bool> setAudioSessionCategory(AudioSessionCategory category) async => true;

  @override
  Future<bool> enableBackgroundRecording() async => true;

  @override
  Future<bool> disableBackgroundRecording() async => true;

  // ==== PRIVATE HELPER METHODS ====

  /// Start mock amplitude monitoring for visualization
  void _startMockAmplitudeMonitoring() {
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isRecording) {
        // Generate mock amplitude data
        final amplitude = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
        _amplitudeController?.add(amplitude.clamp(0.0, 1.0));
      }
    });
  }

  /// Stop mock amplitude monitoring
  void _stopMockAmplitudeMonitoring() {
    _mockTimer?.cancel();
    _amplitudeController?.add(0.0);
  }

  /// Get full file system path
  Future<String> _getFullPath(String relativePath) async {
    if (relativePath.startsWith('/')) {
      return relativePath;
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    return '${documentsDir.path}/$relativePath';
  }

  /// Get audio format from file path
  AudioFormat _getFormatFromPath(String path) {
    final extension = path.toLowerCase().split('.').last;
    switch (extension) {
      case 'wav':
        return AudioFormat.wav;
      case 'm4a':
        return AudioFormat.m4a;
      case 'flac':
        return AudioFormat.flac;
      default:
        return AudioFormat.wav;
    }
  }

  /// Generate default recording name
  String _generateDefaultName() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    return 'Recording $dateStr $timeStr';
  }
}