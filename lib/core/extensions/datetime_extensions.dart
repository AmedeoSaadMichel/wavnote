// File: core/extensions/datetime_extensions.dart
import '../utils/date_formatter.dart';

/// DateTime extension methods for enhanced functionality
///
/// Provides utility methods for date/time manipulation, formatting,
/// and comparison commonly used throughout the voice memo app.
extension DateTimeExtensions on DateTime {

  // ==== FORMATTING ====

  /// Format as user-friendly string
  String get userFriendlyFormat => DateFormatter.getSmartDateDescription(this);

  /// Format as short date (MM/dd/yyyy)
  String get shortDateFormat => DateFormatter.formatShortDate(this);

  /// Format as full date (January 1, 2025)
  String get fullDateFormat => DateFormatter.formatFullDate(this);

  /// Format as time only (3:45 PM)
  String get timeOnlyFormat => DateFormatter.formatTime(this);

  /// Format as date and time (Jan 1, 2025 at 3:45 PM)
  String get dateTimeFormat => DateFormatter.formatDateTime(this);

  /// Format as ISO string (for database storage)
  String get isoFormat => toIso8601String();

  /// Format as file-safe timestamp (20250101_154530)
  String get fileSafeTimestamp {
    return '${year.toString().padLeft(4, '0')}'
        '${month.toString().padLeft(2, '0')}'
        '${day.toString().padLeft(2, '0')}_'
        '${hour.toString().padLeft(2, '0')}'
        '${minute.toString().padLeft(2, '0')}'
        '${second.toString().padLeft(2, '0')}';
  }

  /// Format as recording timestamp for UI
  String get recordingTimestamp {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisDate = DateTime(year, month, day);

    if (thisDate == today) {
      return 'Today at ${timeOnlyFormat}';
    } else if (thisDate == yesterday) {
      return 'Yesterday at ${timeOnlyFormat}';
    } else if (year == now.year) {
      final monthName = DateFormatter.getShortMonthName(month);
      return '$monthName $day at ${timeOnlyFormat}';
    } else {
      return dateTimeFormat;
    }
  }

  // ==== RELATIVE TIME ====

