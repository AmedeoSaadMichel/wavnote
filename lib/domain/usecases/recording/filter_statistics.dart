// File: domain/usecases/recording/filter_statistics.dart
import '../../entities/recording_entity.dart';
import '../../../core/enums/audio_format.dart';

// ==== FILTER STATISTICS ====

/// Statistics about recordings for filter UI
class FilterStatistics {
  final int totalRecordings;
  final Map<AudioFormat, int> formatCounts;
  final Map<String, int> durationCategories;
  final Map<String, int> dateCategories;
  final Map<String, int> sizeCategories;
  final DateTime? earliestDate;
  final DateTime? latestDate;
  final Duration? shortestDuration;
  final Duration? longestDuration;
  final int? smallestFileSize;
  final int? largestFileSize;

  const FilterStatistics({
    required this.totalRecordings,
    required this.formatCounts,
    required this.durationCategories,
    required this.dateCategories,
    required this.sizeCategories,
    this.earliestDate,
    this.latestDate,
    this.shortestDuration,
    this.longestDuration,
    this.smallestFileSize,
    this.largestFileSize,
  });

  /// Create statistics from recordings list
  factory FilterStatistics.fromRecordings(List<RecordingEntity> recordings) {
    if (recordings.isEmpty) {
      return const FilterStatistics(
        totalRecordings: 0,
        formatCounts: {},
        durationCategories: {},
        dateCategories: {},
        sizeCategories: {},
      );
    }

    final formatCounts = <AudioFormat, int>{};
    final durationCategories = <String, int>{};
    final dateCategories = <String, int>{};
    final sizeCategories = <String, int>{};

    DateTime? earliestDate;
    DateTime? latestDate;
    Duration? shortestDuration;
    Duration? longestDuration;
    int? smallestFileSize;
    int? largestFileSize;

    for (final recording in recordings) {
      // Format counts
      formatCounts[recording.format] = (formatCounts[recording.format] ?? 0) + 1;

      // Duration categories
      final durationCategory = _getDurationCategoryName(recording.duration);
      durationCategories[durationCategory] = (durationCategories[durationCategory] ?? 0) + 1;

      // Date categories
      final dateCategory = _getRecordingAgeCategory(recording.createdAt);
      dateCategories[dateCategory] = (dateCategories[dateCategory] ?? 0) + 1;

      // Size categories
      final sizeCategory = _getEstimatedSizeCategory(recording.duration);
      sizeCategories[sizeCategory] = (sizeCategories[sizeCategory] ?? 0) + 1;

      // Min/max values
      if (earliestDate == null || recording.createdAt.isBefore(earliestDate)) {
        earliestDate = recording.createdAt;
      }
      if (latestDate == null || recording.createdAt.isAfter(latestDate)) {
        latestDate = recording.createdAt;
      }
      if (shortestDuration == null || recording.duration < shortestDuration) {
        shortestDuration = recording.duration;
      }
      if (longestDuration == null || recording.duration > longestDuration) {
        longestDuration = recording.duration;
      }
      if (smallestFileSize == null || recording.fileSize < smallestFileSize) {
        smallestFileSize = recording.fileSize;
      }
      if (largestFileSize == null || recording.fileSize > largestFileSize) {
        largestFileSize = recording.fileSize;
      }
    }

    return FilterStatistics(
      totalRecordings: recordings.length,
      formatCounts: formatCounts,
      durationCategories: durationCategories,
      dateCategories: dateCategories,
      sizeCategories: sizeCategories,
      earliestDate: earliestDate,
      latestDate: latestDate,
      shortestDuration: shortestDuration,
      longestDuration: longestDuration,
      smallestFileSize: smallestFileSize,
      largestFileSize: largestFileSize,
    );
  }

  /// Get format distribution as percentages
  Map<AudioFormat, double> get formatPercentages {
    if (totalRecordings == 0) return {};

    return formatCounts.map((format, count) =>
        MapEntry(format, (count / totalRecordings) * 100));
  }

  /// Get most common format
  AudioFormat? get mostCommonFormat {
    if (formatCounts.isEmpty) return null;

    return formatCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get date range description
  String get dateRangeDescription {
    if (earliestDate == null || latestDate == null) {
      return 'No recordings';
    }

    final earliest = earliestDate!;
    final latest = latestDate!;

    if (_isSameDay(earliest, latest)) {
      return 'Today only';
    }

    return '${_formatDate(earliest)} - ${_formatDate(latest)}';
  }

  /// Get duration range description
  String get durationRangeDescription {
    if (shortestDuration == null || longestDuration == null) {
      return 'No recordings';
    }

    return '${_formatDuration(shortestDuration!)} - ${_formatDuration(longestDuration!)}';
  }

  // Helper methods
  static String _getDurationCategoryName(Duration duration) {
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

  static String _getRecordingAgeCategory(DateTime createdAt) {
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

  static String _getEstimatedSizeCategory(Duration duration) {
    // Estimate based on typical audio compression (assume ~64kbps average)
    final estimatedBytes = (duration.inSeconds * 64 * 1024) ~/ 8;

    if (estimatedBytes < 1024 * 1024) {
      return 'Small';
    } else if (estimatedBytes < 10 * 1024 * 1024) {
      return 'Medium';
    } else {
      return 'Large';
    }
  }

  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}