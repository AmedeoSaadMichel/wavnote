// File: domain/usecases/recording/filter_recordings_usecase.dart
import 'package:dartz/dartz.dart';
import '../../entities/recording_entity.dart';
import '../../repositories/i_recording_repository.dart';
import '../../../core/enums/audio_format.dart';
import 'filter_models.dart';
import 'filter_statistics.dart';

/// Use case for filtering recordings with advanced criteria
///
/// Provides comprehensive filtering capabilities including date ranges,
/// duration filters, format filtering, and statistical grouping.
/// Works in conjunction with SearchRecordingsUseCase for complete search functionality.
class FilterRecordingsUseCase {
  final IRecordingRepository _repository;

  const FilterRecordingsUseCase(this._repository);

  /// Apply comprehensive filters to recordings
  Future<Either<Failure, FilterResult>> call(FilterCriteria criteria) async {
    try {
      // Validate filter criteria
      final validationResult = _validateFilterCriteria(criteria);
      if (validationResult != null) {
        return Left(validationResult);
      }

      // Get recordings to filter
      List<RecordingEntity> recordings;

      if (criteria.folderId != null) {
        recordings = await _repository.getRecordingsByFolder(criteria.folderId!);
      } else {
        recordings = await _repository.getAllRecordings();
      }

      // Apply filters
      final filteredRecordings = _applyFilters(recordings, criteria);

      // Apply sorting
      final sortedRecordings = _applySorting(filteredRecordings, criteria);

      return Right(FilterResult(
        recordings: sortedRecordings,
        originalCount: recordings.length,
        filteredCount: filteredRecordings.length,
        criteria: criteria,
        appliedAt: DateTime.now(),
      ));

    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'filter_recordings',
        'Filter operation failed: ${e.toString()}',
      ));
    }
  }

  /// Filter by date ranges with predefined periods
  Future<Either<Failure, List<RecordingEntity>>> filterByTimePeriod(
      TimePeriod period,
      ) async {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case TimePeriod.today:
        startDate = _getStartOfDay(now);
        break;
      case TimePeriod.yesterday:
        startDate = _getStartOfDay(now.subtract(const Duration(days: 1)));
        break;
      case TimePeriod.thisWeek:
        startDate = _getStartOfWeek(now);
        break;
      case TimePeriod.lastWeek:
        final weekAgo = now.subtract(const Duration(days: 7));
        startDate = _getStartOfWeek(weekAgo);
        break;
      case TimePeriod.thisMonth:
        startDate = _getStartOfMonth(now);
        break;
      case TimePeriod.lastMonth:
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        startDate = _getStartOfMonth(monthAgo);
        break;
      case TimePeriod.thisYear:
        startDate = _getStartOfYear(now);
        break;
      case TimePeriod.lastYear:
        startDate = DateTime(now.year - 1, 1, 1);
        break;
    }

    final endDate = _getEndDateForPeriod(period, startDate, now);

    final criteria = FilterCriteria(
      startDate: startDate,
      endDate: endDate,
      sortBy: FilterSortBy.dateDescending,
    );

    final result = await call(criteria);
    return result.fold(
          (failure) => Left(failure),
          (filterResult) => Right(filterResult.recordings),
    );
  }

  /// Filter by duration categories
  Future<Either<Failure, List<RecordingEntity>>> filterByDurationCategory(
      DurationFilterCategory category,
      ) async {
    Duration? minDuration, maxDuration;

    switch (category) {
      case DurationFilterCategory.quickNotes:
        maxDuration = const Duration(seconds: 30);
        break;
      case DurationFilterCategory.shortRecordings:
        minDuration = const Duration(seconds: 30);
        maxDuration = const Duration(minutes: 5);
        break;
      case DurationFilterCategory.mediumRecordings:
        minDuration = const Duration(minutes: 5);
        maxDuration = const Duration(minutes: 30);
        break;
      case DurationFilterCategory.longRecordings:
        minDuration = const Duration(minutes: 30);
        maxDuration = const Duration(hours: 2);
        break;
      case DurationFilterCategory.extendedRecordings:
        minDuration = const Duration(hours: 2);
        break;
    }

    final criteria = FilterCriteria(
      minDuration: minDuration,
      maxDuration: maxDuration,
      sortBy: FilterSortBy.durationDescending,
    );

    final result = await call(criteria);
    return result.fold(
          (failure) => Left(failure),
          (filterResult) => Right(filterResult.recordings),
    );
  }

  /// Filter by audio format
  Future<Either<Failure, List<RecordingEntity>>> filterByFormat(
      AudioFormat format,
      ) async {
    final criteria = FilterCriteria(
      formats: [format],
      sortBy: FilterSortBy.dateDescending,
    );

    final result = await call(criteria);
    return result.fold(
          (failure) => Left(failure),
          (filterResult) => Right(filterResult.recordings),
    );
  }

  /// Filter by file size categories
  Future<Either<Failure, List<RecordingEntity>>> filterByFileSize(
      FileSizeCategory category,
      ) async {
    int? minSize, maxSize;

    switch (category) {
      case FileSizeCategory.tiny:
        maxSize = 1024 * 1024; // 1MB
        break;
      case FileSizeCategory.small:
        minSize = 1024 * 1024; // 1MB
        maxSize = 10 * 1024 * 1024; // 10MB
        break;
      case FileSizeCategory.medium:
        minSize = 10 * 1024 * 1024; // 10MB
        maxSize = 50 * 1024 * 1024; // 50MB
        break;
      case FileSizeCategory.large:
        minSize = 50 * 1024 * 1024; // 50MB
        maxSize = 200 * 1024 * 1024; // 200MB
        break;
      case FileSizeCategory.huge:
        minSize = 200 * 1024 * 1024; // 200MB
        break;
    }

    final criteria = FilterCriteria(
      minFileSize: minSize,
      maxFileSize: maxSize,
      sortBy: FilterSortBy.sizeDescending,
    );

    final result = await call(criteria);
    return result.fold(
          (failure) => Left(failure),
          (filterResult) => Right(filterResult.recordings),
    );
  }

  /// Get recordings grouped by date periods
  Future<Either<Failure, Map<String, List<RecordingEntity>>>> getGroupedByDate() async {
    try {
      final recordings = await _repository.getAllRecordings();
      final grouped = <String, List<RecordingEntity>>{};

      for (final recording in recordings) {
        final category = _getRecordingAgeCategory(recording.createdAt);
        grouped[category] = (grouped[category] ?? [])..add(recording);
      }

      // Sort each group by date descending
      for (final key in grouped.keys) {
        grouped[key]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      return Right(grouped);
    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'group_by_date',
        'Failed to group recordings by date: ${e.toString()}',
      ));
    }
  }

  /// Get recordings grouped by duration categories
  Future<Either<Failure, Map<String, List<RecordingEntity>>>> getGroupedByDuration() async {
    try {
      final recordings = await _repository.getAllRecordings();
      final grouped = <String, List<RecordingEntity>>{};

      for (final recording in recordings) {
        final category = _getDurationCategoryName(recording.duration);
        grouped[category] = (grouped[category] ?? [])..add(recording);
      }

      return Right(grouped);
    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'group_by_duration',
        'Failed to group recordings by duration: ${e.toString()}',
      ));
    }
  }

  /// Get recordings statistics for filters
  Future<Either<Failure, FilterStatistics>> getFilterStatistics() async {
    try {
      final recordings = await _repository.getAllRecordings();
      final stats = FilterStatistics.fromRecordings(recordings);
      return Right(stats);
    } catch (e) {
      return Left(DatabaseFailure.queryFailed(
        'filter_statistics',
        'Failed to get filter statistics: ${e.toString()}',
      ));
    }
  }

  // ==== PRIVATE METHODS ====

  /// Validate filter criteria
  ValidationFailure? _validateFilterCriteria(FilterCriteria criteria) {
    // Validate date range
    if (criteria.startDate != null && criteria.endDate != null) {
      if (criteria.startDate!.isAfter(criteria.endDate!)) {
        return ValidationFailure.invalidFormat(
          'Date range',
          'Start date must be before end date',
        );
      }
    }

    // Validate duration range
    if (criteria.minDuration != null && criteria.maxDuration != null) {
      if (criteria.minDuration! > criteria.maxDuration!) {
        return ValidationFailure.invalidFormat(
          'Duration range',
          'Minimum duration must be less than maximum duration',
        );
      }
    }

    // Validate file size range
    if (criteria.minFileSize != null && criteria.maxFileSize != null) {
      if (criteria.minFileSize! > criteria.maxFileSize!) {
        return ValidationFailure.invalidFormat(
          'File size range',
          'Minimum file size must be less than maximum file size',
        );
      }
    }

    return null;
  }

  /// Apply all filters to recordings list
  List<RecordingEntity> _applyFilters(
      List<RecordingEntity> recordings,
      FilterCriteria criteria,
      ) {
    return recordings.where((recording) {
      // Date range filter
      if (criteria.startDate != null && recording.createdAt.isBefore(criteria.startDate!)) {
        return false;
      }
      if (criteria.endDate != null && recording.createdAt.isAfter(criteria.endDate!)) {
        return false;
      }

      // Duration range filter
      if (criteria.minDuration != null && recording.duration < criteria.minDuration!) {
        return false;
      }
      if (criteria.maxDuration != null && recording.duration > criteria.maxDuration!) {
        return false;
      }

      // File size range filter
      if (criteria.minFileSize != null && recording.fileSize < criteria.minFileSize!) {
        return false;
      }
      if (criteria.maxFileSize != null && recording.fileSize > criteria.maxFileSize!) {
        return false;
      }

      // Format filter
      if (criteria.formats != null &&
          criteria.formats!.isNotEmpty &&
          !criteria.formats!.contains(recording.format)) {
        return false;
      }

      // Has tags filter
      if (criteria.hasTags != null) {
        final hasTags = recording.tags.isNotEmpty;
        if (criteria.hasTags! != hasTags) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Apply sorting to filtered recordings
  List<RecordingEntity> _applySorting(
      List<RecordingEntity> recordings,
      FilterCriteria criteria,
      ) {
    final sortBy = criteria.sortBy ?? FilterSortBy.dateDescending;

    switch (sortBy) {
      case FilterSortBy.nameAscending:
        recordings.sort((a, b) => a.name.compareTo(b.name));
        break;
      case FilterSortBy.nameDescending:
        recordings.sort((a, b) => b.name.compareTo(a.name));
        break;
      case FilterSortBy.dateAscending:
        recordings.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case FilterSortBy.dateDescending:
        recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case FilterSortBy.durationAscending:
        recordings.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case FilterSortBy.durationDescending:
        recordings.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case FilterSortBy.sizeAscending:
        recordings.sort((a, b) => a.fileSize.compareTo(b.fileSize));
        break;
      case FilterSortBy.sizeDescending:
        recordings.sort((a, b) => b.fileSize.compareTo(a.fileSize));
        break;
    }

    return recordings;
  }

  /// Get end date for time period
  DateTime _getEndDateForPeriod(TimePeriod period, DateTime startDate, DateTime now) {
    switch (period) {
      case TimePeriod.today:
        return _getEndOfDay(now);
      case TimePeriod.yesterday:
        return _getEndOfDay(startDate);
      case TimePeriod.thisWeek:
        return _getEndOfWeek(now);
      case TimePeriod.lastWeek:
        return _getEndOfWeek(startDate);
      case TimePeriod.thisMonth:
        return _getEndOfMonth(now);
      case TimePeriod.lastMonth:
        return _getEndOfMonth(startDate);
      case TimePeriod.thisYear:
        return _getEndOfYear(now);
      case TimePeriod.lastYear:
        return DateTime(startDate.year, 12, 31, 23, 59, 59, 999);
    }
  }

  // Helper methods for date calculations
  DateTime _getStartOfDay(DateTime date) => DateTime(date.year, date.month, date.day);
  DateTime _getEndOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  DateTime _getStartOfWeek(DateTime date) {
    final difference = date.weekday - 1;
    return _getStartOfDay(date.subtract(Duration(days: difference)));
  }

  DateTime _getEndOfWeek(DateTime date) {
    final difference = 7 - date.weekday;
    return _getEndOfDay(date.add(Duration(days: difference)));
  }

  DateTime _getStartOfMonth(DateTime date) => DateTime(date.year, date.month, 1);
  DateTime _getEndOfMonth(DateTime date) => DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);

  DateTime _getStartOfYear(DateTime date) => DateTime(date.year, 1, 1);
  DateTime _getEndOfYear(DateTime date) => DateTime(date.year, 12, 31, 23, 59, 59, 999);

  /// Get recording age category for grouping
  String _getRecordingAgeCategory(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return 'This Week';
    } else if (difference.inDays < 30) {
      return 'This Month';
    } else if (difference.inDays < 365) {
      return 'Earlier This Year';
    } else {
      return 'Older';
    }
  }

  /// Get duration category name
  String _getDurationCategoryName(Duration duration) {
    if (duration.inSeconds < 30) {
      return 'Quick Notes';
    } else if (duration.inMinutes < 5) {
      return 'Short Recordings';
    } else if (duration.inMinutes < 30) {
      return 'Medium Recordings';
    } else if (duration.inHours < 2) {
      return 'Long Recordings';
    } else {
      return 'Extended Recordings';
    }
  }
}