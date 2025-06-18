// File: domain/usecases/recording/bulk_operations_usecase.dart
import 'package:dartz/dartz.dart';
import '../../entities/recording_entity.dart';
import '../../repositories/i_recording_repository.dart';
import '../../../core/errors/failures.dart';
import '../../../core/extensions/duration_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/extensions/datetime_extensions.dart';

/// Use case for bulk operations on recordings
///
/// Handles batch operations like bulk delete, bulk export, bulk rename,
/// and other mass operations with proper error handling and progress tracking.
/// Provides atomic operations where possible and detailed result reporting.
class BulkOperationsUseCase {
  final IRecordingRepository _recordingRepository;

  const BulkOperationsUseCase(
      this._recordingRepository,
      );

  /// Delete multiple recordings with confirmation
  Future<Either<Failure, BulkDeleteResult>> bulkDelete({
    required List<String> recordingIds,
    bool requireConfirmation = true,
  }) async {
    try {
      // Validate input
      if (recordingIds.isEmpty) {
        return Left(ValidationFailure.required('Recording IDs'));
      }

      if (recordingIds.length > 500) {
        return Left(ValidationFailure.tooLong('Recording count', 500));
      }

      // Get recordings to delete
      final recordingsToDelete = <RecordingEntity>[];
      final notFoundIds = <String>[];

      for (final id in recordingIds) {
        final recording = await _recordingRepository.getRecordingById(id);
        if (recording != null) {
          recordingsToDelete.add(recording);
        } else {
          notFoundIds.add(id);
        }
      }

      // Calculate statistics (for potential future use in detailed results)

      // Perform deletions
      final deleteResults = <BulkOperationItemResult>[];
      final deletedRecordings = <RecordingEntity>[];
      final failedDeletions = <String, Failure>{};

      for (final recording in recordingsToDelete) {
        final deleteResult = await _recordingRepository.deleteRecording(recording.id);

        if (deleteResult) {
          deletedRecordings.add(recording);
          deleteResults.add(BulkOperationItemResult.success(
            recording.id,
            recording.name,
          ));
        } else {
          final failure = DatabaseFailure.deleteFailed('recordings', recording.id);
          failedDeletions[recording.id] = failure;
          deleteResults.add(BulkOperationItemResult.failure(
            recording.id,
            recording.name,
            failure,
          ));
        }
      }

      return Right(BulkDeleteResult(
        totalRequested: recordingIds.length,
        successfulOperations: deletedRecordings.length,
        failedOperations: failedDeletions.length,
        notFoundCount: notFoundIds.length,
        deletedRecordings: deletedRecordings,
        failedDeletions: failedDeletions,
        notFoundIds: notFoundIds,
        totalSizeDeleted: deletedRecordings.fold<int>(0, (sum, r) => sum + r.fileSize),
        totalDurationDeleted: DurationExtensions.sum(deletedRecordings.map((r) => r.duration).toList()),
        results: deleteResults,
        completedAt: DateTime.now(),
      ));

    } catch (e) {
      return Left(UnexpectedFailure(
        message: 'Bulk delete operation failed: ${e.toString()}',
        code: 'BULK_DELETE_FAILED',
      ));
    }
  }

