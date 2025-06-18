// File: core/extensions/duration_extensions.dart

/// Duration extension methods for enhanced functionality
///
/// Provides utility methods for duration manipulation, formatting,
/// and comparison commonly used throughout the voice memo app.
extension DurationExtensions on Duration {

  // ==== FORMATTING ====

  /// Format as HH:MM:SS
  String get formatted {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Format as compact duration (1h 23m 45s)
  String get compactFormat {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    final parts = <String>[];

    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (seconds > 0 || parts.isEmpty) parts.add('${seconds}s');

    return parts.join(' ');
  }

  /// Format as human readable (1 hour, 23 minutes, 45 seconds)
  String get humanReadable {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    final parts = <String>[];

    if (hours > 0) {
      parts.add(hours == 1 ? '1 hour' : '$hours hours');
    }
    if (minutes > 0) {
      parts.add(minutes == 1 ? '1 minute' : '$minutes minutes');
    }
    if (seconds > 0 || parts.isEmpty) {
      parts.add(seconds == 1 ? '1 second' : '$seconds seconds');
    }

    if (parts.length == 1) {
      return parts.first;
    } else if (parts.length == 2) {
      return '${parts[0]} and ${parts[1]}';
    } else {
      return '${parts.sublist(0, parts.length - 1).join(', ')}, and ${parts.last}';
    }
  }

  /// Format for recording display (shorter format)
  String get recordingFormat {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '0:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Format for minimal display (removes leading zeros)
  String get minimalFormat {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Format as digital clock display
  String get digitalClockFormat {
    final totalSeconds = inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  // ==== COMPARISONS ====

  /// Check if duration is very short (less than 1 second)
  bool get isVeryShort => inMilliseconds < 1000;

  /// Check if duration is short (less than 10 seconds)
  bool get isShort => inSeconds < 10;

  /// Check if duration is medium (10 seconds to 5 minutes)
  bool get isMedium => inSeconds >= 10 && inSeconds < 300;

  /// Check if duration is long (5 minutes to 1 hour)
  bool get isLong => inSeconds >= 300 && inSeconds < 3600;

  /// Check if duration is very long (more than 1 hour)
  bool get isVeryLong => inSeconds >= 3600;

  /// Check if duration is zero
  bool get isZero => inMilliseconds == 0;

  /// Check if duration is positive
  bool get isPositive => inMilliseconds > 0;

  /// Check if duration is negative
  bool get isNegative => inMilliseconds < 0;

  // ==== AUDIO-SPECIFIC ====

  /// Get duration category for UI grouping
  String get categoryName {
    if (isVeryShort) return 'Very Short';
    if (isShort) return 'Short';
    if (isMedium) return 'Medium';
    if (isLong) return 'Long';
    return 'Very Long';
  }

  /// Get estimated file size category (rough estimate)
  String get estimatedSizeCategory {
    final minutes = inMinutes;
    if (minutes < 1) return 'Tiny';
    if (minutes < 5) return 'Small';
    if (minutes < 15) return 'Medium';
    if (minutes < 60) return 'Large';
    return 'Very Large';
  }

  /// Check if suitable for voice memo (not too long)
  bool get isSuitableForVoiceMemo => inSeconds <= 3600; // Max 1 hour

  /// Check if duration warrants a warning (very long)
  bool get warrantsLengthWarning => inSeconds > 1800; // More than 30 minutes

  // ==== MANIPULATION ====

  /// Get duration as percentage of another duration
  double percentageOf(Duration total) {
    if (total.inMilliseconds == 0) return 0.0;
    return (inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Get remaining duration from total
  Duration remainingFrom(Duration total) {
    final remaining = total - this;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Scale duration by factor
  Duration scale(double factor) {
    return Duration(milliseconds: (inMilliseconds * factor).round());
  }

  /// Get absolute duration (remove negative sign)
  Duration get abs => Duration(milliseconds: inMilliseconds.abs());

  /// Clamp duration between min and max
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }

  // ==== PROGRESS TRACKING ====

  /// Convert to progress value (0.0 to 1.0)
  double toProgress(Duration total) {
    return percentageOf(total);
  }

  /// Get progress description
  String progressDescription(Duration total) {
    final progress = toProgress(total);
    final percentage = (progress * 100).round();
    return '$percentage% complete';
  }

  // ==== VALIDATION ====

  /// Check if duration is valid for recording
  bool get isValidRecordingDuration {
    return isPositive && inSeconds <= 3600; // Max 1 hour
  }

  /// Check if duration is reasonable for playback seeking
  bool get isValidSeekPosition {
    return !isNegative && inSeconds <= 86400; // Max 24 hours
  }

  /// Check if duration is suitable for amplitude sampling
  bool get isValidForAmplitudeSampling {
    return isPositive && inMilliseconds >= 10; // At least 10ms
  }

  // ==== PLAYBACK-SPECIFIC ====

  /// Get seek increment for different duration lengths
  Duration get recommendedSeekIncrement {
    if (inSeconds < 30) return const Duration(seconds: 1);
    if (inSeconds < 300) return const Duration(seconds: 5);
    if (inSeconds < 1800) return const Duration(seconds: 15);
    return const Duration(seconds: 30);
  }

  /// Get chapters for long recordings
  List<Duration> get chapterMarkers {
    if (inSeconds < 300) return []; // No chapters for short recordings

    final chapterLength = inSeconds < 1800
        ? const Duration(minutes: 1)
        : const Duration(minutes: 5);

    final chapters = <Duration>[];
    Duration current = Duration.zero;

    while (current < this) {
      chapters.add(current);
      current += chapterLength;
    }

    return chapters;
  }

  /// Get timestamp markers for waveform display
  List<Duration> get timestampMarkers {
    if (inSeconds < 10) return [];

    final interval = inSeconds < 60
        ? const Duration(seconds: 5)
        : inSeconds < 300
        ? const Duration(seconds: 15)
        : const Duration(minutes: 1);

    final markers = <Duration>[];
    Duration current = Duration.zero;

    while (current <= this) {
      markers.add(current);
      current += interval;
    }

    return markers;
  }

  // ==== FILE SIZE ESTIMATION ====

  /// Estimate file size in bytes for different audio formats
  int estimateFileSizeBytes({
    required String format,
    int sampleRate = 44100,
    int bitRate = 128000,
  }) {
    switch (format.toLowerCase()) {
      case 'wav':
      // Uncompressed: sample rate * bits per sample * channels * duration
        return (sampleRate * 16 * 1 * inSeconds / 8).round();

      case 'm4a':
      case 'aac':
      // Compressed: bit rate * duration / 8
        return (bitRate * inSeconds / 8).round();

      case 'mp3':
      // Compressed: bit rate * duration / 8
        return (bitRate * inSeconds / 8).round();

      case 'flac':
      // Lossless compressed: roughly 60% of WAV
        return (estimateFileSizeBytes(format: 'wav', sampleRate: sampleRate) * 0.6).round();

      default:
        return (bitRate * inSeconds / 8).round();
    }
  }

  /// Get file size description
  String getFileSizeDescription({
    required String format,
    int sampleRate = 44100,
    int bitRate = 128000,
  }) {
    final bytes = estimateFileSizeBytes(
      format: format,
      sampleRate: sampleRate,
      bitRate: bitRate,
    );

    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  // ==== COSMIC THEME HELPERS ====

  /// Get mystical duration description for cosmic UI
  String get mysticalDescription {
    if (inSeconds < 10) return 'Brief Transmission';
    if (inSeconds < 60) return 'Momentary Echo';
    if (inSeconds < 300) return 'Temporal Fragment';
    if (inSeconds < 1800) return 'Extended Resonance';
    return 'Epic Cosmic Journey';
  }

  /// Get cosmic intensity based on duration
  String get cosmicIntensity {
    if (inSeconds < 30) return 'Whisper';
    if (inSeconds < 120) return 'Pulse';
    if (inSeconds < 600) return 'Wave';
    if (inSeconds < 1800) return 'Storm';
    return 'Galaxy';
  }

  /// Get ethereal quality description
  String get etherealQuality {
    final minutes = inMinutes;
    if (minutes < 1) return 'Spark of Consciousness';
    if (minutes < 5) return 'Stream of Thought';
    if (minutes < 15) return 'River of Ideas';
    if (minutes < 60) return 'Ocean of Wisdom';
    return 'Infinite Cosmos';
  }

  // ==== MATHEMATICAL OPERATIONS ====

  /// Get average of multiple durations
  static Duration average(List<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;

    final totalMs = durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ durations.length);
  }

  /// Get median of multiple durations
  static Duration median(List<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;

    final sorted = List<Duration>.from(durations)..sort((a, b) => a.inMilliseconds.compareTo(b.inMilliseconds));
    final middle = sorted.length ~/ 2;

    if (sorted.length.isOdd) {
      return sorted[middle];
    } else {
      final ms1 = sorted[middle - 1].inMilliseconds;
      final ms2 = sorted[middle].inMilliseconds;
      return Duration(milliseconds: (ms1 + ms2) ~/ 2);
    }
  }

  /// Get sum of multiple durations
  static Duration sum(List<Duration> durations) {
    return durations.fold(Duration.zero, (sum, d) => sum + d);
  }

  /// Get maximum of multiple durations
  static Duration max(List<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;
    return durations.reduce((a, b) => a > b ? a : b);
  }

  /// Get minimum of multiple durations
  static Duration min(List<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;
    return durations.reduce((a, b) => a < b ? a : b);
  }
}

/// Extension for nullable Duration
extension NullableDurationExtensions on Duration? {

  /// Safe format with fallback
  String formatSafely({String fallback = '--:--'}) {
    return this?.formatted ?? fallback;
  }

  /// Safe recording format with fallback
  String recordingFormatSafely({String fallback = '0:00'}) {
    return this?.recordingFormat ?? fallback;
  }

  /// Check if null or zero
  bool get isNullOrZero {
    return this == null || this!.isZero;
  }

  /// Check if null or positive
  bool get isNullOrPositive {
    return this == null || this!.isPositive;
  }

  /// Get safe duration with fallback
  Duration orDefault([Duration defaultValue = Duration.zero]) {
    return this ?? defaultValue;
  }

  /// Safe percentage calculation
  double percentageOfSafely(Duration? total) {
    if (this == null || total == null || total.inMilliseconds == 0) {
      return 0.0;
    }
    return this!.percentageOf(total);
  }
}