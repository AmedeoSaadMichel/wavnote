import '../entities/folder_entity.dart';

/// Repository interface for folder operations
///
/// Defines the contract for folder data access operations.
/// This interface allows for different implementations (SQLite, API, etc.)
/// while keeping the domain layer independent of specific technologies.
abstract class IFolderRepository {

  // ==== FOLDER CRUD OPERATIONS ====

  /// Get all folders (default + custom)
  Future<List<FolderEntity>> getAllFolders();

  /// Get only custom folders
  Future<List<FolderEntity>> getCustomFolders();

  /// Get folder by ID
  Future<FolderEntity?> getFolderById(String id);

  /// Create a new custom folder
  Future<FolderEntity> createFolder(FolderEntity folder);

  /// Update an existing folder
  Future<FolderEntity> updateFolder(FolderEntity folder);

  /// Delete a folder by ID
  Future<bool> deleteFolder(String id);

  /// Check if folder exists by name
  Future<bool> folderExistsByName(String name, {String? excludeId});

  // ==== FOLDER COUNT OPERATIONS ====

  /// Update folder recording count
  Future<bool> updateFolderCount(String folderId, int newCount);

  /// Increment folder recording count
  Future<bool> incrementFolderCount(String folderId);

  /// Decrement folder recording count
  Future<bool> decrementFolderCount(String folderId);

  // ==== BATCH OPERATIONS ====

  /// Get folders with recording count greater than zero
  Future<List<FolderEntity>> getFoldersWithRecordings();

  /// Get folders sorted by criteria
  Future<List<FolderEntity>> getFoldersSorted(FolderSortCriteria criteria);

  /// Search folders by name
  Future<List<FolderEntity>> searchFolders(String query);

  // ==== UTILITY OPERATIONS ====

  /// Get total recording count across all folders
  Future<int> getTotalRecordingCount();

  /// Export folder data for backup
  Future<Map<String, dynamic>> exportFolders();

  /// Import folder data from backup
  Future<bool> importFolders(Map<String, dynamic> data);

  /// Clear all custom folders (keep default folders)
  Future<bool> clearCustomFolders();
}

/// Criteria for sorting folders
enum FolderSortCriteria {
  name,
  createdDate,
  recordingCount,
  lastModified,
}

/// Extension for sort criteria display names
extension FolderSortCriteriaExtension on FolderSortCriteria {
  String get displayName {
    switch (this) {
      case FolderSortCriteria.name:
        return 'Name';
      case FolderSortCriteria.createdDate:
        return 'Date Created';
      case FolderSortCriteria.recordingCount:
        return 'Recording Count';
      case FolderSortCriteria.lastModified:
        return 'Last Modified';
    }
  }

  String get sqlOrderBy {
    switch (this) {
      case FolderSortCriteria.name:
        return 'name COLLATE NOCASE ASC';
      case FolderSortCriteria.createdDate:
        return 'created_at DESC';
      case FolderSortCriteria.recordingCount:
        return 'recording_count DESC';
      case FolderSortCriteria.lastModified:
        return 'updated_at DESC';
    }
  }
}