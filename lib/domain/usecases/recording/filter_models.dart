// File: domain/usecases/recording/filter_models.dart
import '../../entities/recording_entity.dart';
import '../../../core/enums/audio_format.dart';

// ==== FAILURE CLASSES ====

/// Base failure class
abstract class Failure {
  final String message;
  const Failure(this.message);
}

/// Database-related failures
class DatabaseFailure extends Failure {
  final String operation;

  const DatabaseFailure._(String message, this.operation) : super(message);

  factory DatabaseFailure.queryFailed(String operation, String details) {
    return DatabaseFailure._('Database query failed: $details', operation);
  }
}

/// Validation-related failures
class ValidationFailure extends Failure {
  final String field;

  const ValidationFailure._(String message, this.field) : super(message);

  factory ValidationFailure.invalidFormat(String field, String details) {
    return ValidationFailure._('Invalid $field: $details', field);
  }
}

// ==== FILTER CRITERIA ====

/// Comprehensive filter criteria for recordings
class FilterCriteria {
  final String? folderId;
  final DateTime? startDate;
  final DateTime? endDate;
  final Duration? minDuration;
  final Duration? maxDuration;
  final int? minFileSize;
  final int? maxFileSize;
  final List<AudioFormat>? formats;
  final bool? hasTags;
  final FilterSortBy? sortBy;

  const FilterCriteria({
    this.folderId,
    this.startDate,
    this.endDate,
    this.minDuration,
    this.maxDuration,
    this.minFileSize,
    this.maxFileSize,
    this.formats,
    this.hasTags,
    this.sortBy,
  });

  /// Create criteria for date range filtering
  factory FilterCriteria.dateRange(DateTime start, DateTime end) {
    return FilterCriteria(
      startDate: start,
      endDate: end,
      sortBy: FilterSortBy.dateDescending,
    );
  }

  /// Create criteria for duration filtering
  factory FilterCriteria.durationRange(Duration min, Duration max) {
    return FilterCriteria(
      minDuration: min,
      maxDuration: max,
      sortBy: FilterSortBy.durationDescending,
    );
  }

  /// Create criteria for format filtering
  factory FilterCriteria.formats(List<AudioFormat> formats) {
    return FilterCriteria(
      formats: formats,
      sortBy: FilterSortBy.dateDescending,
    );
  }

  /// Create criteria for folder filtering
  factory FilterCriteria.folder(String folderId) {
    return FilterCriteria(
      folderId: folderId,
      sortBy: FilterSortBy.dateDescending,
    );
  }

  /// Check if any filters are active
  bool get hasActiveFilters {
    return folderId != null ||
        startDate != null ||
        endDate != null ||
        minDuration != null ||
        maxDuration != null ||
        minFileSize != null ||
        maxFileSize != null ||
        formats?.isNotEmpty == true ||
        hasTags != null;
  }

  /// Get human-readable description of active filters
  String get filtersDescription {
    final parts = <String>[];

    if (startDate != null || endDate != null) {
      if (startDate != null && endDate != null) {
        parts.add('Date: ${_formatDate(startDate!)} - ${_formatDate(endDate!)}');
      } else if (startDate != null) {
        parts.add('After: ${_formatDate(startDate!)}');
      } else {
        parts.add('Before: ${_formatDate(endDate!)}');
      }
    }

    if (minDuration != null || maxDuration != null) {
      if (minDuration != null && maxDuration != null) {
        parts.add('Duration: ${_formatDuration(minDuration!)} - ${_formatDuration(maxDuration!)}');
      } else if (minDuration != null) {
        parts.add('Min duration: ${_formatDuration(minDuration!)}');
      } else {
        parts.add('Max duration: ${_formatDuration(maxDuration!)}');
      }
    }

    if (formats?.isNotEmpty == true) {
      parts.add('Formats: ${formats!.map((f) => f.name.toUpperCase()).join(', ')}');
    }

    if (hasTags == true) {
      parts.add('Has tags');
    } else if (hasTags == false) {
      parts.add('No tags');
    }

    return parts.isEmpty ? 'No filters' : parts.join(', ');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Time periods for filtering
enum TimePeriod {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisYear,
  lastYear,
}

/// Duration categories for filtering
enum DurationFilterCategory {
  quickNotes,       // < 30 seconds
  shortRecordings,  // 30 seconds - 5 minutes
  mediumRecordings, // 5 minutes - 30 minutes
  longRecordings,   // 30 minutes - 2 hours
  extendedRecordings, // > 2 hours
}

/// File size categories for filtering
enum FileSizeCategory {
  tiny,   // < 1MB
  small,  // 1MB - 10MB
  medium, // 10MB - 50MB
  large,  // 50MB - 200MB
  huge,   // > 200MB
}

/// Sort options for filtered results
enum FilterSortBy {
  nameAscending,
  nameDescending,
  dateAscending,
  dateDescending,
  durationAscending,
  durationDescending,
  sizeAscending,
  sizeDescending,
}

// ==== FILTER RESULT ====

/// Result of filtering operation with metadata
class FilterResult {
  final List<RecordingEntity> recordings;
  final int originalCount;
  final int filteredCount;
  final FilterCriteria criteria;
  final DateTime appliedAt;

  const FilterResult({
    required this.recordings,
    required this.originalCount,
    required this.filteredCount,
    required this.criteria,
    required this.appliedAt,
  });

  /// Check if filter has results
  bool get hasResults => recordings.isNotEmpty;

  /// Check if filter reduced the result set
  bool get hasReduced => filteredCount < originalCount;

  /// Get filter efficiency (0.0 to 1.0)
  double get filterEfficiency {
    if (originalCount == 0) return 0.0;
    return filteredCount / originalCount;
  }

  /// Get filter summary for UI
  String get filterSummary {
    if (!hasResults) {
      return 'No recordings match the current filters';
    }

    if (!hasReduced) {
      return 'All $originalCount recordings shown';
    }

    return 'Showing $filteredCount of $originalCount recordings';
  }

  /// Get detailed filter description
  String get detailedDescription {
    final summary = filterSummary;
    if (!criteria.hasActiveFilters) {
      return summary;
    }

    return '$summary\nFilters: ${criteria.filtersDescription}';
  }
}