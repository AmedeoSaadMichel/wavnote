// File: data/repositories/recording_repository_bulk.dart
import 'package:dartz/dartz.dart';
import '../database/database_helper.dart';
import 'recording_repository_base.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart'; // Importa per i tipi di errore

/// Bulk operations for recording repository
class RecordingRepositoryBulk extends RecordingRepositoryBase {
  /// Move multiple recordings to a different folder
  Future<Either<Failure, Unit>> moveRecordingsToFolder(
    List<String> recordingIds,
    String folderId,
  ) async {
    try {
      final db = await getDatabaseWithTable();
      await db.transaction((txn) async {
        for (final recordingId in recordingIds) {
          await txn.update(
            DatabaseHelper.recordingsTable,
            {
              'folder_id': folderId,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [recordingId],
          );
        }
      });
      return const Right(unit);
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to move recordings to $folderId',
        ),
      );
    }
  }

  /// Delete multiple recordings
  Future<Either<Failure, Unit>> deleteRecordings(
    List<String> recordingIds,
  ) async {
    try {
      final db = await getDatabaseWithTable();
      await db.transaction((txn) async {
        for (final recordingId in recordingIds) {
          await txn.delete(
            DatabaseHelper.recordingsTable,
            where: 'id = ?',
            whereArgs: [recordingId],
          );
        }
      });
      return const Right(unit);
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to delete recordings',
        ),
      );
    }
  }

  /// Mark multiple recordings as favorite/unfavorite
  Future<Either<Failure, Unit>> updateRecordingsFavoriteStatus(
    List<String> recordingIds,
    bool isFavorite,
  ) async {
    try {
      final db = await getDatabaseWithTable();
      await db.transaction((txn) async {
        for (final recordingId in recordingIds) {
          await txn.update(
            DatabaseHelper.recordingsTable,
            {
              'is_favorite': isFavorite ? 1 : 0,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [recordingId],
          );
        }
      });
      return const Right(unit);
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to update favorite status',
        ),
      );
    }
  }

  /// Toggle favorite status of a single recording
  Future<Either<Failure, Unit>> toggleFavorite(String recordingId) async {
    try {
      final db = await getDatabaseWithTable();
      final result = await db.query(
        DatabaseHelper.recordingsTable,
        columns: ['is_favorite'],
        where: 'id = ?',
        whereArgs: [recordingId],
      );

      if (result.isEmpty) {
        return Left(
          FileSystemFailure(
            message: 'Recording not found: $recordingId',
            errorType: FileSystemErrorType.fileNotFound,
          ),
        );
      }

      final currentFavoriteStatus =
          (result.first['is_favorite'] as int? ?? 0) == 1;
      final newFavoriteStatus = !currentFavoriteStatus;

      final rowsAffected = await db.update(
        DatabaseHelper.recordingsTable,
        {
          'is_favorite': newFavoriteStatus ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [recordingId],
      );

      return rowsAffected > 0
          ? const Right(unit)
          : Left(
              DatabaseFailure(
                message: 'Failed to toggle favorite: $recordingId',
                errorType: DatabaseErrorType.updateFailed,
              ),
            );
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to toggle favorite: $recordingId',
        ),
      );
    }
  }

  /// Add tags to multiple recordings
  Future<Either<Failure, Unit>> addTagsToRecordings(
    List<String> recordingIds,
    List<String> tags,
  ) async {
    try {
      final db = await getDatabaseWithTable();
      await db.transaction((txn) async {
        for (final recordingId in recordingIds) {
          final result = await txn.query(
            DatabaseHelper.recordingsTable,
            columns: ['tags'],
            where: 'id = ?',
            whereArgs: [recordingId],
          );

          if (result.isNotEmpty) {
            final currentTagsString = result.first['tags'] as String? ?? '';
            final currentTags = currentTagsString.isNotEmpty
                ? currentTagsString.split(',')
                : <String>[];
            final updatedTags = {...currentTags, ...tags}.toList();
            await txn.update(
              DatabaseHelper.recordingsTable,
              {
                'tags': updatedTags.join(','),
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [recordingId],
            );
          }
        }
      });
      return const Right(unit);
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to add tags',
        ),
      );
    }
  }
}
