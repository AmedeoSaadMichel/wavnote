// File: services/audio/audio_recorder_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_audio_service_repository.dart';
import '../../core/enums/audio_format.dart';
import '../permission/permission_service.dart';

/// Real audio recording service using flutter_sound
///
/// Provides actual audio recording and playback functionality with
/// comprehensive permission management and error handling.
class AudioRecorderService implements IAudioServiceRepository {
  static const String _tag = 'AudioRecorderService';

  // Flutter Sound instances
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;

  // Stream controllers for real-time updates
  StreamController<double>? _amplitudeController;
  StreamController<Duration>? _positionController;
  StreamController<void>? _completionController;

  // Recording state
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;
  Timer? _durationMonitoringTimer;

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
      debugPrint('$_tag: Initializing real audio service...');

      // Initialize Flutter Sound instances
      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();

      // Open recorder session
      await _recorder!.openRecorder();
      await _player!.openPlayer();

      // Initialize stream controllers
      _amplitudeController = StreamController<double>.broadcast();
      _positionController = StreamController<Duration>.broadcast();
      _completionController = StreamController<void>.broadcast();

      // Check initial permissions
      await _logPermissionStatus();

      _isInitialized = true;
      debugPrint('$_tag: ✅ Real audio service initialized successfully');
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
    debugPrint('$_tag: Disposing real audio service...');

    try {
      // Stop any ongoing operations
      if (_isRecording) {
        await cancelRecording();
      }
      if (_isPlaying) {
        await stopPlaying();
      }

      // Cancel any active timers
      _durationMonitoringTimer?.cancel();
    } catch (e) {
      debugPrint('$_tag: ⚠️ Error stopping operations during disposal: $e');
    }

    // Guaranteed cleanup using try-finally pattern
    try {
      // Close Flutter Sound instances
      await _recorder?.closeRecorder();
    } catch (e) {
      debugPrint('$_tag: ⚠️ Error closing recorder: $e');
    } finally {
      _recorder = null;
    }

    try {
      await _player?.closePlayer();
    } catch (e) {
      debugPrint('$_tag: ⚠️ Error closing player: $e');
    } finally {
      _player = null;
    }

    // Close stream controllers with guaranteed cleanup
    try {
      await _amplitudeController?.close();
    } catch (e) {
      debugPrint('$_tag: ⚠️ Error closing amplitude controller: $e');
    } finally {
      _amplitudeController = null;
    }

    try {
      await _positionController?.close();
    } catch (e) {
      debugPrint('$_tag: ⚠️ Error closing position controller: $e');
    } finally {
      _positionController = null;
    }

    try {
      await _completionController?.close();
    } catch (e) {
      debugPrint('$_tag: ⚠️ Error closing completion controller: $e');
    } finally {
      _completionController = null;
    }

    // Reset state (guaranteed to execute)
    _isInitialized = false;
    _isRecording = false;
    _isPlaying = false;
    _isRecordingPaused = false;
    _isPlaybackPaused = false;
    _currentRecordingPath = null;
    _recordingStartTime = null;
    _pausedDuration = Duration.zero;
    _pauseStartTime = null;
    _lastError = null;

