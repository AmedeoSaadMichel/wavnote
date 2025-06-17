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
import '../permission/permission_service.dart';

/// Enhanced audio recording service with robust permission handling
///
/// Combines mock recording functionality with comprehensive permission management
/// and error handling. Ready for real audio recording integration.
class AudioRecorderService implements IAudioServiceRepository {
  static const String _tag = 'AudioRecorderService';

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

  // Error tracking
  String? _lastError;

  // ==== INITIALIZATION ====

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('$_tag: Initializing audio service...');

      // Initialize stream controllers
      _amplitudeController = StreamController<double>.broadcast();
      _positionController = StreamController<Duration>.broadcast();
      _completionController = StreamController<void>.broadcast();

      // Check initial permissions
      await _logPermissionStatus();

      _isInitialized = true;
      debugPrint('$_tag: ✅ Audio service initialized successfully');
      return true;

    } catch (e, stackTrace) {
      _lastError = 'Failed to initialize audio service: $e';
      debugPrint('$_tag: ❌ Initialization failed: $e');
      debugPrint('$_tag: Stack trace: $stackTrace');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      debugPrint('$_tag: Disposing audio service...');

      // Stop any ongoing operations
      if (_isRecording) {
        await cancelRecording();
      }
      if (_isPlaying) {
        await stopPlaying();
      }

      // Stop timers
      _amplitudeTimer?.cancel();
      _durationTimer?.cancel();

      // Close stream controllers
      await _amplitudeController?.close();
      await _positionController?.close();
      await _completionController?.close();

      // Reset state
      _amplitudeController = null;
      _positionController = null;
      _completionController = null;
      _isInitialized = false;
      _isRecording = false;
      _isPlaying = false;
      _currentRecordingPath = null;

      debugPrint('$_tag: ✅ Audio service disposed');

    } catch (e) {
      debugPrint('$_tag: ❌ Error during disposal: $e');
    }
  }

  // ==== PERMISSION METHODS ====

  /// Check if microphone permission is granted
  @override
  Future<bool> hasMicrophonePermission() async {
    try {
      final hasPermission = await PermissionService.hasMicrophonePermission();
      debugPrint('$_tag: Microphone permission status: $hasPermission');
      return hasPermission;
    } catch (e) {
      debugPrint('$_tag: Error checking microphone permission: $e');
      _lastError = 'Failed to check microphone permission: $e';
      return false;
    }
  }

  /// Request microphone permission with enhanced error handling
  @override
  Future<bool> requestMicrophonePermission() async {
    try {
      debugPrint('$_tag: Requesting microphone permission...');

      final result = await PermissionService.requestMicrophonePermission();

      if (result.isGranted) {
        debugPrint('$_tag: ✅ Microphone permission granted');
        _lastError = null;
        return true;
      } else if (result.isPermanentlyDenied) {
        debugPrint('$_tag: ❌ Microphone permission permanently denied');
        _lastError = 'Microphone permission permanently denied. Please enable it in settings.';
        return false;
      } else if (result.isError) {
        debugPrint('$_tag: ❌ Permission request error: ${result.errorMessage}');
        _lastError = result.errorMessage ?? 'Permission request failed';
        return false;
      } else {
        debugPrint('$_tag: ❌ Microphone permission denied');
        _lastError = 'Microphone permission denied';
        return false;
      }

    } catch (e) {
      debugPrint('$_tag: ❌ Error requesting microphone permission: $e');
      _lastError = 'Failed to request microphone permission: $e';
      return false;
    }
  }

  /// Check if device has microphone hardware
  @override
  Future<bool> hasMicrophone() async {
    try {
      return await PermissionService.hasMicrophoneHardware();
    } catch (e) {
      debugPrint('$_tag: Error checking microphone hardware: $e');
      return false;
    }
  }

  /// Get the last error message
  String? get lastError => _lastError;

  // ==== RECORDING OPERATIONS ====

  @override
  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
  }) async {
    if (!_isInitialized) {
      _lastError = 'Audio service not initialized';
      debugPrint('$_tag: ❌ Service not initialized');
      return false;
    }

    if (_isRecording) {
      _lastError = 'Already recording';
      debugPrint('$_tag: ❌ Already recording');
      return false;
    }

    try {
      debugPrint('$_tag: Starting recording...');

      // 1. Check permissions first with enhanced validation
      final hasPermission = await hasMicrophonePermission();
      if (!hasPermission) {
        debugPrint('$_tag: ❌ No microphone permission - attempting to request...');

        final permissionGranted = await requestMicrophonePermission();
        if (!permissionGranted) {
          _lastError = 'Microphone permission not granted';
          debugPrint('$_tag: ❌ Permission request failed');
          return false;
        }
      }

      // 2. Verify microphone hardware
      final hasMic = await hasMicrophone();
      if (!hasMic) {
        _lastError = 'No microphone detected on this device';
        debugPrint('$_tag: ❌ No microphone hardware');
        return false;
      }

      // 3. Store settings
      _currentFormat = format;
      _currentSampleRate = sampleRate;
      _currentBitRate = bitRate;

      // 4. Generate file path and create directories
      final fullPath = await _getFullPath(filePath);
      final file = File(fullPath);
      await file.parent.create(recursive: true);

      debugPrint('$_tag: Recording to: $fullPath');
      debugPrint('$_tag: Format: ${format.name}, Sample Rate: $sampleRate, Bit Rate: $bitRate');

      // 5. Create mock audio file with metadata
      await _createMockAudioFile(file, format);

      // 6. Update state
      _currentRecordingPath = fullPath;
      _recordingStartTime = DateTime.now();
      _pausedDuration = Duration.zero;
      _isRecording = true;
      _isRecordingPaused = false;
      _lastError = null;

      // 7. Start monitoring
      _startAmplitudeMonitoring();
      _startDurationMonitoring();

      debugPrint('$_tag: ✅ Recording started successfully');
      return true;

    } catch (e, stackTrace) {
      _lastError = 'Failed to start recording: $e';
      debugPrint('$_tag: ❌ Recording start failed: $e');
      debugPrint('$_tag: Stack trace: $stackTrace');
      _isRecording = false;
      return false;
    }
  }

  @override
  Future<RecordingEntity?> stopRecording() async {
    if (!_isRecording || _currentRecordingPath == null) {
      _lastError = 'No active recording to stop';
      debugPrint('$_tag: ❌ No active recording to stop');
      return null;
    }

    try {
      debugPrint('$_tag: Stopping recording...');

      // Stop monitoring
      _stopAmplitudeMonitoring();
      _stopDurationMonitoring();

      // Calculate total duration
      final totalDuration = _calculateTotalRecordingDuration();
      debugPrint('$_tag: Recording duration: ${totalDuration.inSeconds} seconds');

      // Update state
      _isRecording = false;
      _isRecordingPaused = false;

      // Verify file exists
      final file = File(_currentRecordingPath!);
      if (!await file.exists()) {
        _lastError = 'Recording file not found after stop';
        debugPrint('$_tag: ❌ Recording file not found');
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

      // Clean up state
      final recordingPath = _currentRecordingPath;
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pausedDuration = Duration.zero;
      _lastError = null;

      debugPrint('$_tag: ✅ Recording stopped successfully: ${recording.name}');
      debugPrint('$_tag: File path: $recordingPath');
      debugPrint('$_tag: File size: ${fileSize} bytes');

      return recording;

    } catch (e, stackTrace) {
      _lastError = 'Failed to stop recording: $e';
      debugPrint('$_tag: ❌ Recording stop failed: $e');
      debugPrint('$_tag: Stack trace: $stackTrace');
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

      debugPrint('$_tag: ⏸️ Recording paused');
      return true;

    } catch (e) {
      debugPrint('$_tag: ❌ Failed to pause recording: $e');
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

      debugPrint('$_tag: ▶️ Recording resumed');
      return true;

    } catch (e) {
      debugPrint('$_tag: ❌ Failed to resume recording: $e');
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

      debugPrint('$_tag: 🚫 Recording cancelled');
      return true;

    } catch (e) {
      debugPrint('$_tag: ❌ Failed to cancel recording: $e');
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

  // ==== PLAYBACK OPERATIONS ====

  @override
  Future<bool> startPlaying(String filePath) async {
    _isPlaying = true;
    debugPrint('$_tag: ▶️ Mock playback started');
    return true;
  }

  @override
  Future<bool> stopPlaying() async {
    _isPlaying = false;
    debugPrint('$_tag: ⏹️ Mock playback stopped');
    return true;
  }

  @override
  Future<bool> pausePlaying() async {
    _isPlaybackPaused = true;
    debugPrint('$_tag: ⏸️ Mock playback paused');
    return true;
  }

  @override
  Future<bool> resumePlaying() async {
    _isPlaybackPaused = false;
    debugPrint('$_tag: ▶️ Mock playback resumed');
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

  // ==== DEVICE & AUDIO INPUT ====

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
      debugPrint('$_tag: ❌ Error getting audio file info: $e');
      return null;
    }
  }

  // ==== ADVANCED FEATURES (Stub implementations) ====

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

  /// Log current permission status for debugging
  Future<void> _logPermissionStatus() async {
    try {
      final debugInfo = await PermissionService.getPermissionDebugInfo();
      debugPrint('$_tag: Permission Debug Info:');
      debugInfo.forEach((key, value) {
        debugPrint('$_tag:   $key: $value');
      });
    } catch (e) {
      debugPrint('$_tag: Error getting permission debug info: $e');
    }
  }

  /// Create a mock audio file with metadata
  Future<void> _createMockAudioFile(File file, AudioFormat format) async {
    final content = '''Mock Audio File - Enhanced Version
Format: ${format.name}
Sample Rate: $_currentSampleRate
Bit Rate: $_currentBitRate
Created: ${DateTime.now().toIso8601String()}
Duration: 0
Status: Recording...
Permission Check: ✅ Granted
Hardware Check: ✅ Available
Service Version: Enhanced with PermissionService
''';
    await file.writeAsString(content);
    debugPrint('$_tag: Mock audio file created: ${file.path}');
  }

  /// Update mock audio file with final duration
  Future<void> _updateMockAudioFile(File file, Duration duration) async {
    final content = '''Mock Audio File - Enhanced Version
Format: ${_currentFormat.name}
Sample Rate: $_currentSampleRate
Bit Rate: $_currentBitRate
Created: ${DateTime.now().toIso8601String()}
Duration: ${duration.inSeconds}
Status: Completed ✅
Permission Check: ✅ Granted
Hardware Check: ✅ Available
Service Version: Enhanced with PermissionService
Final File Size: ${await file.length()} bytes
''';
    await file.writeAsString(content);
    debugPrint('$_tag: Mock audio file updated with duration: ${duration.inSeconds}s');
  }

  /// Start amplitude monitoring for visualization
  void _startAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isRecording && !_isRecordingPaused) {
        // Generate more realistic amplitude data with speech patterns
        final time = DateTime.now().millisecondsSinceEpoch;
        final speechPattern = math.sin(time / 300) * 0.3; // Slower speech-like pattern
        final breathPattern = math.sin(time / 1000) * 0.1; // Breathing pattern
        final noise = (math.Random().nextDouble() - 0.5) * 0.2; // Random noise

        final baseAmplitude = 0.25 + speechPattern + breathPattern;
        final amplitude = (baseAmplitude + noise).clamp(0.0, 1.0);

        _amplitudeController?.add(amplitude);
      } else {
        _amplitudeController?.add(0.0);
      }
    });
    debugPrint('$_tag: Amplitude monitoring started');
  }

  /// Stop amplitude monitoring
  void _stopAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeController?.add(0.0);
    debugPrint('$_tag: Amplitude monitoring stopped');
  }

  /// Start duration monitoring
  void _startDurationMonitoring() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isRecording) {
        final duration = _calculateTotalRecordingDuration();
        _positionController?.add(duration);
      }
    });
    debugPrint('$_tag: Duration monitoring started');
  }

  /// Stop duration monitoring
  void _stopDurationMonitoring() {
    _durationTimer?.cancel();
    debugPrint('$_tag: Duration monitoring stopped');
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

  /// Generate default recording name with timestamp
  String _generateDefaultName() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    return 'Recording $dateStr $timeStr';
  }
}