  /// Rename multiple recordings with pattern
  Future<Either<Failure, BulkRenameResult>> bulkRename({
    required List<String> recordingIds,
    required String namePattern,
    bool includeSequenceNumber = true,
  }) async {
    try {
      // Validate input
      if (recordingIds.isEmpty) {
        return Left(ValidationFailure.required('Recording IDs'));
      }

      if (namePattern.isBlank) {
        return Left(ValidationFailure.required('Name pattern'));
      }

      if (!namePattern.isValidFileName) {
        return Left(ValidationFailure.invalidFormat(
          'Name pattern',
          'Contains invalid characters',
        ));
      }

      // Get recordings to rename
      final recordingsToRename = <RecordingEntity>[];
      for (final id in recordingIds) {
        final recording = await _recordingRepository.getRecordingById(id);
        if (recording != null) {
          recordingsToRename.add(recording);
        }
      }

      // Generate new names
      final renameOperations = <RenameOperation>[];
      for (int i = 0; i < recordingsToRename.length; i++) {
        final recording = recordingsToRename[i];
        final newName = _generateNewName(
          namePattern,
          i + 1,
          includeSequenceNumber,
          recording,
        );

        renameOperations.add(RenameOperation(
          recording: recording,
          newName: newName,
          originalName: recording.name,
        ));
      }

      // Check for duplicate names
      final duplicateCheck = _checkForDuplicateNames(renameOperations);
      if (duplicateCheck != null) {
        return Left(duplicateCheck);
      }

      // Perform renames
      final renameResults = <BulkOperationItemResult>[];
      final renamedRecordings = <RecordingEntity>[];
      final failedRenames = <String, Failure>{};

      for (final operation in renameOperations) {
        final updatedRecording = operation.recording.copyWith(
          name: operation.newName,
          updatedAt: DateTime.now(),
        );

        final updateResult = await _recordingRepository.updateRecording(updatedRecording);
        // updateRecording returns the updated entity, so if it succeeds we get the entity back
        try {
          renamedRecordings.add(updateResult);
          renameResults.add(BulkOperationItemResult.success(
            operation.recording.id,
            operation.newName,
          ));
        } catch (e) {
          final failure = DatabaseFailure.updateFailed('recordings', {'id': operation.recording.id});
          failedRenames[operation.recording.id] = failure;
          renameResults.add(BulkOperationItemResult.failure(
            operation.recording.id,
            operation.originalName,
            failure,
          ));
        }
      }

      return Right(BulkRenameResult(
        totalRequested: recordingIds.length,
        successfulOperations: renamedRecordings.length,
        failedOperations: failedRenames.length,
        renamedRecordings: renamedRecordings,
        failedRenames: failedRenames,
        namePattern: namePattern,
        results: renameResults,
        completedAt: DateTime.now(),
      ));

    } catch (e) {
      return Left(UnexpectedFailure(
        message: 'Bulk rename operation failed: ${e.toString()}',
        code: 'BULK_RENAME_FAILED',
      ));
    }
  }

  /// Export multiple recordings to a specific format
  Future<Either<Failure, BulkExportResult>> bulkExport({
    required List<String> recordingIds,
    required String exportPath,
    String? exportFormat,
    bool includeMetadata = true,
  }) async {
    try {
      // Validate input
      if (recordingIds.isEmpty) {
        return Left(ValidationFailure.required('Recording IDs'));
      }

      if (exportPath.isBlank) {
        return Left(ValidationFailure.required('Export path'));
      }

      // Get recordings to export
      final recordingsToExport = <RecordingEntity>[];
      for (final id in recordingIds) {
        final recording = await _recordingRepository.getRecordingById(id);
        if (recording != null) {
          recordingsToExport.add(recording);
        }
      }

      // Perform exports (placeholder implementation)
      final exportResults = <BulkOperationItemResult>[];
      final exportedRecordings = <RecordingEntity>[];
      final failedExports = <String, Failure>{};

      for (final recording in recordingsToExport) {
        // TODO: Implement actual export logic
        // For now, simulate export success
        exportedRecordings.add(recording);
        exportResults.add(BulkOperationItemResult.success(
          recording.id,
          recording.name,
        ));
      }

      return Right(BulkExportResult(
        totalRequested: recordingIds.length,
        successfulOperations: exportedRecordings.length,
        failedOperations: failedExports.length,
        exportedRecordings: exportedRecordings,
        failedExports: failedExports,
        exportPath: exportPath,
        exportFormat: exportFormat,
        results: exportResults,
        completedAt: DateTime.now(),
      ));

    } catch (e) {
      return Left(UnexpectedFailure(
        message: 'Bulk export operation failed: ${e.toString()}',
        code: 'BULK_EXPORT_FAILED',
      ));
    }
  }