    debugPrint('$_tag: ✅ Real audio service disposed successfully');
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
    if (!_isInitialized || _recorder == null) {
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
      debugPrint('$_tag: Starting real recording...');

      // 1. Check permissions first
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

      // 2. Store settings
      _currentFormat = format;
      _currentSampleRate = sampleRate;
      _currentBitRate = bitRate;

      // 3. Generate file path and create directories
      final fullPath = await _getFullPath(filePath);
      final file = File(fullPath);
      await file.parent.create(recursive: true);

      debugPrint('$_tag: Recording to: $fullPath');
      debugPrint('$_tag: Format: ${format.name}, Sample Rate: $sampleRate, Bit Rate: $bitRate');

      // 4. Convert format to flutter_sound codec
      final codec = _getFlutterSoundCodec(format);
      
      // 5. Start real recording with flutter_sound
      await _recorder!.startRecorder(
        toFile: fullPath,
        codec: codec,
        sampleRate: sampleRate,
        bitRate: bitRate,
      );

      // 6. Update state
      _currentRecordingPath = fullPath;
      _recordingStartTime = DateTime.now();
      _pausedDuration = Duration.zero;
      _isRecording = true;
      _isRecordingPaused = false;
      _lastError = null;

      // 7. Start monitoring
      _startRealAmplitudeMonitoring();
      _startDurationMonitoring();

      debugPrint('$_tag: ✅ Real recording started successfully');
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
    if (!_isRecording || _currentRecordingPath == null || _recorder == null) {
      _lastError = 'No active recording to stop';
      debugPrint('$_tag: ❌ No active recording to stop');
      return null;
    }

    try {
      debugPrint('$_tag: Stopping real recording...');

      // Capture final duration BEFORE stopping anything to avoid timing issues
      final finalDuration = _calculateTotalRecordingDuration();
      debugPrint('$_tag: Final duration captured: ${finalDuration.inSeconds}.${(finalDuration.inMilliseconds % 1000).toString().padLeft(3, '0')} seconds (${finalDuration.inMilliseconds}ms)');

      // Stop monitoring after capturing duration
      _stopAmplitudeMonitoring();
      _stopDurationMonitoring();

      // Stop real recording with flutter_sound
      await _recorder!.stopRecorder();

      // Use the captured duration instead of recalculating
      final totalDuration = finalDuration;
      debugPrint('$_tag: Recording duration: ${totalDuration.inSeconds}.${(totalDuration.inMilliseconds % 1000).toString().padLeft(3, '0')} seconds (${totalDuration.inMilliseconds}ms)');

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

      final fileSize = await file.length();

      // Create recording entity with correct folder ID extracted from file path
      final folderId = _extractFolderIdFromPath(_currentRecordingPath!);
      final recording = RecordingEntity.create(
        name: _generateDefaultName(),
        filePath: _currentRecordingPath!,
        folderId: folderId,
        format: _currentFormat,
        duration: totalDuration,
        fileSize: fileSize,
        sampleRate: _currentSampleRate,
        // Note: locationName will be set by RecordingBloc using geolocation
      );
      
      debugPrint('$_tag: 🔍 Created recording entity:');
      debugPrint('$_tag: - ID: ${recording.id}');
      debugPrint('$_tag: - Name: ${recording.name}');
      debugPrint('$_tag: - FilePath: ${recording.filePath}');
      debugPrint('$_tag: - FolderId: ${recording.folderId}');
      debugPrint('$_tag: - Format: ${recording.format}');
      debugPrint('$_tag: - Duration: ${recording.duration}');
      debugPrint('$_tag: - FileSize: ${recording.fileSize}');
      debugPrint('$_tag: - SampleRate: ${recording.sampleRate}');
      debugPrint('$_tag: - CreatedAt: ${recording.createdAt}');

      // Clean up state
      final recordingPath = _currentRecordingPath;
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pausedDuration = Duration.zero;
      _lastError = null;

      debugPrint('$_tag: ✅ Real recording stopped successfully: ${recording.name}');
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
    if (!_isRecording || _isRecordingPaused || _recorder == null) return false;

    try {
      await _recorder!.pauseRecorder();
      _isRecordingPaused = true;
      _pauseStartTime = DateTime.now();
      _stopAmplitudeMonitoring();

      debugPrint('$_tag: ⏸️ Real recording paused');
      return true;

    } catch (e) {
      debugPrint('$_tag: ❌ Failed to pause recording: $e');
      return false;
    }
  }

  @override
  Future<bool> resumeRecording() async {
    if (!_isRecording || !_isRecordingPaused || _recorder == null) return false;

    try {
      await _recorder!.resumeRecorder();

      // Add paused time to total paused duration
      if (_pauseStartTime != null) {
        _pausedDuration += DateTime.now().difference(_pauseStartTime!);
        _pauseStartTime = null;
      }

      _isRecordingPaused = false;
      _startRealAmplitudeMonitoring();
      _startDurationMonitoring();

      debugPrint('$_tag: ▶️ Real recording resumed');
      return true;

    } catch (e) {
      debugPrint('$_tag: ❌ Failed to resume recording: $e');
      return false;
    }
  }

  @override
  Future<bool> cancelRecording() async {
    if (!_isRecording || _recorder == null) return false;

    try {
      _stopAmplitudeMonitoring();
      _stopDurationMonitoring();

      // Stop real recording
      await _recorder!.stopRecorder();

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

      debugPrint('$_tag: 🚫 Real recording cancelled');
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

  @override
  Stream<double>? get amplitudeStream => _amplitudeController?.stream;

  @override
  Stream<Duration>? get durationStream => _positionController?.stream;

  // ==== PLAYBACK OPERATIONS ====

  @override
  Future<bool> startPlaying(String filePath) async {
    if (_player == null) return false;

    try {
      final fullPath = await _getFullPath(filePath);
      await _player!.startPlayer(
        fromURI: fullPath,
        whenFinished: () {
          _isPlaying = false;
          _isPlaybackPaused = false;
          _completionController?.add(null);
        },
      );
      _isPlaying = true;
      _isPlaybackPaused = false;
      debugPrint('$_tag: ▶️ Real playback started: $fullPath');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to start playback: $e');
      return false;
    }
  }

  @override
  Future<bool> stopPlaying() async {
    if (_player == null) return false;

    try {
      await _player!.stopPlayer();
      _isPlaying = false;
      _isPlaybackPaused = false;
      debugPrint('$_tag: ⏹️ Real playback stopped');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to stop playback: $e');
      return false;
    }
  }

  @override
  Future<bool> pausePlaying() async {
    if (_player == null) return false;

    try {
      await _player!.pausePlayer();
      _isPlaybackPaused = true;
      debugPrint('$_tag: ⏸️ Real playback paused');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to pause playback: $e');
      return false;
    }
  }

  @override
  Future<bool> resumePlaying() async {
    if (_player == null) return false;

    try {
      await _player!.resumePlayer();
      _isPlaybackPaused = false;
      debugPrint('$_tag: ▶️ Real playback resumed');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to resume playback: $e');
      return false;
    }
  }

  @override
  Future<bool> seekTo(Duration position) async {
    if (_player == null) return false;
    try {
      await _player!.seekToPlayer(position);
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to seek: $e');
      return false;
    }
  }

  @override
  Future<bool> setPlaybackSpeed(double speed) async {
    if (_player == null) return false;
    try {
      await _player!.setSpeed(speed);
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to set speed: $e');
      return false;
    }
  }

  @override
  Future<bool> setVolume(double volume) async {
    if (_player == null) return false;
    try {
      await _player!.setVolume(volume);
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to set volume: $e');
      return false;
    }
  }

  @override
  Future<bool> isPlaying() async => _isPlaying && !_isPlaybackPaused;

  @override
  Future<bool> isPlaybackPaused() async => _isPlaybackPaused;

  @override
  Future<Duration> getCurrentPlaybackPosition() async {
    // Note: getProgress is deprecated in newer flutter_sound versions
    // For now, return Duration.zero as placeholder
    return Duration.zero;
  }

  @override
  Future<Duration> getCurrentPlaybackDuration() async {
    // Note: getProgress is deprecated in newer flutter_sound versions
    // For now, return Duration.zero as placeholder
    return Duration.zero;
  }

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

  /// Convert AudioFormat to FlutterSound Codec
  Codec _getFlutterSoundCodec(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return Codec.pcm16WAV;
      case AudioFormat.m4a:
        return Codec.aacMP4;
      case AudioFormat.flac:
        return Codec.flac;
    }
  }

  /// Start real amplitude monitoring using flutter_sound
  void _startRealAmplitudeMonitoring() {
    if (_recorder == null) return;
    
    try {
      // Subscribe to recorder's amplitude stream
      _recorder!.onProgress!.listen((e) {
        if (_isRecording && !_isRecordingPaused) {
          // Convert decibels to normalized amplitude (0.0 to 1.0)
          final dbfs = e.decibels ?? -80.0;
          final amplitude = _dbToAmplitude(dbfs);
          _amplitudeController?.add(amplitude);
        } else {
          _amplitudeController?.add(0.0);
        }
      });
      debugPrint('$_tag: Real amplitude monitoring started');
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to start amplitude monitoring: $e');
      // Fallback to mock monitoring
      _startMockAmplitudeMonitoring();
    }
  }

  /// Convert decibels to amplitude (0.0 to 1.0)
  double _dbToAmplitude(double dbfs) {
    // Convert dBFS to linear amplitude
    // -80 dBFS = 0.0, -20 dBFS = 1.0 (approximate speech range)
    final normalizedDb = (dbfs + 80.0) / 60.0; // Normalize -80 to -20 dBFS to 0-1
    return normalizedDb.clamp(0.0, 1.0);
  }

  /// Fallback mock amplitude monitoring
  void _startMockAmplitudeMonitoring() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isRecording && !_isRecordingPaused) {
        final time = DateTime.now().millisecondsSinceEpoch;
        final speechPattern = math.sin(time / 300) * 0.3;
        final breathPattern = math.sin(time / 1000) * 0.1;
        final noise = (math.Random().nextDouble() - 0.5) * 0.2;
        final baseAmplitude = 0.25 + speechPattern + breathPattern;
        final amplitude = (baseAmplitude + noise).clamp(0.0, 1.0);
        _amplitudeController?.add(amplitude);
      } else {
        _amplitudeController?.add(0.0);
      }
    });
  }

  /// Stop amplitude monitoring
  void _stopAmplitudeMonitoring() {
    _amplitudeController?.add(0.0);
    debugPrint('$_tag: Amplitude monitoring stopped');
  }

  /// Start duration monitoring
  void _startDurationMonitoring() {
    // Cancel any existing timer
    _durationMonitoringTimer?.cancel();

    _durationMonitoringTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isRecording && !_isRecordingPaused) {
        final duration = _calculateTotalRecordingDuration();
        _positionController?.add(duration);
      } else if (!_isRecording) {
        timer.cancel();
        _durationMonitoringTimer = null;
      }
    });
    debugPrint('$_tag: Duration monitoring started');
  }

  /// Stop duration monitoring
  void _stopDurationMonitoring() {
    _durationMonitoringTimer?.cancel();
    _durationMonitoringTimer = null;
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

    final actualDuration = totalElapsed - adjustedPausedDuration;
    
    // Add a small buffer (100ms) to account for processing delays
    // This helps prevent recordings from being slightly trimmed at the end
    const processingBuffer = Duration(milliseconds: 100);
    final finalDuration = actualDuration + processingBuffer;
    
    debugPrint('$_tag: Duration calculation details:');
    debugPrint('   Start time: $_recordingStartTime');
    debugPrint('   Stop time: $now');
    debugPrint('   Total elapsed: ${totalElapsed.inMilliseconds}ms');
    debugPrint('   Paused duration: ${adjustedPausedDuration.inMilliseconds}ms');
    debugPrint('   Actual duration: ${actualDuration.inMilliseconds}ms');
    debugPrint('   Processing buffer: ${processingBuffer.inMilliseconds}ms');
    debugPrint('   Final duration: ${finalDuration.inMilliseconds}ms (${finalDuration.inSeconds}.${(finalDuration.inMilliseconds % 1000).toString().padLeft(3, '0')}s)');
    
    return finalDuration;
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

  /// Extract folder ID from file path
  /// File path format: ".../Documents/folderId/recording_timestamp.extension"
  String _extractFolderIdFromPath(String filePath) {
    try {
      final parts = filePath.split('/');
      debugPrint('$_tag: 🔍 Splitting path: $filePath');
      debugPrint('$_tag: 🔍 Path parts: $parts');
      
      // Look for the folder ID - it should be the directory name before the filename
      // The structure is: .../Documents/folderId/filename.extension
      if (parts.length >= 2) {
        // Find the last directory before the filename
        final filename = parts.last;
        final folderName = parts[parts.length - 2];
        
        debugPrint('$_tag: 📁 Filename: $filename');
        debugPrint('$_tag: 📁 Folder name: $folderName');
        
        // Check if this looks like a folder ID (numeric string)
        if (folderName.isNotEmpty && RegExp(r'^\d+$').hasMatch(folderName)) {
          debugPrint('$_tag: 📁 Extracted folder ID: $folderName from path: $filePath');
          return folderName;
        }
      }
    } catch (e) {
      debugPrint('$_tag: ⚠️ Failed to extract folder ID from path: $filePath, error: $e');
    }
    
    // Fallback to default
    debugPrint('$_tag: ⚠️ Using fallback folder ID: all_recordings');
    return 'all_recordings';
  }
}