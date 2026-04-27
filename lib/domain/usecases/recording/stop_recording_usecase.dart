// File: lib/domain/usecases/recording/stop_recording_usecase.dart
import 'dart:async';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../../../core/errors/failures.dart';

import '../../../domain/entities/recording_entity.dart';
import '../../../domain/repositories/i_audio_recording_repository.dart';
import '../../../domain/repositories/i_recording_repository.dart';
import '../../../domain/repositories/i_location_repository.dart';
import '../../../core/utils/app_file_utils.dart'; // IMPORT AGGIUNTO

/// Use case for stopping an active audio recording
class StopRecordingUseCase {
  final IAudioRecordingRepository _audioService;
  final IRecordingRepository _recordingRepository;
  final ILocationRepository _locationRepository;

  StopRecordingUseCase({
    required IAudioRecordingRepository audioService,
    required IRecordingRepository recordingRepository,
    required ILocationRepository locationRepository,
  }) : _audioService = audioService,
       _recordingRepository = recordingRepository,
       _locationRepository = locationRepository;

  Future<Either<Failure, RecordingEntity>> execute({
    List<double>? waveformData,
    Duration? overrideDuration,
    bool raw = false,
  }) async {
    try {
      final isRecording = await _audioService.isRecording();
      final isPaused = await _audioService.isRecordingPaused();
      if (!isRecording && !isPaused) {
        return Left(
          AudioRecordingFailure.stopFailed('No active recording to stop'),
        );
      }

      final recordingEntity = await _audioService.stopRecording(raw: raw);
      if (recordingEntity == null) {
        return Left(
          AudioRecordingFailure.stopFailed('Audio service returned null'),
        );
      }

      final namedRecording = await _generateLocationBasedRecording(
        recordingEntity,
      );
      final finalRecording = _addWaveformData(
        namedRecording,
        waveformData,
        overrideDuration,
      );

      final validationError = _validateRecording(finalRecording);
      if (validationError != null) {
        // CORRETTO: Usiamo una Failure generica o startFailed se non esiste invalidRecording specifica
        return Left(AudioRecordingFailure.startFailed(validationError));
      }

      return await _recordingRepository
          .createRecording(finalRecording)
          .then((entity) => Right(entity));
    } catch (e) {
      debugPrint('❌ StopRecordingUseCase: $e');
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to stop recording',
        ),
      );
    }
  }

  Future<RecordingEntity> _generateLocationBasedRecording(
    RecordingEntity recording,
  ) async {
    try {
      String locationName;
      try {
        locationName = await _locationRepository
            .getRecordingLocationName()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        final now = DateTime.now();
        locationName =
            'Recording ${now.day}/${now.month} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      }

      final existingRecordings = await _recordingRepository
          .getRecordingsByFolder(recording.folderId);
      final matchingRecordings = existingRecordings
          .where((r) => r.name.startsWith(locationName))
          .toList();

      String newName;
      if (matchingRecordings.isEmpty) {
        newName = locationName;
      } else {
        int highestNumber = 0;
        for (final existingRecording in matchingRecordings) {
          if (existingRecording.name == locationName)
            highestNumber = highestNumber > 1 ? highestNumber : 1;
          else {
            final escapedLocationName = RegExp.escape(locationName);
            final regex = RegExp('^$escapedLocationName (\\d+)\$');
            final match = regex.firstMatch(existingRecording.name);
            if (match != null) {
              final number = int.tryParse(match.group(1) ?? '0') ?? 0;
              if (number > highestNumber) highestNumber = number;
            }
          }
        }
        newName = '$locationName ${highestNumber + 1}';
      }

      final recordingWithName = recording.copyWith(
        name: newName,
        locationName: locationName,
      );

      // --- File Rename Logic ---
      try {
        final absolutePath = await recordingWithName.resolvedFilePath;
        final oldFile = File(absolutePath);

        if (await oldFile.exists()) {
          final directory = path.dirname(absolutePath);
          final fileExtension = path.extension(absolutePath);
          final timestamp = DateTime.now().millisecondsSinceEpoch;

          final safeNewName = newName
              .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
              .replaceAll(RegExp(r'\s+'), '_');
          final newFileName = '${safeNewName}_$timestamp$fileExtension';
          final newPath = path.join(directory, newFileName);

          await oldFile.rename(newPath);

          final newRelativePath = await AppFileUtils.toRelative(newPath);
          return recordingWithName.copyWith(filePath: newRelativePath);
        } else {
          debugPrint(
            '⚠️ StopRecordingUseCase: Original file not found at $absolutePath',
          );
          return recordingWithName;
        }
      } catch (e) {
        debugPrint('❌ StopRecordingUseCase: Error renaming file: $e');
        return recordingWithName;
      }
    } catch (e) {
      debugPrint(
        '❌ StopRecordingUseCase: Error generating location-based name: $e',
      );
      return recording;
    }
  }

  RecordingEntity _addWaveformData(
    RecordingEntity recording,
    List<double>? waveformData,
    Duration? overrideDuration,
  ) {
    if (waveformData != null && waveformData.isNotEmpty) {
      final durationFromWaveform = Duration(
        milliseconds: waveformData.length * 100,
      );
      return recording.copyWith(
        waveformData: waveformData,
        duration: durationFromWaveform,
      );
    }
    final finalDuration = overrideDuration ?? recording.duration;
    return recording.copyWith(duration: finalDuration);
  }

  String? _validateRecording(RecordingEntity recording) {
    if (recording.filePath.isEmpty) return 'Recording file path is empty';
    if (recording.duration.inMilliseconds <= 0)
      return 'Recording duration must be greater than zero';
    if (recording.fileSize <= 0) return 'Recording file size is invalid';
    if (recording.folderId.isEmpty) return 'Recording folder ID is required';
    if (recording.name.isEmpty) return 'Recording name is required';
    return null;
  }
}
