// File: domain/usecases/recording/overwrite_recording_usecase.dart
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/repositories/i_audio_trimmer_repository.dart';

class OverwriteRecordingUseCase {
  final IAudioTrimmerRepository _trimmerService;

  OverwriteRecordingUseCase({required IAudioTrimmerRepository trimmerService})
    : _trimmerService = trimmerService;

  Future<Either<Failure, void>> execute({
    required String originalPath,
    required String insertionPath,
    required Duration startTime,
    required Duration overwriteDuration,
    required String outputPath,
    required String format,
  }) async {
    try {
      await _trimmerService.overwriteAudioSegment(
        originalPath: originalPath,
        insertionPath: insertionPath,
        startTime: startTime,
        overwriteDuration: overwriteDuration,
        outputPath: outputPath,
        format: format,
      );
      return const Right(null);
    } catch (e, st) {
      debugPrint('❌ OverwriteRecordingUseCase: $e\n$st');
      return Left(
        UnexpectedFailure(message: 'Failed to overwrite segment: $e'),
      );
    }
  }
}
