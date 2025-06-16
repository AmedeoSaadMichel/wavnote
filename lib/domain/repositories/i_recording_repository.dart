// File: domain/repositories/i_recording_repository.dart
import '../entities/recording_entity.dart';
import '../../core/enums/audio_format.dart';

/// Repository interface for recording operations
///
/// Defines the contract for recording data access operations.
/// This interface allows for different implementations (SQLite, API, etc.)
/// while keeping the domain layer independent of specific technologies.
abstract class IRecordingRepository {

  // ==== RECORDING CRUD OPERATIONS ====

  /// Get all recordings across all folders
  Future<List<RecordingEntity>> getAllRecordings();

  /// Get recordings for a specific folder
  Future<List<RecordingEntity>> getRecordingsByFolder(String folderId);

  /// Get recording by ID
  Future<RecordingEntity?> getRecordingById(String id);

  /// Create a new recording
  Future<RecordingEntity> createRecording(RecordingEntity recording);

  /// Update an existing recording
  Future<RecordingEntity> updateRecording(RecordingEntity recording);

  /// Delete a recording by ID
  Future<bool> deleteRecording(String id);

  // ==== SEARCH & FILTER OPERATIONS ====

  /// Search recordings by name or location
  Future<List<RecordingEntity>> searchRecordings(String query);

  /// Get recordings by audio format
  Future<List<RecordingEntity>> getRecordingsByFormat(AudioFormat format);

  /// Get favorite recordings
  Future<List<RecordingEntity>> getFavoriteRecordings();

  /// Get recordings within date range
  Future<List<RecordingEntity>> getRecordingsByDateRange(
      DateTime startDate,
      DateTime endDate,
      );

  /// Get recordings by duration range
  Future<List<RecordingEntity>> getRecordingsByDurationRange(
      Duration minDuration,
      Duration maxDuration,
      );

  /// Get recordings sorted by criteria
  Future<List<RecordingEntity>> getRecordingsSorted(
      RecordingSortCriteria criteria,
      );

  // ==== BULK OPERATIONS ====

  /// Move multiple recordings to a different folder
  Future<bool> moveRecordingsToFolder(
      List<String> recordingIds,
      String folderId,
      );

  /// Delete multiple recordings
  Future<bool> deleteRecordings(List<String> recordingIds);

  /// Mark multiple recordings as favorite/unfavorite
  Future<bool> updateRecordingsFavoriteStatus(
      List<String> recordingIds,
      bool isFavorite,
      );

  /// Add tags to multiple recordings
  Future<bool> addTagsToRecordings(
      List<String> recordingIds,
      List<String> tags,
      );

  // ==== STATISTICS OPERATIONS ====

  /// Get recording count for a folder
  Future<int> getRecordingCountByFolder(String folderId);

  /// Get total duration for recordings in a folder
  Future<Duration> getTotalDurationByFolder(String folderId);

  /// Get total file size for recordings in a folder
  Future<int> getTotalFileSizeByFolder(String folderId);

  /// Get recording statistics by format
  Future<Map<AudioFormat, int>> getRecordingCountsByFormat();

  /// Get recording statistics by date
  Future<Map<DateTime, int>> getRecordingCountsByDate(
      DateTime startDate,
      DateTime endDate,
      );

  // ==== MAINTENANCE OPERATIONS ====

  /// Verify recording files exist on disk
  Future<List<String>> getOrphanedRecordings();

  /// Clean up orphaned recordings (database entries without files)
  Future<int> cleanupOrphanedRecordings();

  /// Rebuild recording indices for performance
  Future<bool> rebuildIndices();

  /// Validate all recording data integrity
  Future<List<String>> validateRecordingIntegrity();

  // ==== BACKUP & EXPORT OPERATIONS ====

  /// Export recordings metadata to JSON
  Future<Map<String, dynamic>> exportRecordings();

  /// Import recordings metadata from JSON
  Future<bool> importRecordings(Map<String, dynamic> data);

  /// Clear all recordings (for testing/reset)
  Future<bool> clearAllRecordings();

  /// Get recordings that need to be backed up
  Future<List<RecordingEntity>> getRecordingsForBackup();
}

/// Criteria for sorting recordings
enum RecordingSortCriteria {
  name,
  createdDate,
  duration,
  fileSize,
  lastModified,
  format,
}

/// Extension for sort criteria display names
extension RecordingSortCriteriaExtension on RecordingSortCriteria {
  String get displayName {
    switch (this) {
      case RecordingSortCriteria.name:
        return 'Name';
      case RecordingSortCriteria.createdDate:
        return 'Date Created';
      case RecordingSortCriteria.duration:
        return 'Duration';
      case RecordingSortCriteria.fileSize:
        return 'File Size';
      case RecordingSortCriteria.lastModified:
        return 'Last Modified';
      case RecordingSortCriteria.format:
        return 'Format';
    }
  }

  String get sqlOrderBy {
    switch (this) {
      case RecordingSortCriteria.name:
        return 'name COLLATE NOCASE ASC';
      case RecordingSortCriteria.createdDate:
        return 'created_at DESC';
      case RecordingSortCriteria.duration:
        return 'duration_seconds DESC';
      case RecordingSortCriteria.fileSize:
        return 'file_size DESC';
      case RecordingSortCriteria.lastModified:
        return 'updated_at DESC';
      case RecordingSortCriteria.format:
        return 'format_index ASC, name ASC';
    }
  }
}

/// Recording filter options
class RecordingFilter {
  final String? folderId;
  final AudioFormat? format;
  final bool? isFavorite;
  final Duration? minDuration;
  final Duration? maxDuration;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? tags;

  const RecordingFilter({
    this.folderId,
    this.format,
    this.isFavorite,
    this.minDuration,
    this.maxDuration,
    this.startDate,
    this.endDate,
    this.tags,
  });

  /// Whether any filters are active
  bool get hasActiveFilters =>
      folderId != null ||
          format != null ||
          isFavorite != null ||
          minDuration != null ||
          maxDuration != null ||
          startDate != null ||
          endDate != null ||
          (tags?.isNotEmpty ?? false);

  /// Create copy with updated values
  RecordingFilter copyWith({
    String? folderId,
    AudioFormat? format,
    bool? isFavorite,
    Duration? minDuration,
    Duration? maxDuration,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tags,
  }) {
    return RecordingFilter(
      folderId: folderId ?? this.folderId,
      format: format ?? this.format,
      isFavorite: isFavorite ?? this.isFavorite,
      minDuration: minDuration ?? this.minDuration,
      maxDuration: maxDuration ?? this.maxDuration,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      tags: tags ?? this.tags,
    );
  }

  /// Clear all filters
  RecordingFilter clear() {
    return const RecordingFilter();
  }
}