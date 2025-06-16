// File: domain/usecases/recording/delete_recording_usecase.dart
import 'package:dartz/dartz.dart';
import '../../entities/recording_entity.dart';
import '../../repositories/i_recording_repository.dart';
import '../../repositories/i_folder_repository.dart';
import '../../../core/utils/file_utils.dart';
import 'dart:io';

/// Use case for deleting audio recordings
///
/// Handles the complete flow of recording deletion including:
/// - Recording validation
/// - File system cleanup
/// - Database removal
/// - Folder count updates
/// - Backup creation (optional)
class DeleteRecordingUseCase {
  final IRecordingRepository _recordingRepository;
  final IFolderRepository _folderRepository;

  const DeleteRecordingUseCase({
    required IRecordingRepository recordingRepository,
    required IFolderRepository folderRepository,
  })  : _recordingRepository = recordingRepository,
        _folderRepository = folderRepository;

  /// Delete a single recording
  Future<Either<RecordingFailure, DeletionResult>> execute(
      DeleteRecordingParams params,
      ) async {
    try {
      // 1. Validate recording exists
      final recording = await _recordingRepository.getRecordingById(params.recordingId);
      if (recording == null) {
        return Left(RecordingFailure.recordingError('Recording not found: ${params.recordingId}'));
      }

      // 2. Create backup if requested
      String? backupPath;
      if (params.createBackup) {
        final backupResult = await _createRecordingBackup(recording);
        if (backupResult.isLeft()) {
          return Left(backupResult.fold((l) => l, (r) => throw Exception()));
        }
        backupPath = backupResult.fold((l) => throw Exception(), (r) => r);
      }

      // 3. Delete file from filesystem
      final fileDeleteResult = await _deleteRecordingFile(recording);
      if (fileDeleteResult.isLeft()) {
        return Left(fileDeleteResult.fold((l) => l, (r) => throw Exception()));
      }

      // 4. Remove from database
      final dbDeleteResult = await _recordingRepository.deleteRecording(recording.id);
      if (!dbDeleteResult) {
        return Left(RecordingFailure.databaseError('Failed to remove recording from database'));
      }

      // 5. Update folder count
      await _updateFolderCount(recording.folderId);

      // 6. Create deletion result
      final result = DeletionResult(
        deletedRecording: recording,
        deletedAt: DateTime.now(),
        backupPath: backupPath,
        wasBackedUp: params.createBackup,
        fileSize: recording.fileSize,
      );

      return Right(result);
    } catch (e) {
      return Left(RecordingFailure.unexpected('Failed to delete recording: $e'));
    }
  }

  /// Delete multiple recordings
  Future<Either<RecordingFailure, BulkDeletionResult>> deleteMultiple(
      DeleteMultipleRecordingsParams params,
      ) async {
    try {
      final deletionResults = <DeletionResult>[];
      final failures = <String, RecordingFailure>{};
      int totalFilesSize = 0;

      for (final recordingId in params.recordingIds) {
        final deleteParams = DeleteRecordingParams(
          recordingId: recordingId,
          createBackup: params.createBackup,
        );

        final result = await execute(deleteParams);

        result.fold(
              (failure) => failures[recordingId] = failure,
              (success) {
            deletionResults.add(success);
            totalFilesSize += success.fileSize;
          },
        );
      }

      final bulkResult = BulkDeletionResult(
        deletionResults: deletionResults,
        failures: failures,
        totalDeletedCount: deletionResults.length,
        totalFailedCount: failures.length,
        totalFreedSpace: totalFilesSize,
        deletedAt: DateTime.now(),
      );

      // Return success even if some deletions failed
      return Right(bulkResult);
    } catch (e) {
      return Left(RecordingFailure.unexpected('Failed to delete multiple recordings: $e'));
    }
  }

  /// Delete all recordings in a folder
  Future<Either<RecordingFailure, BulkDeletionResult>> deleteByFolder(
      DeleteByFolderParams params,
      ) async {
    try {
      // 1. Get all recordings in folder
      final recordings = await _recordingRepository.getRecordingsByFolder(params.folderId);

      if (recordings.isEmpty) {
        return Right(BulkDeletionResult.empty());
      }

      // 2. Extract recording IDs
      final recordingIds = recordings.map((r) => r.id).toList();

      // 3. Use bulk delete
      final deleteParams = DeleteMultipleRecordingsParams(
        recordingIds: recordingIds,
        createBackup: params.createBackup,
      );

      return await deleteMultiple(deleteParams);
    } catch (e) {
      return Left(RecordingFailure.unexpected('Failed to delete folder recordings: $e'));
    }
  }