  /// Add tags to multiple recordings
  Future<Either<Failure, BulkTagResult>> bulkAddTags({
    required List<String> recordingIds,
    required List<String> tagsToAdd,
  }) async {
    try {
      // Validate input
      if (recordingIds.isEmpty) {
        return Left(ValidationFailure.required('Recording IDs'));
      }

      if (tagsToAdd.isEmpty) {
        return Left(ValidationFailure.required('Tags to add'));
      }

      // Validate tags
      for (final tag in tagsToAdd) {
        if (tag.isBlank) {
          return Left(ValidationFailure.invalidFormat('Tags', 'Empty tag not allowed'));
        }
        if (tag.length > 50) {
          return Left(ValidationFailure.tooLong('Tag', 50));
        }
      }

      // Process recordings
      final tagResults = <BulkOperationItemResult>[];
      final taggedRecordings = <RecordingEntity>[];
      final failedTags = <String, Failure>{};

      for (final id in recordingIds) {
        final recording = await _recordingRepository.getRecordingById(id);

        if (recording != null) {
          // Add new tags (avoid duplicates)
          final existingTags = Set<String>.from(recording.tags);
          final newTags = Set<String>.from(tagsToAdd);
          final combinedTags = existingTags.union(newTags).toList();

          final updatedRecording = recording.copyWith(
            tags: combinedTags,
            updatedAt: DateTime.now(),
          );

          try {
            final updated = await _recordingRepository.updateRecording(updatedRecording);
            taggedRecordings.add(updated);
            tagResults.add(BulkOperationItemResult.success(id, recording.name));
          } catch (e) {
            final failure = DatabaseFailure.updateFailed('recordings', {'id': id});
            failedTags[id] = failure;
            tagResults.add(BulkOperationItemResult.failure(id, recording.name, failure));
          }
        } else {
          final failure = DatabaseFailure.queryFailed('getRecordingById', 'Recording not found: $id');
          failedTags[id] = failure;
          tagResults.add(BulkOperationItemResult.failure(id, 'Unknown', failure));
        }
      }

      return Right(BulkTagResult(
        totalRequested: recordingIds.length,
        successfulOperations: taggedRecordings.length,
        failedOperations: failedTags.length,
        taggedRecordings: taggedRecordings,
        failedTags: failedTags,
        addedTags: tagsToAdd,
        results: tagResults,
        completedAt: DateTime.now(),
      ));

    } catch (e) {
      return Left(UnexpectedFailure(
        message: 'Bulk tag operation failed: ${e.toString()}',
        code: 'BULK_TAG_FAILED',
      ));
    }
  }

  /// Remove tags from multiple recordings
  Future<Either<Failure, BulkTagResult>> bulkRemoveTags({
    required List<String> recordingIds,
    required List<String> tagsToRemove,
  }) async {
    try {
      // Validate input
      if (recordingIds.isEmpty) {
        return Left(ValidationFailure.required('Recording IDs'));
      }

      if (tagsToRemove.isEmpty) {
        return Left(ValidationFailure.required('Tags to remove'));
      }

      // Process recordings
      final tagResults = <BulkOperationItemResult>[];
      final untaggedRecordings = <RecordingEntity>[];
      final failedUntags = <String, Failure>{};

      for (final id in recordingIds) {
        final recording = await _recordingRepository.getRecordingById(id);

        if (recording != null) {
          // Remove specified tags
          final existingTags = Set<String>.from(recording.tags);
          final tagsToRemoveSet = Set<String>.from(tagsToRemove);
          final remainingTags = existingTags.difference(tagsToRemoveSet).toList();

          final updatedRecording = recording.copyWith(
            tags: remainingTags,
            updatedAt: DateTime.now(),
          );

          try {
            final updated = await _recordingRepository.updateRecording(updatedRecording);
            untaggedRecordings.add(updated);
            tagResults.add(BulkOperationItemResult.success(id, recording.name));
          } catch (e) {
            final failure = DatabaseFailure.updateFailed('recordings', {'id': id});
            failedUntags[id] = failure;
            tagResults.add(BulkOperationItemResult.failure(id, recording.name, failure));
          }
        } else {
          final failure = DatabaseFailure.queryFailed('getRecordingById', 'Recording not found: $id');
          failedUntags[id] = failure;
          tagResults.add(BulkOperationItemResult.failure(id, 'Unknown', failure));
        }
      }

      return Right(BulkTagResult(
        totalRequested: recordingIds.length,
        successfulOperations: untaggedRecordings.length,
        failedOperations: failedUntags.length,
        taggedRecordings: untaggedRecordings,
        failedTags: failedUntags,
        addedTags: [], // Empty for removal operation
        removedTags: tagsToRemove,
        results: tagResults,
        completedAt: DateTime.now(),
      ));

    } catch (e) {
      return Left(UnexpectedFailure(
        message: 'Bulk untag operation failed: ${e.toString()}',
        code: 'BULK_UNTAG_FAILED',
      ));
    }
  }

