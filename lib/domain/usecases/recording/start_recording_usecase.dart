// File: domain/usecases/recording/start_recording_usecase.dart
// 
// Start Recording Use Case - Domain Layer
// =======================================
//
// This use case encapsulates all the business logic required to start a new audio recording.
// Following Clean Architecture principles, it coordinates between different services and
// repositories while maintaining independence from external frameworks.
//
// Business Logic Flow:
// 1. Validate microphone permissions
// 2. Generate location-based recording title using GPS data
// 3. Create unique file path for the recording
// 4. Configure audio service with specified format and quality
// 5. Initialize and start the recording process
// 6. Return success/failure result with appropriate error handling
//
// Dependencies:
// - IAudioServiceRepository: For audio recording operations
// - GeolocationService: For location-based naming
//
// This use case promotes the Single Responsibility Principle by focusing solely
// on recording initiation logic, separate from UI concerns or data persistence.

import 'dart:async';
import '../../../core/enums/audio_format.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import '../../../services/location/geolocation_service.dart';
import 'package:flutter/foundation.dart';

/// Use case for starting a new audio recording
///
/// Handles all business logic for recording initialization including:
/// - Microphone permission validation
/// - File path generation with location-based naming
/// - Audio service configuration and startup
/// - Error handling and validation
///
/// Example usage:
/// ```dart
/// final result = await startRecordingUseCase.execute(
///   folderId: 'user_folder_1',
///   format: AudioFormat.m4a,
///   sampleRate: 44100,
/// );
/// 
/// if (result.isSuccess) {
///   print('Recording started: ${result.filePath}');
/// } else {
///   print('Error: ${result.errorMessage}');
/// }
/// ```
class StartRecordingUseCase {
  final IAudioServiceRepository _audioService;
  final GeolocationService _geolocationService;

  StartRecordingUseCase({
    required IAudioServiceRepository audioService,
    required GeolocationService geolocationService,
  })  : _audioService = audioService,
        _geolocationService = geolocationService;