  /// Create backup of recording before deletion
  Future<Either<RecordingFailure, String>> _createRecordingBackup(
      RecordingEntity recording,
      ) async {
    try {
      final sourceFile = File(recording.filePath);

      if (!await sourceFile.exists()) {
        return Left(RecordingFailure.fileSystemError('Source file not found for backup'));
      }

      // Generate backup path
      final backupDir = await FileUtils.getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFileName = 'backup_${recording.name}_$timestamp${recording.fileExtension}';
      final backupPath = '${backupDir.path}/$backupFileName';

      // Copy file to backup location
      await sourceFile.copy(backupPath);

      // Verify backup was created
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        return Left(RecordingFailure.fileSystemError('Failed to create backup file'));
      }

      return Right(backupPath);
    } catch (e) {
      return Left(RecordingFailure.fileSystemError('Backup creation failed: $e'));
    }
  }

  /// Delete recording file from filesystem
  Future<Either<RecordingFailure, void>> _deleteRecordingFile(
      RecordingEntity recording,
      ) async {
    try {
      final file = File(recording.filePath);

      if (!await file.exists()) {
        // File already doesn't exist, consider it success
        return const Right(null);
      }

      await file.delete();

      // Verify deletion
      if (await file.exists()) {
        return Left(RecordingFailure.fileSystemError('Failed to delete recording file'));
      }

      return const Right(null);
    } catch (e) {
      return Left(RecordingFailure.fileSystemError('File deletion failed: $e'));
    }
  }

  /// Update folder recording count after deletion
  Future<void> _updateFolderCount(String folderId) async {
    try {
      await _folderRepository.decrementFolderCount(folderId);
    } catch (e) {
      // Log error but don't fail the deletion operation
      print('Warning: Failed to update folder count after deletion: $e');
    }
  }
}

/// Parameters for deleting a single recording
class DeleteRecordingParams {
  final String recordingId;
  final bool createBackup;

  const DeleteRecordingParams({
    required this.recordingId,
    this.createBackup = false,
  });
}

/// Parameters for deleting multiple recordings
class DeleteMultipleRecordingsParams {
  final List<String> recordingIds;
  final bool createBackup;

  const DeleteMultipleRecordingsParams({
    required this.recordingIds,
    this.createBackup = false,
  });
}

/// Parameters for deleting all recordings in a folder
class DeleteByFolderParams {
  final String folderId;
  final bool createBackup;

  const DeleteByFolderParams({
    required this.folderId,
    this.createBackup = false,
  });
}

/// Result of a single recording deletion
class DeletionResult {
  final RecordingEntity deletedRecording;
  final DateTime deletedAt;
  final String? backupPath;
  final bool wasBackedUp;
  final int fileSize;

  const DeletionResult({
    required this.deletedRecording,
    required this.deletedAt,
    this.backupPath,
    required this.wasBackedUp,
    required this.fileSize,
  });

  /// Get human-readable deleted size
  String get deletedSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Check if backup was created successfully
  bool get hasBackup => wasBackedUp && backupPath != null;
}

/// Result of bulk recording deletion
class BulkDeletionResult {
  final List<DeletionResult> deletionResults;
  final Map<String, RecordingFailure> failures;
  final int totalDeletedCount;
  final int totalFailedCount;
  final int totalFreedSpace;
  final DateTime deletedAt;

  const BulkDeletionResult({
    required this.deletionResults,
    required this.failures,
    required this.totalDeletedCount,
    required this.totalFailedCount,
    required this.totalFreedSpace,
    required this.deletedAt,
  });

  /// Create empty result
  factory BulkDeletionResult.empty() {
    return BulkDeletionResult(
      deletionResults: const [],
      failures: const {},
      totalDeletedCount: 0,
      totalFailedCount: 0,
      totalFreedSpace: 0,
      deletedAt: DateTime.now(),
    );
  }

  /// Check if all deletions were successful
  bool get allSuccessful => totalFailedCount == 0;

  /// Check if any deletions were successful
  bool get anySuccessful => totalDeletedCount > 0;

  /// Check if all deletions failed
  bool get allFailed => totalDeletedCount == 0 && totalFailedCount > 0;

  /// Get human-readable freed space
  String get freedSpaceFormatted {
    if (totalFreedSpace < 1024) return '${totalFreedSpace}B';
    if (totalFreedSpace < 1024 * 1024) return '${(totalFreedSpace / 1024).toStringAsFixed(1)}KB';
    return '${(totalFreedSpace / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get success rate percentage
  double get successRate {
    final total = totalDeletedCount + totalFailedCount;
    if (total == 0) return 0.0;
    return (totalDeletedCount / total) * 100;
  }

  /// Get summary message
  String get summaryMessage {
    if (allSuccessful) {
      return 'Successfully deleted $totalDeletedCount recording${totalDeletedCount > 1 ? 's' : ''} (${freedSpaceFormatted} freed)';
    } else if (allFailed) {
      return 'Failed to delete all $totalFailedCount recording${totalFailedCount > 1 ? 's' : ''}';
    } else {
      return 'Deleted $totalDeletedCount, failed $totalFailedCount recording${(totalDeletedCount + totalFailedCount) > 1 ? 's' : ''}';
    }
  }

  /// Get list of backed up recordings
  List<DeletionResult> get backedUpRecordings =>
      deletionResults.where((r) => r.hasBackup).toList();

  /// Count of recordings with backups
  int get backupCount => backedUpRecordings.length;
}

/// Recording failure types for error handling
class RecordingFailure {
  final String message;
  final RecordingFailureType type;

  const RecordingFailure._(this.message, this.type);

  factory RecordingFailure.recordingError(String message) =>
      RecordingFailure._(message, RecordingFailureType.recording);

  factory RecordingFailure.fileSystemError(String message) =>
      RecordingFailure._(message, RecordingFailureType.fileSystem);

  factory RecordingFailure.databaseError(String message) =>
      RecordingFailure._(message, RecordingFailureType.database);

  factory RecordingFailure.unexpected(String message) =>
      RecordingFailure._(message, RecordingFailureType.unexpected);

  @override
  String toString() => 'RecordingFailure: $message (${type.name})';
}

/// Types of recording failures
enum RecordingFailureType {
  recording,
  fileSystem,
  database,
  unexpected,
}