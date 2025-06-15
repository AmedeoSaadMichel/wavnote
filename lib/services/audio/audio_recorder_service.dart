// File: services/audio/audio_recorder_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_audio_service_repository.dart';
import '../../core/enums/audio_format.dart';

/// Simplified audio recording service for WavNote
///
/// Focuses on providing a working recording interface with mock functionality
/// that can be enhanced with real audio recording later.
/// This version avoids flutter_sound API compatibility issues.
class AudioRecorderService implements IAudioServiceRepository {

  // Stream controllers for real-time updates
  StreamController<double>? _amplitudeController;
  StreamController<Duration>? _positionController;
  StreamController<void>? _completionController;

  // Recording state
  Timer? _amplitudeTimer;
  Timer? _durationTimer;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;

  // Recording settings
  int _currentSampleRate = 44100;
  int _currentBitRate = 128000;
  AudioFormat _currentFormat = AudioFormat.m4a;

  // Service state
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  bool _isPlaying = false;
  bool _isPlaybackPaused = false;

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
      _amplitudeTimer?.cancel();
      _durationTimer?.cancel();

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
      // Store settings
      _currentFormat = format;
      _currentSampleRate = sampleRate;
      _currentBitRate = bitRate;

      // Get full file path
      final fullPath = await _getFullPath(filePath);
      final file = File(fullPath);
      await file.parent.create(recursive: true);

      // Create a mock audio file with some metadata
      await _createMockAudioFile(file, format);

      _currentRecordingPath = fullPath;
      _recordingStartTime = DateTime.now();
      _pausedDuration = Duration.zero;
      _isRecording = true;
      _isRecordingPaused = false;

      // Start mock amplitude monitoring
      _startAmplitudeMonitoring();

      // Start duration monitoring
      _startDurationMonitoring();

      debugPrint('✅ Recording started (mock): $fullPath');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to start recording: $e');
      _isRecording = false;
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
      // Stop monitoring
      _stopAmplitudeMonitoring();
      _stopDurationMonitoring();

      // Calculate total duration
      final totalDuration = _calculateTotalRecordingDuration();

      _isRecording = false;
      _isRecordingPaused = false;

      // Get file info
      final file = File(_currentRecordingPath!);
      if (!await file.exists()) {
        debugPrint('❌ Recording file not found');
        return null;
      }

      // Update file with duration info
      await _updateMockAudioFile(file, totalDuration);
      final fileSize = await file.length();

      // Create recording entity
      final recording = RecordingEntity.create(
        name: _generateDefaultName(),
        filePath: _currentRecordingPath!,
        folderId: 'all_recordings',
        format: _currentFormat,
        duration: totalDuration,
        fileSize: fileSize,
        sampleRate: _currentSampleRate,
      );

      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pausedDuration = Duration.zero;

