// File: data/mappers/recording_sort_mapper.dart
//
// Recording Sort Mapper - Data Layer
// ====================================
//
// Maps domain RecordingSortCriteria to SQL ORDER BY clauses.
// Keeps SQL-specific logic in the data layer.

import '../../domain/repositories/i_recording_repository.dart';

/// Maps RecordingSortCriteria to SQL ORDER BY clause
class RecordingSortMapper {
  static String toSqlOrderBy(RecordingSortCriteria criteria) {
    switch (criteria) {
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
