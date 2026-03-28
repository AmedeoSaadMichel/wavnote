// File: domain/usecases/recording/get_recordings_usecase.dart
//
// GetRecordingsUseCase - Domain Layer
// =====================================
//
// REFERENCE IMPLEMENTATION — Either/dartz pattern
// ================================================
// This use case is the canonical example of how ALL new use cases
// should be written in WavNote. Key rules (from CLAUDE.md):
//
//   1. Return Either<Failure, Success> — never throw or return bool
//   2. Let the BLoC consume result.fold(left, right)
//   3. Map exceptions to typed Failure subtypes (DatabaseFailure, etc.)
//   4. Never let raw exceptions bubble up to the UI layer
//
// Usage in a BLoC:
//   final result = await _getRecordingsUseCase.execute(folderId: event.folderId);
//   result.fold(
//     (failure) => emit(RecordingError(failure.message)),
//     (recordings) => emit(RecordingsLoaded(recordings)),
//   );

import 'package:dartz/dartz.dart';

import '../../entities/recording_entity.dart';
import '../../repositories/i_recording_repository.dart';
import '../../../core/errors/failures.dart';
import '../../../core/errors/exceptions.dart'; // DatabaseException — caught and mapped to Failure

/// Retrieves all recordings belonging to a given folder.
///
/// Returns [Either<Failure, List<RecordingEntity>>]:
/// - [Left]  — a typed [Failure] (e.g. [DatabaseFailure]) on error
/// - [Right] — the list of recordings on success (may be empty)
class GetRecordingsUseCase {
  final IRecordingRepository _repository;

  const GetRecordingsUseCase({required IRecordingRepository repository})
      : _repository = repository;

  /// Execute the use case.
  ///
  /// [folderId] — ID of the folder whose recordings are requested.
  /// Pass `null` to retrieve recordings from all folders.
  Future<Either<Failure, List<RecordingEntity>>> execute({
    String? folderId,
  }) async {
    try {
      final recordings = await _repository.getRecordingsByFolder(folderId ?? '');
      return Right(recordings);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'recordings',
        'Failed to load recordings for folder "$folderId": ${e.message}',
      ));
    } catch (e) {
      return Left(UnexpectedFailure(
        message: 'Unexpected error loading recordings: $e',
        code: 'GET_RECORDINGS_UNEXPECTED',
      ));
    }
  }
}