  /// Execute the start recording process
  ///
  /// Returns [StartRecordingResult] containing either success data or error info
  Future<StartRecordingResult> execute({
    required String folderId,
    AudioFormat format = AudioFormat.m4a,
    int sampleRate = 44100,
    int bitRate = 128000,
  }) async {
    try {
      debugPrint('🎙️ StartRecordingUseCase: Starting recording process...');

      // Step 1: Validate microphone permissions
      final hasPermissions = await _validateMicrophonePermissions();
      if (!hasPermissions) {
        debugPrint('❌ StartRecordingUseCase: Missing microphone permissions');
        return StartRecordingResult.failure(
          'Microphone permission is required to record audio',
          StartRecordingErrorType.permissionDenied,
        );
      }

      // Step 2: Generate location-based recording title
      final title = await _generateLocationBasedTitle();
      debugPrint('📍 StartRecordingUseCase: Generated title: $title');

      // Step 3: Create unique file path
      final filePath = _generateUniqueFilePath(folderId, title, format);
      debugPrint('📁 StartRecordingUseCase: File path: $filePath');

      // Step 4: Validate recording configuration
      final configError = _validateRecordingConfiguration(format, sampleRate, bitRate);
      if (configError != null) {
        debugPrint('❌ StartRecordingUseCase: Invalid configuration: $configError');
        return StartRecordingResult.failure(
          configError,
          StartRecordingErrorType.invalidConfiguration,
        );
      }

      // Step 5: Initialize and start audio service
      final startSuccess = await _startAudioRecording(
        filePath: filePath,
        format: format,
        sampleRate: sampleRate,
        bitRate: bitRate,
      );

      if (startSuccess) {
        debugPrint('✅ StartRecordingUseCase: Recording started successfully');
        return StartRecordingResult.success(
          filePath: filePath,
          title: title,
          folderId: folderId,
          format: format,
          sampleRate: sampleRate,
          bitRate: bitRate,
          startTime: DateTime.now(),
        );
      } else {
        debugPrint('❌ StartRecordingUseCase: Audio service failed to start');
        return StartRecordingResult.failure(
          'Failed to start audio recording service',
          StartRecordingErrorType.audioServiceError,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ StartRecordingUseCase: Unexpected error: $e');
      debugPrint('📍 StartRecordingUseCase: Stack trace: $stackTrace');
      return StartRecordingResult.failure(
        'Unexpected error during recording start: $e',
        StartRecordingErrorType.unknown,
      );
    }
  }

  /// Validate that microphone permissions are granted
  Future<bool> _validateMicrophonePermissions() async {
    try {
      final hasPermission = await _audioService.hasMicrophonePermission();
      if (!hasPermission) {
        // Try to request permission if not already granted
        final requested = await _audioService.requestMicrophonePermission();
        return requested;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ StartRecordingUseCase: Error checking permissions: $e');
      return false;
    }
  }

  /// Generate a location-based title for the recording
  Future<String> _generateLocationBasedTitle() async {
    try {
      final locationName = await _geolocationService.getRecordingLocationName();
      return locationName.isNotEmpty ? locationName : _generateFallbackTitle();
    } catch (e) {
      debugPrint('⚠️ StartRecordingUseCase: Location service error: $e');
      return _generateFallbackTitle();
    }
  }

  /// Generate fallback title when location is unavailable
  String _generateFallbackTitle() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return 'Recording $dateStr $timeStr';
  }

  /// Generate unique file path with timestamp
  String _generateUniqueFilePath(String folderId, String title, AudioFormat format) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedTitle = _sanitizeFilename(title);
    final extension = format.fileExtension;
    return '$folderId/${sanitizedTitle}_$timestamp.$extension';
  }

  /// Sanitize filename by removing invalid characters
  String _sanitizeFilename(String filename) {
    // Remove invalid file system characters
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .substring(0, filename.length > 50 ? 50 : filename.length);
  }

  /// Validate recording configuration parameters
  String? _validateRecordingConfiguration(AudioFormat format, int sampleRate, int bitRate) {
    // Validate sample rate
    if (sampleRate < 8000 || sampleRate > 192000) {
      return 'Invalid sample rate: $sampleRate. Must be between 8000 and 192000 Hz';
    }

    // Validate bit rate
    if (bitRate < 32000 || bitRate > 512000) {
      return 'Invalid bit rate: $bitRate. Must be between 32000 and 512000 bps';
    }

    // Validate format-specific constraints
    switch (format) {
      case AudioFormat.wav:
        if (bitRate > 192000) {
          return 'WAV format does not support bit rates above 192000 bps';
        }
        break;
      case AudioFormat.m4a:
        if (sampleRate > 48000) {
          return 'M4A format works best with sample rates up to 48000 Hz';
        }
        break;
      case AudioFormat.flac:
        // FLAC is lossless, bitrate is less relevant
        break;
    }

    return null; // Configuration is valid
  }

  /// Start the actual audio recording
  Future<bool> _startAudioRecording({
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
      debugPrint('❌ StartRecordingUseCase: Audio service error: $e');
      return false;
    }
  }
}

/// Result class for start recording operation
class StartRecordingResult {
  final bool isSuccess;
  final String? filePath;
  final String? title;
  final String? folderId;
  final AudioFormat? format;
  final int? sampleRate;
  final int? bitRate;
  final DateTime? startTime;
  final String? errorMessage;
  final StartRecordingErrorType? errorType;

  const StartRecordingResult._({
    required this.isSuccess,
    this.filePath,
    this.title,
    this.folderId,
    this.format,
    this.sampleRate,
    this.bitRate,
    this.startTime,
    this.errorMessage,
    this.errorType,
  });

  /// Create a successful result
  factory StartRecordingResult.success({
    required String filePath,
    required String title,
    required String folderId,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
    required DateTime startTime,
  }) =>
      StartRecordingResult._(
        isSuccess: true,
        filePath: filePath,
        title: title,
        folderId: folderId,
        format: format,
        sampleRate: sampleRate,
        bitRate: bitRate,
        startTime: startTime,
      );

  /// Create a failure result
  factory StartRecordingResult.failure(
    String message,
    StartRecordingErrorType errorType,
  ) =>
      StartRecordingResult._(
        isSuccess: false,
        errorMessage: message,
        errorType: errorType,
      );

  @override
  String toString() {
    if (isSuccess) {
      return 'StartRecordingResult.success(filePath: $filePath, title: $title)';
    } else {
      return 'StartRecordingResult.failure(error: $errorMessage, type: $errorType)';
    }
  }
}

/// Types of errors that can occur during recording start
enum StartRecordingErrorType {
  permissionDenied,
  audioServiceError,
  invalidConfiguration,
  fileSystemError,
  unknown,
}

/// Extension to get user-friendly error messages
extension StartRecordingErrorTypeExtension on StartRecordingErrorType {
  String get userMessage {
    switch (this) {
      case StartRecordingErrorType.permissionDenied:
        return 'Microphone permission is required to record audio';
      case StartRecordingErrorType.audioServiceError:
        return 'Audio recording service is not available';
      case StartRecordingErrorType.invalidConfiguration:
        return 'Invalid recording settings';
      case StartRecordingErrorType.fileSystemError:
        return 'Unable to create recording file';
      case StartRecordingErrorType.unknown:
        return 'An unexpected error occurred';
    }
  }
}