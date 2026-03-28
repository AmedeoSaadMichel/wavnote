// File: domain/usecases/recording/stop_recording_usecase.dart
//
// Stop Recording Use Case - Domain Layer
// ========================================
//
// Returns Either<Failure, RecordingEntity> following the canonical Either pattern
// (CLAUDE.md). The BLoC consumes via result.fold(left, right).
import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../core/enums/audio_format.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import '../../../domain/repositories/i_recording_repository.dart';
import '../../../services/location/geolocation_service.dart';

/// Use case for stopping an active audio recording
///
/// Handles all business logic for recording completion including:
/// - Audio service stop operation
/// - Location-based naming with incremental numbering
/// - Recording entity creation and persistence
/// - Waveform data integration
/// - Error handling and validation
class StopRecordingUseCase {
  final IAudioServiceRepository _audioService;
  final IRecordingRepository _recordingRepository;
  final GeolocationService _geolocationService;

  StopRecordingUseCase({
    required IAudioServiceRepository audioService,
    required IRecordingRepository recordingRepository,
    required GeolocationService geolocationService,
  })  : _audioService = audioService,
        _recordingRepository = recordingRepository,
        _geolocationService = geolocationService;

  /// Execute the stop recording process.
  ///
  /// Returns [Either<Failure, RecordingEntity>]:
  /// - [Left]  — a [Failure] on error
  /// - [Right] — the saved [RecordingEntity] on success
  Future<Either<Failure, RecordingEntity>> execute({
    List<double>? waveformData,
    Duration? overrideDuration,
  }) async {
    try {
      // 1. Validate active recording
      final isRecording = await _audioService.isRecording();
      final isPaused = await _audioService.isRecordingPaused();
      if (!isRecording && !isPaused) {
        return Left(AudioRecordingFailure.stopFailed('No active recording to stop'));
      }

      // 2. Stop audio service
      final recordingEntity = await _audioService.stopRecording();
      if (recordingEntity == null) {
        return Left(AudioRecordingFailure.stopFailed('Audio service returned null'));
      }

      // 3. Generate location-based name
      final namedRecording = await _generateLocationBasedRecording(recordingEntity);

      // 4. Apply waveform data and duration override
      final finalRecording = _addWaveformData(namedRecording, waveformData, overrideDuration);

      // 5. Validate
      final validationError = _validateRecording(finalRecording);
      if (validationError != null) {
        return Left(AudioRecordingFailure.stopFailed(validationError));
      }

      // 6. Persist
      final saved = await _recordingRepository.createRecording(finalRecording);
      return Right(saved);

    } catch (e, st) {
      debugPrint('❌ StopRecordingUseCase: $e\n$st');
      return Left(UnexpectedFailure(
        message: 'Unexpected error stopping recording: $e',
        code: 'STOP_RECORDING_UNEXPECTED',
      ));
    }
  }

