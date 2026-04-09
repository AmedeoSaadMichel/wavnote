// File: data/mappers/folder_sort_mapper.dart
//
// Folder Sort Mapper - Data Layer
// =================================
//
// Maps domain FolderSortCriteria to SQL ORDER BY clauses.
// Keeps SQL-specific logic in the data layer.

import '../../domain/repositories/i_folder_repository.dart';

/// Maps FolderSortCriteria to SQL ORDER BY clause
class FolderSortMapper {
  static String toSqlOrderBy(FolderSortCriteria criteria) {
    switch (criteria) {
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