      debugPrint('✅ Recording stopped (mock): ${recording.name}');
      return recording;

    } catch (e) {
      debugPrint('❌ Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  @override
  Future<bool> pauseRecording() async {
    if (!_isRecording || _isRecordingPaused) return false;

    try {
      _isRecordingPaused = true;
      _pauseStartTime = DateTime.now();
      _stopAmplitudeMonitoring();

      debugPrint('⏸️ Recording paused (mock)');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to pause recording: $e');
      return false;
    }
  }

  @override
  Future<bool> resumeRecording() async {
    if (!_isRecording || !_isRecordingPaused) return false;

    try {
      // Add paused time to total paused duration
      if (_pauseStartTime != null) {
        _pausedDuration += DateTime.now().difference(_pauseStartTime!);
        _pauseStartTime = null;
      }

      _isRecordingPaused = false;
      _startAmplitudeMonitoring();

      debugPrint('▶️ Recording resumed (mock)');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to resume recording: $e');
      return false;
    }
  }

  @override
  Future<bool> cancelRecording() async {
    if (!_isRecording) return false;

    try {
      _stopAmplitudeMonitoring();
      _stopDurationMonitoring();

      _isRecording = false;
      _isRecordingPaused = false;

      // Delete the file
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pausedDuration = Duration.zero;
      _pauseStartTime = null;

      debugPrint('🚫 Recording cancelled (mock)');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to cancel recording: $e');
      return false;
    }
  }

  @override
  Future<bool> isRecording() async => _isRecording && !_isRecordingPaused;

  @override
  Future<bool> isRecordingPaused() async => _isRecordingPaused;

  @override
  Future<Duration> getCurrentRecordingDuration() async {
    return _calculateTotalRecordingDuration();
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
    _isPlaybackPaused = true;
    debugPrint('⏸️ Mock playback paused');
    return true;
  }

  @override
  Future<bool> resumePlaying() async {
    _isPlaybackPaused = false;
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
  Future<bool> isPlaying() async => _isPlaying && !_isPlaybackPaused;

  @override
  Future<bool> isPlaybackPaused() async => _isPlaybackPaused;

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

  // ==== AUDIO FILE OPERATIONS ====

  @override
  Future<AudioFileInfo?> getAudioFileInfo(String filePath) async {
    try {
      final file = File(await _getFullPath(filePath));
      if (!await file.exists()) return null;

      final fileSize = await file.length();
      final format = _getFormatFromPath(filePath);
      final stat = await file.stat();

      // Try to get duration from mock file content
      Duration duration = const Duration(seconds: 30);
      try {
        final content = await file.readAsString();
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.startsWith('Duration:')) {
            final durationStr = line.split(':')[1].trim();
            final seconds = int.tryParse(durationStr) ?? 30;
            duration = Duration(seconds: seconds);
            break;
          }
        }
      } catch (e) {
        // Use default duration
      }

      return AudioFileInfo(
        filePath: filePath,
        format: format,
        duration: duration,
        fileSize: fileSize,
        sampleRate: _currentSampleRate,
        bitRate: _currentBitRate,
        channels: 1,
        createdAt: stat.changed,
      );
    } catch (e) {
      debugPrint('❌ Error getting audio file info: $e');
      return null;
    }
  }

  // Stub implementations for advanced features
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
    // Generate mock waveform data
    final random = math.Random(42);
    return List.generate(sampleCount, (index) => random.nextDouble());
  }

  @override
  Future<bool> setAudioSessionCategory(AudioSessionCategory category) async => true;

  @override
  Future<bool> enableBackgroundRecording() async => true;

  @override
  Future<bool> disableBackgroundRecording() async => true;

  // ==== PRIVATE HELPER METHODS ====

  /// Create a mock audio file with metadata
  Future<void> _createMockAudioFile(File file, AudioFormat format) async {
    final content = '''Mock Audio File
Format: ${format.name}
Sample Rate: $_currentSampleRate
Bit Rate: $_currentBitRate
Created: ${DateTime.now().toIso8601String()}
Duration: 0
Status: Recording...
''';
    await file.writeAsString(content);
  }

  /// Update mock audio file with final duration
  Future<void> _updateMockAudioFile(File file, Duration duration) async {
    final content = '''Mock Audio File
Format: ${_currentFormat.name}
Sample Rate: $_currentSampleRate
Bit Rate: $_currentBitRate
Created: ${DateTime.now().toIso8601String()}
Duration: ${duration.inSeconds}
Status: Completed
''';
    await file.writeAsString(content);
  }

  /// Start amplitude monitoring for visualization
  void _startAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isRecording && !_isRecordingPaused) {
        // Generate realistic amplitude data
        final baseAmplitude = 0.3 + (math.sin(DateTime.now().millisecondsSinceEpoch / 200) * 0.2);
        final noise = (math.Random().nextDouble() - 0.5) * 0.3;
        final amplitude = (baseAmplitude + noise).clamp(0.0, 1.0);

        _amplitudeController?.add(amplitude);
      }
    });
  }

  /// Stop amplitude monitoring
  void _stopAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeController?.add(0.0);
  }

  /// Start duration monitoring
  void _startDurationMonitoring() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isRecording) {
        // Duration updates are handled by the bloc through getCurrentRecordingDuration
      }
    });
  }

  /// Stop duration monitoring
  void _stopDurationMonitoring() {
    _durationTimer?.cancel();
  }

  /// Calculate total recording duration accounting for pauses
  Duration _calculateTotalRecordingDuration() {
    if (_recordingStartTime == null) return Duration.zero;

    final now = DateTime.now();
    final totalElapsed = now.difference(_recordingStartTime!);

    // Subtract paused time
    var adjustedPausedDuration = _pausedDuration;
    if (_isRecordingPaused && _pauseStartTime != null) {
      adjustedPausedDuration += now.difference(_pauseStartTime!);
    }

    return totalElapsed - adjustedPausedDuration;
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
        return AudioFormat.m4a;
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