  /// Generate location-based recording name with incremental numbering
  Future<RecordingEntity> _generateLocationBasedRecording(RecordingEntity recording) async {
    try {
      // Get the current address from geolocation with timeout
      String locationName;
      
      try {
        // Add a shorter timeout to prevent blocking
        locationName = await _geolocationService.getRecordingLocationName()
            .timeout(const Duration(seconds: 3));
        debugPrint('📍 StopRecordingUseCase: Using geolocation address: "$locationName"');
      } catch (e) {
        debugPrint('⚠️ StopRecordingUseCase: Geolocation timeout/error, using fallback: $e');
        // Use timestamp-based fallback if geolocation fails
        final now = DateTime.now();
        locationName = 'Recording ${now.day}/${now.month} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
        debugPrint('📍 StopRecordingUseCase: Using fallback name: "$locationName"');
      }

      // Get existing recordings in this folder to determine the next number
      final existingRecordings = await _recordingRepository.getRecordingsByFolder(recording.folderId);
      
      // Filter recordings that start with the location name
      final matchingRecordings = existingRecordings.where((r) => 
        r.name.startsWith(locationName)
      ).toList();

      // Determine the next number
      String newName;
      if (matchingRecordings.isEmpty) {
        // First recording with this location name
        newName = locationName;
      } else {
        // Find the highest number used
        int highestNumber = 0; // Start from 0, so first recording without number = 1
        
        for (final existingRecording in matchingRecordings) {
          if (existingRecording.name == locationName) {
            // This is the base name without number (represents number 1)
            highestNumber = highestNumber > 1 ? highestNumber : 1;
          } else {
            // Try to extract number from name like "88 Bostall Lane 2"
            final escapedLocationName = RegExp.escape(locationName);
            final regex = RegExp('^$escapedLocationName (\\d+)\$');
            final match = regex.firstMatch(existingRecording.name);
            if (match != null) {
              final number = int.tryParse(match.group(1) ?? '0') ?? 0;
              if (number > highestNumber) {
                highestNumber = number;
              }
            }
          }
        }
        
        // Next recording should be the next number
        newName = '$locationName ${highestNumber + 1}';
      }

      debugPrint('📝 StopRecordingUseCase: Generated name: "$newName" (${matchingRecordings.length} existing)');

      // Create updated recording with the new name and location
      return recording.copyWith(
        name: newName,
        locationName: locationName,
      );

    } catch (e) {
      debugPrint('❌ StopRecordingUseCase: Error generating location-based name: $e');
      // Return original recording if naming fails
      return recording;
    }
  }

  /// Add waveform data to the recording if provided
  RecordingEntity _addWaveformData(
    RecordingEntity recording,
    List<double>? waveformData,
    Duration? overrideDuration,
  ) {
    // Use override duration if provided, otherwise keep original
    final finalDuration = overrideDuration ?? recording.duration;
    
    // Add waveform data if provided and not empty
    if (waveformData != null && waveformData.isNotEmpty) {
      debugPrint('🎵 StopRecordingUseCase: Adding ${waveformData.length} waveform data points');
      return recording.copyWith(
        waveformData: waveformData,
        duration: finalDuration,
      );
    } else {
      debugPrint('🎵 StopRecordingUseCase: No waveform data provided');
      return recording.copyWith(duration: finalDuration);
    }
  }

  /// Validate recording before saving
  String? _validateRecording(RecordingEntity recording) {
    // Check file path
    if (recording.filePath.isEmpty) {
      return 'Recording file path is empty';
    }

    // Check duration
    if (recording.duration.inMilliseconds <= 0) {
      return 'Recording duration must be greater than zero';
    }

    // Check file size
    if (recording.fileSize <= 0) {
      return 'Recording file size is invalid';
    }

    // Check folder ID
    if (recording.folderId.isEmpty) {
      return 'Recording folder ID is required';
    }

    // Check name
    if (recording.name.isEmpty) {
      return 'Recording name is required';
    }

    // Check waveform data validity if present
    if (recording.waveformData != null) {
      final waveformData = recording.waveformData!;
      if (waveformData.any((value) => value.isNaN || value.isInfinite)) {
        return 'Waveform data contains invalid values';
      }
      if (waveformData.any((value) => value < -1.0 || value > 1.0)) {
        return 'Waveform data values must be between -1.0 and 1.0';
      }
    }

    return null; // Recording is valid
  }
}

// Error type enum kept for BLoC mapping in recording_bloc.dart
enum StopRecordingErrorType {
  noActiveRecording,
  audioServiceError,
  invalidRecording,
  repositoryError,
  fileSystemError,
  unknown,
}

/// Extension to get user-friendly error messages
extension StopRecordingErrorTypeExtension on StopRecordingErrorType {
  String get userMessage {
    switch (this) {
      case StopRecordingErrorType.noActiveRecording:
        return 'No active recording to stop';
      case StopRecordingErrorType.audioServiceError:
        return 'Audio recording service error';
      case StopRecordingErrorType.invalidRecording:
        return 'Recording data is invalid';
      case StopRecordingErrorType.repositoryError:
        return 'Failed to save recording';
      case StopRecordingErrorType.fileSystemError:
        return 'Unable to access recording file';
      case StopRecordingErrorType.unknown:
        return 'An unexpected error occurred';
    }
  }
}