  /// Get detailed statistics for bulk operations planning
  Future<Either<Failure, BulkOperationStatistics>> getBulkOperationStatistics({
    required List<String> recordingIds,
  }) async {
    try {
      final recordings = <RecordingEntity>[];
      final notFoundIds = <String>[];

      // Collect recordings
      for (final id in recordingIds) {
        final recording = await _recordingRepository.getRecordingById(id);
        if (recording != null) {
          recordings.add(recording);
        } else {
          notFoundIds.add(id);
        }
      }

      // Calculate statistics
      final totalSize = recordings.fold<int>(0, (sum, r) => sum + r.fileSize);
      final totalDuration = DurationExtensions.sum(recordings.map((r) => r.duration).toList());
      final avgDuration = recordings.isEmpty
          ? Duration.zero
          : Duration(milliseconds: totalDuration.inMilliseconds ~/ recordings.length);

      // Group by folders
      final folderGroups = <String, List<RecordingEntity>>{};
      for (final recording in recordings) {
        folderGroups[recording.folderId] = (folderGroups[recording.folderId] ?? [])..add(recording);
      }

      // Group by formats
      final formatGroups = <String, List<RecordingEntity>>{};
      for (final recording in recordings) {
        final format = recording.format.name;
        formatGroups[format] = (formatGroups[format] ?? [])..add(recording);
      }

      return Right(BulkOperationStatistics(
        totalRecordings: recordings.length,
        notFoundCount: notFoundIds.length,
        totalFileSize: totalSize,
        totalDuration: totalDuration,
        averageDuration: avgDuration,
        shortestDuration: recordings.isEmpty ? Duration.zero : DurationExtensions.min(recordings.map((r) => r.duration).toList()),
        longestDuration: recordings.isEmpty ? Duration.zero : DurationExtensions.max(recordings.map((r) => r.duration).toList()),
        folderDistribution: folderGroups.map((k, v) => MapEntry(k, v.length)),
        formatDistribution: formatGroups.map((k, v) => MapEntry(k, v.length)),
        createdAt: DateTime.now(),
      ));

    } catch (e) {
      return Left(UnexpectedFailure(
        message: 'Statistics calculation failed: ${e.toString()}',
        code: 'STATISTICS_FAILED',
      ));
    }
  }

  // ==== PRIVATE METHODS ====

  /// Generate new name from pattern
  String _generateNewName(
      String pattern,
      int sequenceNumber,
      bool includeSequence,
      RecordingEntity recording,
      ) {
    String newName = pattern;

    // Replace placeholders
    newName = newName.replaceAll('{original}', recording.name);
    newName = newName.replaceAll('{date}', recording.createdAt.shortDateFormat);
    newName = newName.replaceAll('{time}', recording.createdAt.timeOnlyFormat);
    newName = newName.replaceAll('{duration}', recording.duration.formatted);
    newName = newName.replaceAll('{format}', recording.format.name.toUpperCase());

    if (includeSequence) {
      newName = newName.replaceAll('{number}', sequenceNumber.toString().padLeft(3, '0'));
      if (!newName.contains('{number}')) {
        newName = '$newName ${sequenceNumber.toString().padLeft(3, '0')}';
      }
    }

    return newName.safeFileName;
  }

  /// Check for duplicate names in rename operations
  ValidationFailure? _checkForDuplicateNames(List<RenameOperation> operations) {
    final names = operations.map((op) => op.newName.toLowerCase()).toList();
    final uniqueNames = names.toSet();

    if (uniqueNames.length != names.length) {
      return ValidationFailure.duplicate(
        'Recording names',
        'Pattern would create duplicate names',
      );
    }

    return null;
  }
}

// ==== BULK OPERATION RESULTS ====