  /// Get time ago string (e.g., "5 minutes ago")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else if (difference.inDays > 0) {
      return difference.inDays == 1 ? '1 day ago' : '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return difference.inHours == 1 ? '1 hour ago' : '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return difference.inMinutes == 1 ? '1 minute ago' : '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  /// Get time until string (e.g., "in 5 minutes")
  String get timeUntil {
    final now = DateTime.now();
    final difference = this.difference(now);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? 'in 1 year' : 'in $years years';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? 'in 1 month' : 'in $months months';
    } else if (difference.inDays > 0) {
      return difference.inDays == 1 ? 'in 1 day' : 'in ${difference.inDays} days';
    } else if (difference.inHours > 0) {
      return difference.inHours == 1 ? 'in 1 hour' : 'in ${difference.inHours} hours';
    } else if (difference.inMinutes > 0) {
      return difference.inMinutes == 1 ? 'in 1 minute' : 'in ${difference.inMinutes} minutes';
    } else {
      return 'Now';
    }
  }

  // ==== COMPARISONS ====

  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  /// Check if date is tomorrow
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year && month == tomorrow.month && day == tomorrow.day;
  }

  /// Check if date is this week
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// Check if date is this month
  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// Check if date is this year
  bool get isThisYear {
    final now = DateTime.now();
    return year == now.year;
  }

  /// Check if date is in the past
  bool get isPast => isBefore(DateTime.now());

  /// Check if date is in the future
  bool get isFuture => isAfter(DateTime.now());

  /// Check if date is within the last N days
  bool isWithinLastDays(int days) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    return isAfter(cutoff);
  }

  /// Check if date is within the next N days
  bool isWithinNextDays(int days) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    return isBefore(cutoff);
  }

  // ==== MANIPULATION ====

  /// Start of day (00:00:00)
  DateTime get startOfDay => DateTime(year, month, day);

  /// End of day (23:59:59.999)
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// Start of week (Monday 00:00:00)
  DateTime get startOfWeek {
    final daysFromMonday = weekday - 1;
    return startOfDay.subtract(Duration(days: daysFromMonday));
  }

  /// End of week (Sunday 23:59:59.999)
  DateTime get endOfWeek {
    final daysUntilSunday = 7 - weekday;
    return endOfDay.add(Duration(days: daysUntilSunday));
  }

  /// Start of month (1st day 00:00:00)
  DateTime get startOfMonth => DateTime(year, month, 1);

  /// End of month (last day 23:59:59.999)
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59, 999);

  /// Start of year (Jan 1st 00:00:00)
  DateTime get startOfYear => DateTime(year, 1, 1);

  /// End of year (Dec 31st 23:59:59.999)
  DateTime get endOfYear => DateTime(year, 12, 31, 23, 59, 59, 999);

  /// Add business days (skip weekends)
  DateTime addBusinessDays(int days) {
    DateTime result = this;
    int remainingDays = days.abs();
    final increment = days.isNegative ? -1 : 1;

    while (remainingDays > 0) {
      result = result.add(Duration(days: increment));
      if (result.weekday <= 5) { // Monday = 1, Friday = 5
        remainingDays--;
      }
    }

    return result;
  }

  // ==== RECORDING-SPECIFIC ====

  /// Get age in days for recording sorting
  int get ageInDays => DateTime.now().difference(this).inDays;

  /// Get age in hours for recent recordings
  int get ageInHours => DateTime.now().difference(this).inHours;

  /// Get age in minutes for very recent recordings
  int get ageInMinutes => DateTime.now().difference(this).inMinutes;

  /// Check if recording is recent (less than 1 hour old)
  bool get isRecentRecording => ageInHours < 1;

  /// Check if recording is old (more than 30 days old)
  bool get isOldRecording => ageInDays > 30;

  /// Get recording age category for UI grouping
  String get recordingAgeCategory {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    if (isThisWeek) return 'This Week';
    if (isThisMonth) return 'This Month';
    if (isThisYear) return 'This Year';
    return 'Older';
  }

  // ==== TIMEZONE ====

  /// Convert to local timezone
  DateTime get toLocalTime => toLocal();

  /// Convert to UTC
  DateTime get toUtcTime => toUtc();

  /// Get timezone offset string (+05:30)
  String get timezoneOffset {
    final offset = timeZoneOffset;
    final hours = offset.inHours.abs();
    final minutes = (offset.inMinutes.abs() % 60);
    final sign = offset.isNegative ? '-' : '+';

    return '$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  // ==== VALIDATION ====

  /// Check if date is valid for recording (not in future)
  bool get isValidRecordingDate => !isFuture;

  /// Check if date is reasonable for app (not too old)
  bool get isReasonableDate {
    final appEpoch = DateTime(2020, 1, 1); // App didn't exist before 2020
    final futureLimit = DateTime.now().add(const Duration(days: 365));

    return isAfter(appEpoch) && isBefore(futureLimit);
  }

  // ==== COSMIC THEME HELPERS ====

  /// Get mystical time description for cosmic UI
  String get mysticalTimeDescription {
    final hour = this.hour;

    if (hour >= 0 && hour < 6) {
      return 'Deep Night Transmission';
    } else if (hour >= 6 && hour < 12) {
      return 'Dawn Essence';
    } else if (hour >= 12 && hour < 18) {
      return 'Solar Resonance';
    } else {
      return 'Twilight Echo';
    }
  }

  /// Get cosmic phase based on date
  String get cosmicPhase {
    final dayOfYear = difference(DateTime(year, 1, 1)).inDays;
    final phases = [
      'Nebula Genesis',
      'Stellar Formation',
      'Cosmic Expansion',
      'Galactic Harmony',
    ];

    return phases[dayOfYear % phases.length];
  }
}

/// Extension for nullable DateTime
extension NullableDateTimeExtensions on DateTime? {

  /// Safe format with fallback
  String formatSafely({String fallback = 'Unknown'}) {
    return this?.userFriendlyFormat ?? fallback;
  }

  /// Check if null or in past
  bool get isNullOrPast {
    return this == null || this!.isPast;
  }

  /// Check if null or in future
  bool get isNullOrFuture {
    return this == null || this!.isFuture;
  }

  /// Get safe time ago with fallback
  String timeAgoSafely({String fallback = 'Unknown time'}) {
    return this?.timeAgo ?? fallback;
  }
}