// File: data/repositories/recording_repository_utils.dart
import 'package:sqflite/sqflite.dart';
import 'package:dartz/dartz.dart';
import '../../domain/entities/recording_entity.dart';
import '../database/database_helper.dart';
import '../models/recording_model.dart';
import 'recording_repository_base.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/failure_utils.dart';
import '../../core/errors/exceptions.dart'; // Importa per le Enum di errore
import '../../core/errors/failure_types/data_failures.dart';

/// Utility operations for recording repository
class RecordingRepositoryUtils extends RecordingRepositoryBase {
  /// Verify recording files exist on disk
  Future<List<String>> getOrphanedRecordings() async {
    try {
      final db = await getDatabaseWithTable();
      final recordings = await db.query(DatabaseHelper.recordingsTable);
      final orphanedIds = <String>[];
      for (final recordingMap in recordings) {
        // Placeholder per logica esistenza file
      }
      return orphanedIds;
    } catch (e) {
      return [];
    }
  }

  /// Clean up orphaned recordings
  Future<int> cleanupOrphanedRecordings() async {
    try {
      final orphanedIds = await getOrphanedRecordings();
      if (orphanedIds.isNotEmpty) {
        final db = await getDatabaseWithTable();
        await db.transaction((txn) async {
          for (final id in orphanedIds) {
            await txn.delete(
              DatabaseHelper.recordingsTable,
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        });
      }
      return orphanedIds.length;
    } catch (e) {
      return 0;
    }
  }

  /// Rebuild recording indices for performance
  Future<Either<Failure, Unit>> rebuildIndices() async {
    try {
      final db = await getDatabaseWithTable();
      await rebuildRecordingIndices(db);
      return const Right(unit);
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to rebuild indices',
        ),
      );
    }
  }

  /// Validate all recording data integrity
  Future<List<String>> validateRecordingIntegrity() async {
    try {
      final db = await getDatabaseWithTable();
      final recordings = await db.query(DatabaseHelper.recordingsTable);
      final issues = <String>[];
      for (final recordingMap in recordings) {
        try {
          final model = RecordingModel.fromDatabase(recordingMap);
          if (!model.isValid)
            issues.add('Invalid recording data: ${recordingMap['id']}');
        } catch (e) {
          issues.add('Corrupted recording data: ${recordingMap['id']} - $e');
        }
      }
      return issues;
    } catch (e) {
      return [];
    }
  }

  /// Export recordings metadata to JSON
  Future<Map<String, dynamic>> exportRecordings() async {
    try {
      final db = await getDatabaseWithTable();
      final recordings = await db.query(DatabaseHelper.recordingsTable);
      final exportData = recordings
          .map((m) => RecordingModel.fromDatabase(m).toJson())
          .toList();
      return {
        'version': 1,
        'export_date': DateTime.now().toIso8601String(),
        'app_name': 'WavNote',
        'total_recordings': recordings.length,
        'recordings': exportData,
      };
    } catch (e) {
      return {};
    }
  }

  /// Import recordings metadata from JSON
  Future<Either<Failure, Unit>> importRecordings(
    Map<String, dynamic> data,
  ) async {
    try {
      final recordingsData = data['recordings'] as List<dynamic>?;
      if (recordingsData == null) {
        return Left(
          DatabaseFailure(
            message: 'Invalid import data',
            errorType: DatabaseErrorType.queryFailed,
          ),
        );
      }

      final db = await getDatabaseWithTable();
      await db.transaction((txn) async {
        for (final recordingData in recordingsData) {
          final model = RecordingModel.fromJson(recordingData);
          await txn.insert(
            DatabaseHelper.recordingsTable,
            model.toDatabase(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      return const Right(unit);
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to import recordings',
        ),
      );
    }
  }

  /// Clear all recordings
  Future<Either<Failure, Unit>> clearAllRecordings() async {
    try {
      final db = await getDatabaseWithTable();
      await db.delete(DatabaseHelper.recordingsTable);
      return const Right(unit);
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to clear recordings',
        ),
      );
    }
  }

  /// Get recordings that need to be backed up
  Future<List<RecordingEntity>> getRecordingsForBackup() async {
    try {
      final db = await getDatabaseWithTable();
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      final recordings = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'updated_at IS NULL OR updated_at >= ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );
      return recordings
          .map((map) => RecordingModel.fromDatabase(map).toEntity())
          .toList();
    } catch (e) {
      return [];
    }
  }
}
