// File: services/audio/audio_recorder_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_audio_service_repository.dart';
import '../../core/enums/audio_format.dart';
import '../permission/permission_service.dart';

/// Audio recording service using the [record] package.
///
/// Handles recording lifecycle, permission management, real-time
/// amplitude monitoring, and pause/resume tracking.
/// Playback is delegated to [AudioPlayerService] via [AudioServiceCoordinator].
class AudioRecorderService implements IAudioServiceRepository {
  static const String _tag = 'AudioRecorderService';

  // Record package instance
  AudioRecorder? _recorder;

  // Stream controllers for real-time updates
  StreamController<double>? _amplitudeController;
  StreamController<Duration>? _positionController;
  StreamController<void>? _completionController;

  // Amplitude polling timer
  Timer? _amplitudeMonitoringTimer;

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

  // Error tracking
  String? _lastError;

  // ==== INITIALIZATION ====

  @override
  bool get needsDisposal => true;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _recorder = AudioRecorder();

      _amplitudeController = StreamController<double>.broadcast();
      _positionController = StreamController<Duration>.broadcast();
      _completionController = StreamController<void>.broadcast();

      await _logPermissionStatus();

      _isInitialized = true;
      debugPrint('$_tag: ✅ Audio recorder initialized');
      return true;
    } catch (e) {
      _lastError = 'Failed to initialize audio recorder: $e';
      debugPrint('$_tag: ❌ Initialization failed: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      if (_isRecording) await cancelRecording();
    } catch (e) {
      debugPrint('$_tag: ⚠️ Error stopping recording during disposal: $e');
    }

    _durationMonitoringTimer?.cancel();
    _amplitudeMonitoringTimer?.cancel();

    try {
      await _recorder?.dispose();
    } catch (e) {
      debugPrint('$_tag: ⚠️ Error disposing recorder: $e');
    } finally {
      _recorder = null;
    }

    await _amplitudeController?.close();
    await _positionController?.close();
    await _completionController?.close();

    _amplitudeController = null;
    _positionController = null;
    _completionController = null;

    _isInitialized = false;
    _isRecording = false;
    _isRecordingPaused = false;
    _currentRecordingPath = null;
    _recordingStartTime = null;
    _pausedDuration = Duration.zero;
    _pauseStartTime = null;
    _lastError = null;

    debugPrint('$_tag: ✅ Audio recorder disposed');
  }

  // ==== PERMISSION METHODS ====

  @override
  Future<bool> hasMicrophonePermission() async {
    try {
      return await PermissionService.hasMicrophonePermission();
    } catch (e) {
      _lastError = 'Failed to check microphone permission: $e';
      return false;
    }
  }

  @override
  Future<bool> requestMicrophonePermission() async {
    try {
      final result = await PermissionService.requestMicrophonePermission();
      if (result.isGranted) return true;
      _lastError = result.isError
          ? result.errorMessage ?? 'Permission request failed'
          : 'Microphone permission denied';
      return false;
    } catch (e) {
      _lastError = 'Failed to request microphone permission: $e';
      return false;
    }
  }

  @override
  Future<bool> hasMicrophone() async {
    try {
      return await PermissionService.hasMicrophoneHardware();
    } catch (e) {
      return false;
    }
  }

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
      return false;
    }
    if (_isRecording) {
      _lastError = 'Already recording';
      return false;
    }

    try {
      // Ensure microphone permission
      if (!await hasMicrophonePermission()) {
        if (!await requestMicrophonePermission()) {
          _lastError = 'Microphone permission not granted';
          return false;
        }
      }

      _currentFormat = format;
      _currentSampleRate = sampleRate;
      _currentBitRate = bitRate;

      final fullPath = await _getFullPath(filePath);
      await File(fullPath).parent.create(recursive: true);

      final encoder = _getAudioEncoder(format);

      await _recorder!.start(
        RecordConfig(
          encoder: encoder,
          sampleRate: sampleRate,
          bitRate: bitRate,
          numChannels: 1,
        ),
        path: fullPath,
      );

      _currentRecordingPath = fullPath;
      _recordingStartTime = DateTime.now();
      _pausedDuration = Duration.zero;
      _isRecording = true;
      _isRecordingPaused = false;
      _lastError = null;

      _startAmplitudeMonitoring();
      _startDurationMonitoring();

      debugPrint(
        '$_tag: ✅ Recording started — $fullPath ($format, ${sampleRate}Hz)',
      );
      return true;
    } catch (e) {
      _lastError = 'Failed to start recording: $e';
      debugPrint('$_tag: ❌ Recording start failed: $e');
      _isRecording = false;
      return false;
    }
  }

  @override
  Future<RecordingEntity?> stopRecording({bool raw = false}) async {
    if (!_isRecording || _currentRecordingPath == null || _recorder == null) {
      _lastError = 'No active recording to stop';
      return null;
    }

    try {
      final finalDuration = _calculateTotalRecordingDuration();

      _stopAmplitudeMonitoring();
      _stopDurationMonitoring();

      await _recorder!.stop();

      _isRecording = false;
      _isRecordingPaused = false;

      final file = File(_currentRecordingPath!);
      if (!await file.exists()) {
        _lastError = 'Recording file not found after stop';
        return null;
      }

      final fileSize = await file.length();
      final folderId = _extractFolderIdFromPath(_currentRecordingPath!);

      final recording = RecordingEntity.create(
        name: _generateDefaultName(),
        filePath: _currentRecordingPath!,
        folderId: folderId,
        format: _currentFormat,
        duration: finalDuration,
        fileSize: fileSize,
        sampleRate: _currentSampleRate,
      );

      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pausedDuration = Duration.zero;
      _lastError = null;

      debugPrint(
        '$_tag: ✅ Recording stopped — ${recording.name} (${finalDuration.inMilliseconds}ms, ${fileSize}B)',
      );
      return recording;
    } catch (e) {
      _lastError = 'Failed to stop recording: $e';
      debugPrint('$_tag: ❌ Recording stop failed: $e');
      _isRecording = false;
      return null;
    }
  }

  @override
  Future<bool> pauseRecording() async {
    if (!_isRecording || _isRecordingPaused || _recorder == null) return false;
    try {
      await _recorder!.pause();
      _isRecordingPaused = true;
      _pauseStartTime = DateTime.now();
      _stopAmplitudeMonitoring();
      debugPrint('$_tag: ⏸️ Recording paused');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to pause: $e');
      return false;
    }
  }

  @override
  Future<bool> resumeRecording() async {
    if (!_isRecording || !_isRecordingPaused || _recorder == null) return false;
    try {
      await _recorder!.resume();
      if (_pauseStartTime != null) {
        _pausedDuration += DateTime.now().difference(_pauseStartTime!);
        _pauseStartTime = null;
      }
      _isRecordingPaused = false;
      _startAmplitudeMonitoring();
      _startDurationMonitoring();
      debugPrint('$_tag: ▶️ Recording resumed');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to resume: $e');
      return false;
    }
  }

  @override
  Future<bool> cancelRecording() async {
    if (!_isRecording || _recorder == null) return false;
    try {
      _stopAmplitudeMonitoring();
      _stopDurationMonitoring();
      await _recorder!.stop();
      _isRecording = false;
      _isRecordingPaused = false;
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) await file.delete();
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
  Future<Duration> getCurrentRecordingDuration() async =>
      _calculateTotalRecordingDuration();

  @override
  Stream<double> getRecordingAmplitudeStream() =>
      _amplitudeController?.stream ?? const Stream.empty();

  @override
  Stream<double>? get amplitudeStream => _amplitudeController?.stream;

  @override
  Stream<Duration>? get durationStream => _positionController?.stream;

  @override
  Future<double> getCurrentAmplitude() async => 0.0;

  // ==== PLAYBACK — delegated to AudioPlayerService via coordinator ====

  @override
  Future<bool> startPlaying(
    String filePath, {
    Duration? initialPosition,
  }) async => false;
  @override
  Future<bool> stopPlaying() async => false;
  @override
  Future<bool> pausePlaying() async => false;
  @override
  Future<bool> resumePlaying() async => false;
  @override
  Future<bool> seekTo(Duration position) async => false;
  @override
  Future<bool> setPlaybackSpeed(double speed) async => false;
  @override
  Future<bool> setVolume(double volume) async => false;
  @override
  Future<bool> isPlaying() async => false;
  @override
  Future<bool> isPlaybackPaused() async => false;
  @override
  Future<Duration> getCurrentPlaybackPosition() async => Duration.zero;
  @override
  Future<Duration> getCurrentPlaybackDuration() async => Duration.zero;
  @override
  Stream<Duration> getPlaybackPositionStream() => const Stream.empty();
  @override
  Stream<void> getPlaybackCompletionStream() => const Stream.empty();

  // ==== DEVICE & FORMAT ====

  @override
  Future<List<AudioInputDevice>> getAudioInputDevices() async => [
    const AudioInputDevice(
      id: 'default',
      name: 'Default Microphone',
      isDefault: true,
      isAvailable: true,
    ),
  ];

  @override
  Future<bool> setAudioInputDevice(String deviceId) async => true;

  @override
  Future<List<AudioFormat>> getSupportedFormats() async {
    if (Platform.isIOS) return [AudioFormat.m4a, AudioFormat.wav];
    return [AudioFormat.wav, AudioFormat.m4a];
  }

  @override
  Future<List<int>> getSupportedSampleRates(AudioFormat format) async =>
      format.supportedSampleRates;

  // ==== AUDIO FILE INFO ====

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
        duration: Duration.zero, // Duration resolved by just_audio at playback
        fileSize: fileSize,
        sampleRate: _currentSampleRate,
        bitRate: _currentBitRate,
        channels: 1,
        createdAt: stat.changed,
      );
    } catch (e) {
      return null;
    }
  }

  // ==== ADVANCED (stubs) ====

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
  Future<List<double>> getWaveformData(
    String filePath, {
    int sampleCount = 100,
  }) async {
    final random = math.Random(42);
    return List.generate(sampleCount, (_) => random.nextDouble());
  }

  @override
  Future<Duration> getAudioDuration(String filePath) async => Duration.zero;

  @override
  Future<bool> setAudioSessionCategory(AudioSessionCategory category) async =>
      true;
  @override
  Future<bool> enableBackgroundRecording() async => true;
  @override
  Future<bool> disableBackgroundRecording() async => true;

  // ==== PRIVATE HELPERS ====

  /// Map [AudioFormat] to [record] package encoder
  AudioEncoder _getAudioEncoder(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return AudioEncoder.wav;
      case AudioFormat.m4a:
        return AudioEncoder.aacLc;
      case AudioFormat.flac:
        return AudioEncoder.flac;
    }
  }

  /// Start real-time amplitude monitoring (50ms interval via [record] getAmplitude())
  void _startAmplitudeMonitoring() {
    _amplitudeMonitoringTimer?.cancel();
    _amplitudeMonitoringTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) async {
        if (_recorder == null) return;
        if (_isRecording && !_isRecordingPaused) {
          try {
            final amp = await _recorder!.getAmplitude();
            // dBFS: typically -60 (silence) to 0 (max) → normalize to 0.0–1.0
            final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
            _amplitudeController?.add(normalized);
          } catch (_) {
            _amplitudeController?.add(0.0);
          }
        } else {
          _amplitudeController?.add(0.0);
        }
      },
    );
  }

  void _stopAmplitudeMonitoring() {
    _amplitudeMonitoringTimer?.cancel();
    _amplitudeMonitoringTimer = null;
    _amplitudeController?.add(0.0);
  }

  void _startDurationMonitoring() {
    _durationMonitoringTimer?.cancel();
    _durationMonitoringTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (timer) {
        if (_isRecording && !_isRecordingPaused) {
          _positionController?.add(_calculateTotalRecordingDuration());
        } else if (!_isRecording) {
          timer.cancel();
          _durationMonitoringTimer = null;
        }
      },
    );
  }

  void _stopDurationMonitoring() {
    _durationMonitoringTimer?.cancel();
    _durationMonitoringTimer = null;
  }

  /// Calculate total recording duration, excluding paused time
  Duration _calculateTotalRecordingDuration() {
    if (_recordingStartTime == null) return Duration.zero;
    final now = DateTime.now();
    final totalElapsed = now.difference(_recordingStartTime!);
    var pausedSoFar = _pausedDuration;
    if (_isRecordingPaused && _pauseStartTime != null) {
      pausedSoFar += now.difference(_pauseStartTime!);
    }
    return (totalElapsed - pausedSoFar) + const Duration(milliseconds: 100);
  }

  Future<String> _getFullPath(String path) async {
    if (path.startsWith('/')) return path;
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$path';
  }

  AudioFormat _getFormatFromPath(String path) {
    switch (path.toLowerCase().split('.').last) {
      case 'wav':
        return AudioFormat.wav;
      case 'flac':
        return AudioFormat.flac;
      default:
        return AudioFormat.m4a;
    }
  }

  String _generateDefaultName() {
    final now = DateTime.now();
    return 'Recording '
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
  }

  String _extractFolderIdFromPath(String filePath) {
    try {
      final parts = filePath.split('/');
      if (parts.length >= 2) {
        final folderName = parts[parts.length - 2];
        if (folderName.isNotEmpty && RegExp(r'^\d+$').hasMatch(folderName)) {
          return folderName;
        }
      }
    } catch (_) {}
    return 'all_recordings';
  }

  Future<void> _logPermissionStatus() async {
    try {
      final info = await PermissionService.getPermissionDebugInfo();
      info.forEach((k, v) => debugPrint('$_tag: permission $k: $v'));
    } catch (_) {}
  }
}
