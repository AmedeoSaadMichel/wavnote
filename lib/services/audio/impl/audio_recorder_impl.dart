// File: services/audio/impl/audio_recorder_impl.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import '../../../core/enums/audio_format.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_constants.dart';
import 'audio_monitoring_service.dart';

/// Core audio recording implementation using flutter_sound
///
/// Handles the actual recording operations without business logic.
/// Focused on audio recording functionality only.
class AudioRecorderImpl {

  // Flutter Sound instances
  FlutterSoundRecorder? _recorder;

  // Recording state
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;

  // Recording settings
  AudioFormat _currentFormat = AudioFormat.m4a;
  int _currentSampleRate = 44100;
  int _currentBitRate = 128000;

  // Service state
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isRecordingPaused = false;

  // ==== INITIALIZATION ====

  Future<bool> initialize() async {
    try {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();

      _isInitialized = true;
      debugPrint('✅ Audio recorder initialized');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to initialize audio recorder: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await cancelRecording();
      }

      await _recorder?.closeRecorder();
      _isInitialized = false;
      debugPrint('✅ Audio recorder disposed');

    } catch (e) {
      debugPrint('❌ Error disposing audio recorder: $e');
    }
  }

  // ==== RECORDING OPERATIONS ====

  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
  }) async {
    if (!_isInitialized || _recorder == null) {
      debugPrint('❌ Audio recorder not initialized');
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

      // Get absolute file path
      final absolutePath = await FileUtils.getAbsolutePath(filePath);

      // Ensure directory exists
      final file = File(absolutePath);
      await file.parent.create(recursive: true);

      // Configure codec based on format
      final codec = _getCodecForFormat(format);

      // Start recording
      await _recorder!.startRecorder(
        toFile: absolutePath,
        codec: codec,
        sampleRate: sampleRate,
        bitRate: bitRate,
        numChannels: 1,
      );

      _currentRecordingPath = absolutePath;
      _recordingStartTime = DateTime.now();
      _pausedDuration = Duration.zero;
      _isRecording = true;
      _isRecordingPaused = false;

      debugPrint('✅ Recording started: $absolutePath');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to start recording: $e');
      _isRecording = false;
      return false;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording || _recorder == null || _currentRecordingPath == null) {
      debugPrint('❌ No active recording to stop');
      return null;
    }

    try {
      // Stop Flutter Sound recording
      await _recorder!.stopRecorder();

      _isRecording = false;
      _isRecordingPaused = false;

      // Verify file exists
      final file = File(_currentRecordingPath!);
      if (!await file.exists()) {
        debugPrint('❌ Recording file not found after stopping');
        return null;
      }

      final recordingPath = _currentRecordingPath!;

      // Clean up
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pausedDuration = Duration.zero;

      debugPrint('✅ Recording stopped: $recordingPath');
      return recordingPath;

    } catch (e) {
      debugPrint('❌ Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  Future<bool> pauseRecording() async {
    if (!_isRecording || _isRecordingPaused || _recorder == null) {
      return false;
    }

    try {
      await _recorder!.pauseRecorder();

      _isRecordingPaused = true;
      _pauseStartTime = DateTime.now();

      debugPrint('⏸️ Recording paused');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to pause recording: $e');
      return false;
    }
  }

  Future<bool> resumeRecording() async {
    if (!_isRecording || !_isRecordingPaused || _recorder == null) {
      return false;
    }

    try {
      await _recorder!.resumeRecorder();

      // Add paused time to total paused duration
      if (_pauseStartTime != null) {
        _pausedDuration += DateTime.now().difference(_pauseStartTime!);
        _pauseStartTime = null;
      }

      _isRecordingPaused = false;

      debugPrint('▶️ Recording resumed');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to resume recording: $e');
      return false;
    }
  }

  Future<bool> cancelRecording() async {
    if (!_isRecording || _recorder == null) {
      return false;
    }

    try {
      // Stop recording
      await _recorder!.stopRecorder();

      _isRecording = false;
      _isRecordingPaused = false;

      // Delete the file
      if (_currentRecordingPath != null) {
        await FileUtils.deleteFile(_currentRecordingPath!);
      }

      // Clean up
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pausedDuration = Duration.zero;
      _pauseStartTime = null;

      debugPrint('🚫 Recording cancelled');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to cancel recording: $e');
      return false;
    }
  }

  // ==== STATE GETTERS ====

  bool get isRecording => _isRecording && !_isRecordingPaused;
  bool get isRecordingPaused => _isRecordingPaused;
  bool get isInitialized => _isInitialized;
  String? get currentRecordingPath => _currentRecordingPath;

  Duration calculateTotalRecordingDuration() {
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

  // ==== PERMISSIONS ====

  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status == PermissionStatus.granted;
  }

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  // ==== DEVICE INFO ====

  Future<bool> hasMicrophone() async => true; // Assume available on mobile

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

  Future<List<AudioFormat>> getSupportedFormats() async {
    if (Platform.isIOS) {
      return [AudioFormat.m4a, AudioFormat.wav];
    } else {
      return [AudioFormat.wav, AudioFormat.m4a];
    }
  }

  Future<List<int>> getSupportedSampleRates(AudioFormat format) async {
    return format.supportedSampleRates;
  }

  // ==== PRIVATE HELPERS ====

  /// Get Flutter Sound codec for audio format
  Codec _getCodecForFormat(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return Codec.pcm16WAV;
      case AudioFormat.m4a:
        return Codec.aacADTS;
      case AudioFormat.flac:
        return Codec.flac;
    }
  }
}