/// Base result for bulk operations
abstract class BulkOperationResult {
  final int totalRequested;
  final int successfulOperations;
  final int failedOperations;
  final List<BulkOperationItemResult> results;
  final DateTime completedAt;

  const BulkOperationResult({
    required this.totalRequested,
    required this.successfulOperations,
    required this.failedOperations,
    required this.results,
    required this.completedAt,
  });

  /// Check if all operations were successful
  bool get allSuccessful => failedOperations == 0;

  /// Check if any operations were successful
  bool get anySuccessful => successfulOperations > 0;

  /// Get success rate (0.0 to 1.0)
  double get successRate {
    if (totalRequested == 0) return 0.0;
    return successfulOperations / totalRequested;
  }
}

/// Result of bulk delete operation
class BulkDeleteResult extends BulkOperationResult {
  final List<RecordingEntity> deletedRecordings;
  final Map<String, Failure> failedDeletions;
  final List<String> notFoundIds;
  final int notFoundCount;
  final int totalSizeDeleted;
  final Duration totalDurationDeleted;

  const BulkDeleteResult({
    required super.totalRequested,
    required super.successfulOperations,
    required super.failedOperations,
    required super.results,
    required super.completedAt,
    required this.deletedRecordings,
    required this.failedDeletions,
    required this.notFoundIds,
    required this.notFoundCount,
    required this.totalSizeDeleted,
    required this.totalDurationDeleted,
  });

  /// Get formatted size deleted
  String get formattedSizeDeleted {
    if (totalSizeDeleted < 1024) return '${totalSizeDeleted} bytes';
    if (totalSizeDeleted < 1024 * 1024) return '${(totalSizeDeleted / 1024).toStringAsFixed(1)} KB';
    if (totalSizeDeleted < 1024 * 1024 * 1024) return '${(totalSizeDeleted / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalSizeDeleted / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get deletion summary
  String get deletionSummary {
    if (allSuccessful) {
      return 'Successfully deleted $successfulOperations recording${successfulOperations == 1 ? '' : 's'} (${formattedSizeDeleted})';
    }

    return 'Deleted $successfulOperations of $totalRequested recordings ($failedOperations failed)';
  }
}

/// Result of bulk rename operation
class BulkRenameResult extends BulkOperationResult {
  final List<RecordingEntity> renamedRecordings;
  final Map<String, Failure> failedRenames;
  final String namePattern;

  const BulkRenameResult({
    required super.totalRequested,
    required super.successfulOperations,
    required super.failedOperations,
    required super.results,
    required super.completedAt,
    required this.renamedRecordings,
    required this.failedRenames,
    required this.namePattern,
  });

  /// Get rename summary
  String get renameSummary {
    if (allSuccessful) {
      return 'Successfully renamed $successfulOperations recording${successfulOperations == 1 ? '' : 's'}';
    }

    return 'Renamed $successfulOperations of $totalRequested recordings ($failedOperations failed)';
  }
}

/// Result of bulk export operation
class BulkExportResult extends BulkOperationResult {
  final List<RecordingEntity> exportedRecordings;
  final Map<String, Failure> failedExports;
  final String exportPath;
  final String? exportFormat;

  const BulkExportResult({
    required super.totalRequested,
    required super.successfulOperations,
    required super.failedOperations,
    required super.results,
    required super.completedAt,
    required this.exportedRecordings,
    required this.failedExports,
    required this.exportPath,
    this.exportFormat,
  });

  /// Get export summary
  String get exportSummary {
    if (allSuccessful) {
      return 'Successfully exported $successfulOperations recording${successfulOperations == 1 ? '' : 's'}';
    }

    return 'Exported $successfulOperations of $totalRequested recordings ($failedOperations failed)';
  }
}

/// Result of bulk tag operation
class BulkTagResult extends BulkOperationResult {
  final List<RecordingEntity> taggedRecordings;
  final Map<String, Failure> failedTags;
  final List<String> addedTags;
  final List<String> removedTags;

  const BulkTagResult({
    required super.totalRequested,
    required super.successfulOperations,
    required super.failedOperations,
    required super.results,
    required super.completedAt,
    required this.taggedRecordings,
    required this.failedTags,
    this.addedTags = const [],
    this.removedTags = const [],
  });

