// File: domain/usecases/recording/recording_lifecycle_usecase.dart
import 'dart:async';
import '../../../core/enums/audio_format.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import '../../../domain/repositories/i_recording_repository.dart';
import '../../../services/location/geolocation_service.dart';

/// Use case for managing recording lifecycle operations
///
/// Encapsulates business logic for recording start/stop/pause operations
/// with proper error handling and location-based naming.
class RecordingLifecycleUseCase {
  final IAudioServiceRepository _audioService;
  final IRecordingRepository _recordingRepository;
  final GeolocationService _geolocationService;

  RecordingLifecycleUseCase({
    required IAudioServiceRepository audioService,
    required IRecordingRepository recordingRepository,
    required GeolocationService geolocationService,
  }) : _audioService = audioService,
        _recordingRepository = recordingRepository,
        _geolocationService = geolocationService;

  /// Initialize audio service
  Future<bool> initializeAudioService() async {
    try {
      return await _audioService.initialize();
    } catch (e) {
      print('❌ RecordingLifecycleUseCase: Error initializing audio service: $e');
      return false;
    }
  }

  /// Check if recording can be started
  Future<bool> canStartRecording() async {
    try {
      return await _audioService.hasMicrophonePermission();
    } catch (e) {
      print('❌ RecordingLifecycleUseCase: Error checking permissions: $e');
      return false;
    }
  }

  /// Generate location-based recording title
  Future<String> generateRecordingTitle() async {
    try {
      final locationName = await _geolocationService.getRecordingLocationName();
      return locationName.isNotEmpty ? locationName : 'New Recording';
    } catch (e) {
      print('⚠️ RecordingLifecycleUseCase: Failed to get location for recording title: $e');
      return 'New Recording';
    }
  }

  /// Start recording with the given parameters
  Future<bool> startRecording({
    required String filePath,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
  }) async {
    try {
      return await _audioService.startRecording(
        filePath: filePath,
        format: format,
        sampleRate: sampleRate,
        bitRate: bitRate,
      );
    } catch (e) {
      print('❌ RecordingLifecycleUseCase: Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    try {
      final result = await _audioService.stopRecording();
      return result?.filePath;
    } catch (e) {
      print('❌ RecordingLifecycleUseCase: Error stopping recording: $e');
      return null;
    }
  }

  /// Pause recording
  Future<bool> pauseRecording() async {
    try {
      return await _audioService.pauseRecording();
    } catch (e) {
      print('❌ RecordingLifecycleUseCase: Error pausing recording: $e');
      return false;
    }
  }

  /// Resume recording
  Future<bool> resumeRecording() async {
    try {
      return await _audioService.resumeRecording();
    } catch (e) {
      print('❌ RecordingLifecycleUseCase: Error resuming recording: $e');
      return false;
    }
  }

  /// Cancel recording
  Future<void> cancelRecording() async {
    try {
      await _audioService.cancelRecording();
    } catch (e) {
      print('❌ RecordingLifecycleUseCase: Error cancelling recording: $e');
    }
  }

  /// Save completed recording to repository
  Future<RecordingEntity> saveRecording({
    required String filePath,
    required String title,
    required Duration duration,
    required String folderId,
    required DateTime startTime,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
  }) async {
    try {
      final recording = RecordingEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: title,
        filePath: filePath,
        duration: duration,
        folderId: folderId,
        createdAt: startTime,
        format: format,
        sampleRate: sampleRate,
        fileSize: 0, // Will be updated by actual service
        isFavorite: false,
      );

      await _recordingRepository.createRecording(recording);
      return recording;
    } catch (e) {
      print('❌ RecordingLifecycleUseCase: Error saving recording: $e');
      rethrow;
    }
  }

  /// Get amplitude stream for real-time updates
  Stream<double>? get amplitudeStream => _audioService.amplitudeStream;

  /// Get duration stream for real-time updates  
  Stream<Duration>? get durationStream => _audioService.durationStream;

  /// Dispose audio service
  Future<void> dispose() async {
    try {
      await _audioService.dispose();
    } catch (e) {
      print('⚠️ RecordingLifecycleUseCase: Error disposing audio service: $e');
    }
  }
}