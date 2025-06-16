// File: core/utils/date_formatter.dart

/// Utility class for formatting dates and times throughout the app
///
/// Provides consistent date/time formatting for the voice memo app
/// with human-readable relative time descriptions.
/// Note: This implementation uses basic DateTime methods to avoid external dependencies.
class DateFormatter {

  // ==== DATE FORMAT PATTERNS ====
  // Using basic DateTime formatting without external dependencies

  // ==== PRIMARY FORMATTING METHODS ====

  /// Format date as "Wednesday, March 15, 2024"
  static String formatFullDate(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];

    return '$weekday, $month ${date.day}, ${date.year}';
  }

  /// Format date as "Mar 15, 2024"
  static String formatShortDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final month = months[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  /// Format time as "2:30 PM"
  static String formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    return '$displayHour:${minute.toString().padLeft(2, '0')} $ampm';
  }

  /// Format date and time as "Mar 15, 2024 2:30 PM"
  static String formatDateTime(DateTime date) {
    return '${formatShortDate(date)} ${formatTime(date)}';
  }

  /// Format for file names as "2024-03-15_14-30-45"
  static String formatForFileName(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}_${date.hour.toString().padLeft(2, '0')}-${date.minute.toString().padLeft(2, '0')}-${date.second.toString().padLeft(2, '0')}';
  }

  /// Format for exports as "2024-03-15_14-30"
  static String formatForExport(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}_${date.hour.toString().padLeft(2, '0')}-${date.minute.toString().padLeft(2, '0')}';
  }

  // ==== RELATIVE TIME FORMATTING ====

  /// Get relative time description (e.g., "2 hours ago", "Just now")
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.isNegative) {
      return 'In the future'; // Handle edge case
    }

    // Just now (less than 1 minute)
    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    // Minutes ago (1-59 minutes)
    if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '${minutes} minute${minutes == 1 ? '' : 's'} ago';
    }

    // Hours ago (1-23 hours)
    if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '${hours} hour${hours == 1 ? '' : 's'} ago';
    }

    // Days ago (1-6 days)
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '${days} day${days == 1 ? '' : 's'} ago';
    }

    // Weeks ago (1-3 weeks)
    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks} week${weeks == 1 ? '' : 's'} ago';
    }

    // Months ago (1-11 months)
    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months} month${months == 1 ? '' : 's'} ago';
    }

    // Years ago (1+ years)
    final years = (difference.inDays / 365).floor();
    return '${years} year${years == 1 ? '' : 's'} ago';
  }

  /// Get smart date description based on context
  static String getSmartDateDescription(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) {
      // Today - show time only
      return 'Today ${formatTime(date)}';
    } else if (difference == 1) {
      // Yesterday - show time
      return 'Yesterday ${formatTime(date)}';
    } else if (difference < 7) {
      // This week - show day name and time
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final weekday = weekdays[date.weekday - 1];
      return '$weekday ${formatTime(date)}';
    } else if (difference < 365) {
      // This year - show month, day and time
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[date.month - 1];
      return '$month ${date.day} ${formatTime(date)}';
    } else {
      // Previous years - show full date
      return formatShortDate(date);
    }
  }

  /// Get recording age description for UI
  static String getRecordingAge(DateTime createdDate) {
    final difference = DateTime.now().difference(createdDate);

    if (difference.inMinutes < 1) {
      return 'Just recorded';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return 'Recorded ${minutes}m ago';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return 'Recorded ${hours}h ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return 'Recorded ${days}d ago';
    } else {
      return 'Recorded ${formatShortDate(createdDate)}';
    }
  }

  // ==== DURATION FORMATTING ====

  /// Format duration as "02:30" or "1:02:30"
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Format duration with centiseconds as "02:30.50"
  static String formatDurationWithCentiseconds(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final centiseconds = (duration.inMilliseconds.remainder(1000) / 10).floor();

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}';
  }

  /// Format duration in human readable form ("2 hours 30 minutes")
  static String formatDurationHuman(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final parts = <String>[];

    if (days > 0) {
      parts.add('${days} day${days == 1 ? '' : 's'}');
    }
    if (hours > 0) {
      parts.add('${hours} hour${hours == 1 ? '' : 's'}');
    }
    if (minutes > 0) {
      parts.add('${minutes} minute${minutes == 1 ? '' : 's'}');
    }
    if (seconds > 0 && parts.isEmpty) {
      parts.add('${seconds} second${seconds == 1 ? '' : 's'}');
    }

    if (parts.isEmpty) {
      return '0 seconds';
    } else if (parts.length == 1) {
      return parts[0];
    } else if (parts.length == 2) {
      return '${parts[0]} and ${parts[1]}';
    } else {
      return '${parts.take(parts.length - 1).join(', ')}, and ${parts.last}';
    }
  }

  // ==== DATE RANGE FORMATTING ====

  /// Format date range as "Mar 1 - Mar 15, 2024"
  static String formatDateRange(DateTime startDate, DateTime endDate) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    if (startDate.year == endDate.year && startDate.month == endDate.month) {
      // Same month
      final month = months[startDate.month - 1];
      return '$month ${startDate.day} - ${endDate.day}, ${endDate.year}';
    } else if (startDate.year == endDate.year) {
      // Same year, different months
      final startMonth = months[startDate.month - 1];
      final endMonth = months[endDate.month - 1];
      return '$startMonth ${startDate.day} - $endMonth ${endDate.day}, ${endDate.year}';
    } else {
      // Different years
      return '${formatShortDate(startDate)} - ${formatShortDate(endDate)}';
    }
  }

  // ==== VALIDATION & PARSING ====

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  /// Check if date is within this week
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
        date.isBefore(endOfWeek.add(const Duration(seconds: 1)));
  }

  /// Parse duration from string "mm:ss" or "hh:mm:ss"
  static Duration? parseDuration(String durationString) {
    try {
      final parts = durationString.split(':');

      if (parts.length == 2) {
        // mm:ss format
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return Duration(minutes: minutes, seconds: seconds);
      } else if (parts.length == 3) {
        // hh:mm:ss format
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ==== SPECIALIZED FORMATTERS ====

  /// Format for recording list display
  static String formatForRecordingList(DateTime date) {
    return getSmartDateDescription(date);
  }

  /// Format for folder display
  static String formatForFolderDisplay(DateTime date) {
    final difference = DateTime.now().difference(date).inDays;

    if (difference < 7) {
      return getRelativeTime(date);
    } else {
      return formatShortDate(date);
    }
  }

  /// Format for export file naming
  static String formatForExportFileName(DateTime date, String prefix) {
    return '${prefix}_${formatForExport(date)}';
  }

  /// Get month name
  static String getMonthName(int month) {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    if (month >= 1 && month <= 12) {
      return monthNames[month - 1];
    }
    return 'Unknown';
  }

  /// Get day of week name
  static String getDayOfWeekName(int weekday) {
    final dayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];

    if (weekday >= 1 && weekday <= 7) {
      return dayNames[weekday - 1];
    }
    return 'Unknown';
  }

  /// Get short month name
  static String getShortMonthName(int month) {
    final shortMonthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    if (month >= 1 && month <= 12) {
      return shortMonthNames[month - 1];
    }
    return 'Unk';
  }

  /// Get short day of week name
  static String getShortDayOfWeekName(int weekday) {
    final shortDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (weekday >= 1 && weekday <= 7) {
      return shortDayNames[weekday - 1];
    }
    return 'Unk';
  }

  /// Format time in 24-hour format as "14:30"
  static String formatTime24Hour(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Format date in ISO format as "2024-03-15"
  static String formatISODate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format timestamp for logs as "2024-03-15 14:30:45"
  static String formatTimestamp(DateTime date) {
    return '${formatISODate(date)} ${formatTime24Hour(date)}:${date.second.toString().padLeft(2, '0')}';
  }
}