  /// Check if this was an add operation
  bool get isAddOperation => addedTags.isNotEmpty;

  /// Check if this was a remove operation
  bool get isRemoveOperation => removedTags.isNotEmpty;

  /// Get tag operation summary
  String get tagSummary {
    final operation = isAddOperation ? 'added tags to' : 'removed tags from';

    if (allSuccessful) {
      return 'Successfully $operation $successfulOperations recording${successfulOperations == 1 ? '' : 's'}';
    }

    return 'Successfully $operation $successfulOperations of $totalRequested recordings ($failedOperations failed)';
  }
}

/// Individual operation result
class BulkOperationItemResult {
  final String recordingId;
  final String recordingName;
  final bool success;
  final Failure? failure;
  final DateTime processedAt;

  const BulkOperationItemResult._({
    required this.recordingId,
    required this.recordingName,
    required this.success,
    this.failure,
    required this.processedAt,
  });

  factory BulkOperationItemResult.success(String id, String name) {
    return BulkOperationItemResult._(
      recordingId: id,
      recordingName: name,
      success: true,
      processedAt: DateTime.now(),
    );
  }

  factory BulkOperationItemResult.failure(String id, String name, Failure failure) {
    return BulkOperationItemResult._(
      recordingId: id,
      recordingName: name,
      success: false,
      failure: failure,
      processedAt: DateTime.now(),
    );
  }

  /// Get result description for UI
  String get resultDescription {
    if (success) {
      return 'Success: $recordingName';
    } else {
      return 'Failed: $recordingName (${failure?.userMessage ?? 'Unknown error'})';
    }
  }
}

/// Statistics for bulk operation planning
class BulkOperationStatistics {
  final int totalRecordings;
  final int notFoundCount;
  final int totalFileSize;
  final Duration totalDuration;
  final Duration averageDuration;
  final Duration shortestDuration;
  final Duration longestDuration;
  final Map<String, int> folderDistribution;
  final Map<String, int> formatDistribution;
  final DateTime createdAt;

  const BulkOperationStatistics({
    required this.totalRecordings,
    required this.notFoundCount,
    required this.totalFileSize,
    required this.totalDuration,
    required this.averageDuration,
    required this.shortestDuration,
    required this.longestDuration,
    required this.folderDistribution,
    required this.formatDistribution,
    required this.createdAt,
  });

  /// Get formatted total file size
  String get formattedTotalSize {
    if (totalFileSize < 1024) return '${totalFileSize} bytes';
    if (totalFileSize < 1024 * 1024) return '${(totalFileSize / 1024).toStringAsFixed(1)} KB';
    if (totalFileSize < 1024 * 1024 * 1024) return '${(totalFileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalFileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get statistics summary for UI
  String get statisticsSummary {
    if (totalRecordings == 0) {
      return 'No recordings found';
    }

    final parts = <String>[
      '$totalRecordings recording${totalRecordings == 1 ? '' : 's'}',
      formattedTotalSize,
      totalDuration.formatted,
    ];

    if (notFoundCount > 0) {
      parts.add('$notFoundCount not found');
    }

    return parts.join(', ');
  }

  /// Get folder distribution description
  String get folderDistributionDescription {
    if (folderDistribution.isEmpty) return 'No folders';

    final sortedFolders = folderDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedFolders.length == 1) {
      return 'All in one folder';
    }

    return '${sortedFolders.length} folder${sortedFolders.length == 1 ? '' : 's'}';
  }

  /// Get format distribution description
  String get formatDistributionDescription {
    if (formatDistribution.isEmpty) return 'No formats';

    final sortedFormats = formatDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedFormats.length == 1) {
      return 'All ${sortedFormats.first.key.toUpperCase()}';
    }

    return sortedFormats.map((e) => '${e.value} ${e.key.toUpperCase()}').join(', ');
  }
}

/// Rename operation helper class
class RenameOperation {
  final RecordingEntity recording;
  final String newName;
  final String originalName;

  const RenameOperation({
    required this.recording,
    required this.newName,
    required this.originalName,
  });

  /// Check if name will actually change
  bool get willChange => newName != originalName;

  /// Get preview description
  String get previewDescription => '$originalName → $newName';
}