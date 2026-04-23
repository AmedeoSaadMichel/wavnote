// File: data/repositories/recording_repository_crud.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dartz/dartz.dart';
import '../../domain/entities/recording_entity.dart';
import '../database/database_helper.dart';
import '../models/recording_model.dart';
import 'recording_repository_base.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/app_file_utils.dart'; // Import necessario

/// CRUD operations for recording repository
class RecordingRepositoryCrud extends RecordingRepositoryBase {
  /// Get all recordings across all folders
  Future<List<RecordingEntity>> getAllRecordings() async {
    try {
      final db = await DatabaseHelper.database;
      await ensureRecordingsTable(db);
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        orderBy: 'created_at DESC',
      );
      return maps
          .map((map) => RecordingModel.fromDatabase(map).toEntity())
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get recordings for a specific folder
  Future<List<RecordingEntity>> getRecordingsByFolder(String folderId) async {
    try {
      final db = await DatabaseHelper.database;
      await ensureRecordingsTable(db);
      List<Map<String, dynamic>> maps;

      if (folderId == 'all_recordings') {
        maps = await db.query(
          DatabaseHelper.recordingsTable,
          where: 'folder_id != ? AND (is_deleted = 0 OR is_deleted IS NULL)',
          whereArgs: ['recently_deleted'],
          orderBy: 'created_at DESC',
        );
      } else if (folderId == 'favourites') {
        maps = await db.query(
          DatabaseHelper.recordingsTable,
          where:
              'folder_id != ? AND is_favorite = 1 AND (is_deleted = 0 OR is_deleted IS NULL)',
          whereArgs: ['recently_deleted'],
          orderBy: 'created_at DESC',
        );
      } else if (folderId == 'recently_deleted') {
        maps = await db.query(
          DatabaseHelper.recordingsTable,
          where: 'is_deleted = 1',
          orderBy: 'deleted_at DESC',
        );
      } else {
        maps = await db.query(
          DatabaseHelper.recordingsTable,
          where: 'folder_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
          whereArgs: [folderId],
          orderBy: 'created_at DESC',
        );
      }
      return maps
          .map((map) => RecordingModel.fromDatabase(map).toEntity())
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get recording by ID
  Future<RecordingEntity?> getRecordingById(String id) async {
    try {
      final db = await DatabaseHelper.database;
      await ensureRecordingsTable(db);
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return RecordingModel.fromDatabase(maps.first).toEntity();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create a new recording
  Future<RecordingEntity> createRecording(RecordingEntity recording) async {
    try {
      final db = await DatabaseHelper.database;
      await ensureRecordingsTable(db);

      // Conversione asincrona del path in relativo
      final relativePath = await AppFileUtils.toRelative(recording.filePath);
      final model = RecordingModel.fromEntity(
        recording.copyWith(filePath: relativePath),
      );

      if (!model.isValid) throw ArgumentError('Invalid recording data');

      try {
        await db.insert(
          DatabaseHelper.recordingsTable,
          model.toDatabase(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        if (e.toString().contains('waveform_data')) {
          final dbMap = model.toDatabase()..remove('waveform_data');
          await db.insert(
            DatabaseHelper.recordingsTable,
            dbMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          rethrow;
        }
      }
      return recording;
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing recording
  Future<RecordingEntity> updateRecording(RecordingEntity recording) async {
    try {
      final db = await DatabaseHelper.database;
      await ensureRecordingsTable(db);

      // Conversione asincrona del path in relativo
      final relativePath = await AppFileUtils.toRelative(recording.filePath);
      final model = RecordingModel.fromEntity(
        recording.copyWith(filePath: relativePath, updatedAt: DateTime.now()),
      );

      int rowsAffected;
      try {
        rowsAffected = await db.update(
          DatabaseHelper.recordingsTable,
          model.toDatabase(),
          where: 'id = ?',
          whereArgs: [recording.id],
        );
      } catch (e) {
        if (e.toString().contains('waveform_data')) {
          final dbMap = model.toDatabase()..remove('waveform_data');
          rowsAffected = await db.update(
            DatabaseHelper.recordingsTable,
            dbMap,
            where: 'id = ?',
            whereArgs: [recording.id],
          );
        } else {
          rethrow;
        }
      }

      if (rowsAffected == 0)
        throw StateError('Recording not found: ${recording.id}');
      return model.toEntity();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a recording by ID
  Future<Either<Failure, Unit>> deleteRecording(String id) async {
    try {
      final db = await DatabaseHelper.database;
      await ensureRecordingsTable(db);
      final rowsAffected = await db.delete(
        DatabaseHelper.recordingsTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rowsAffected > 0) {
        return const Right(unit);
      } else {
        return Left(
          FileSystemFailure(
            message: 'Recording not found: $id',
            errorType: FileSystemErrorType.fileNotFound,
          ),
        );
      }
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to delete recording: $id',
        ),
      );
    }
  }

  // ==== SOFT DELETE OPERATIONS ====

  /// Soft delete a recording
  Future<Either<Failure, Unit>> softDeleteRecording(String id) async {
    try {
      final db = await getDatabaseWithTable();
      final recording = await getRecordingById(id);
      if (recording == null) {
        return Left(
          FileSystemFailure(
            message: 'Recording not found: $id',
            errorType: FileSystemErrorType.fileNotFound,
          ),
        );
      }

      final deletedRecording = recording.softDelete();
      // Conversione asincrona
      final relativePath = await AppFileUtils.toRelative(
        deletedRecording.filePath,
      );
      final recordingModel = RecordingModel.fromEntity(
        deletedRecording.copyWith(filePath: relativePath),
      );

      final rowsAffected = await db.update(
        DatabaseHelper.recordingsTable,
        recordingModel.toDatabase(),
        where: 'id = ?',
        whereArgs: [id],
      );

      return rowsAffected > 0
          ? const Right(unit)
          : Left(
              DatabaseFailure(
                message: 'Failed to soft delete: $id',
                errorType: DatabaseErrorType.updateFailed,
              ),
            );
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to soft delete: $id',
        ),
      );
    }
  }

  /// Restore a recording
  Future<Either<Failure, Unit>> restoreRecording(String id) async {
    try {
      final db = await getDatabaseWithTable();
      final recording = await getRecordingById(id);
      if (recording == null) {
        return Left(
          FileSystemFailure(
            message: 'Recording not found: $id',
            errorType: FileSystemErrorType.fileNotFound,
          ),
        );
      }

      if (!recording.isDeleted) {
        return Left(
          FileSystemFailure(
            message: 'Recording is not deleted, cannot restore: $id',
            errorType: FileSystemErrorType.invalidFileName,
          ),
        );
      }

      final restoredRecording = recording.restore();
      // Conversione asincrona
      final relativePath = await AppFileUtils.toRelative(
        restoredRecording.filePath,
      );
      final recordingModel = RecordingModel.fromEntity(
        restoredRecording.copyWith(filePath: relativePath),
      );

      final rowsAffected = await db.update(
        DatabaseHelper.recordingsTable,
        recordingModel.toDatabase(),
        where: 'id = ?',
        whereArgs: [id],
      );

      return rowsAffected > 0
          ? const Right(unit)
          : Left(
              DatabaseFailure(
                message: 'Failed to restore: $id',
                errorType: DatabaseErrorType.updateFailed,
              ),
            );
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to restore: $id',
        ),
      );
    }
  }

  /// Permanently delete a recording
  Future<Either<Failure, Unit>> permanentlyDeleteRecording(String id) async {
    try {
      final db = await getDatabaseWithTable();
      final recording = await getRecordingById(id);
      if (recording != null) {
        try {
          final absolutePath = await recording.resolvedFilePath;
          final file = File(absolutePath);
          if (await file.exists()) await file.delete();
        } catch (fileError) {
          debugPrint('⚠️ Could not delete audio file: $fileError');
        }
      }

      final rowsAffected = await db.delete(
        DatabaseHelper.recordingsTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      return rowsAffected > 0
          ? const Right(unit)
          : Left(
              FileSystemFailure(
                message: 'Failed to permanently delete: $id',
                errorType: FileSystemErrorType.fileDeletionFailed,
              ),
            );
    } catch (e) {
      return Left(
        FailureUtils.convertExceptionToFailure(
          e,
          contextMessage: 'Failed to permanently delete: $id',
        ),
      );
    }
  }

  /// Get expired recordings
  Future<List<RecordingEntity>> getExpiredDeletedRecordings() async {
    try {
      final db = await getDatabaseWithTable();
      final fifteenDaysAgo = DateTime.now().subtract(const Duration(days: 15));
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'is_deleted = ? AND deleted_at < ?',
        whereArgs: [1, fifteenDaysAgo.toIso8601String()],
      );
      return maps
          .map((map) => RecordingModel.fromDatabase(map).toEntity())
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Clean up expired recordings
  Future<int> cleanupExpiredRecordings() async {
    try {
      final expiredRecordings = await getExpiredDeletedRecordings();
      int deletedCount = 0;
      for (final recording in expiredRecordings) {
        final result = await permanentlyDeleteRecording(recording.id);
        if (result.isRight()) deletedCount++;
      }
      return deletedCount;
    } catch (e) {
      return 0;
    }
  }
}
