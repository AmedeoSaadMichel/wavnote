// File: core/extensions/string_extensions.dart
import 'dart:convert';
import '../constants/app_constants.dart';

/// String extension methods for enhanced functionality
///
/// Provides utility methods for string manipulation, validation,
/// and formatting commonly used throughout the voice memo app.
extension StringExtensions on String {

  // ==== VALIDATION ====

  /// Check if string is null or empty
  bool get isNullOrEmpty => isEmpty;

  /// Check if string is not null and not empty
  bool get isNotNullOrEmpty => isNotEmpty;

  /// Check if string contains only whitespace
  bool get isBlank => trim().isEmpty;

  /// Check if string is not blank
  bool get isNotBlank => trim().isNotEmpty;

  /// Check if string is a valid file name
  bool get isValidFileName {
    if (isBlank || length > AppConstants.maxFileNameLength) {
      return false;
    }

    for (final char in AppConstants.invalidFileNameChars) {
      if (contains(char)) {
        return false;
      }
    }

    return true;
  }

  /// Check if string is a valid recording name
  bool get isValidRecordingName {
    return isNotBlank &&
        length >= 1 &&
        length <= 100 &&
        isValidFileName;
  }

  /// Check if string is a valid folder name
  bool get isValidFolderName {
    return isNotBlank &&
        length >= 1 &&
        length <= 50 &&
        isValidFileName;
  }

  // ==== FORMATTING ====

  /// Capitalize first letter
  String get capitalize {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }

  /// Capitalize each word
  String get capitalizeWords {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.capitalize)
        .join(' ');
  }

  /// Convert to title case
  String get toTitleCase => capitalizeWords;

  /// Remove extra whitespace
  String get trimmed => trim();

  /// Remove all whitespace
  String get removeWhitespace => replaceAll(RegExp(r'\s+'), '');

  /// Replace multiple spaces with single space
  String get normalizeSpaces => replaceAll(RegExp(r'\s+'), ' ').trim();

  // ==== FILE OPERATIONS ====

  /// Get file extension from path
  String get fileExtension {
    final lastDot = lastIndexOf('.');
    if (lastDot == -1 || lastDot == length - 1) {
      return '';
    }
    return substring(lastDot + 1).toLowerCase();
  }

  /// Get file name without extension
  String get fileNameWithoutExtension {
    final lastSlash = lastIndexOf('/');
    final lastDot = lastIndexOf('.');

    final start = lastSlash == -1 ? 0 : lastSlash + 1;
    final end = lastDot == -1 ? length : lastDot;

    return substring(start, end);
  }

  /// Get directory path from file path
  String get directoryPath {
    final lastSlash = lastIndexOf('/');
    if (lastSlash == -1) return '';
    return substring(0, lastSlash);
  }

  /// Get safe file name for storage
  String get safeFileName {
    String safe = this;

    // Replace invalid characters with underscores
    for (final char in AppConstants.invalidFileNameChars) {
      safe = safe.replaceAll(char, '_');
    }

    // Normalize spaces and trim
    safe = safe.normalizeSpaces.replaceAll(' ', '_');

    // Ensure length limit
    if (safe.length > AppConstants.maxFileNameLength) {
      safe = safe.substring(0, AppConstants.maxFileNameLength);
    }

    return safe;
  }

  // ==== AUDIO-SPECIFIC ====

  /// Check if string represents an audio file
  bool get isAudioFile {
    final ext = fileExtension;
    return ['wav', 'm4a', 'mp3', 'aac', 'flac', 'ogg'].contains(ext);
  }

  /// Get audio format display name
  String get audioFormatDisplayName {
    switch (fileExtension) {
      case 'wav':
        return 'WAV Audio';
      case 'm4a':
        return 'M4A Audio';
      case 'mp3':
        return 'MP3 Audio';
      case 'aac':
        return 'AAC Audio';
      case 'flac':
        return 'FLAC Audio';
      case 'ogg':
        return 'OGG Audio';
      default:
        return 'Audio File';
    }
  }

  // ==== SEARCH & FILTERING ====

  /// Check if string contains another string (case insensitive)
  bool containsIgnoreCase(String other) {
    return toLowerCase().contains(other.toLowerCase());
  }

  /// Check if string starts with another string (case insensitive)
  bool startsWithIgnoreCase(String other) {
    return toLowerCase().startsWith(other.toLowerCase());
  }

  /// Check if string ends with another string (case insensitive)
  bool endsWithIgnoreCase(String other) {
    return toLowerCase().endsWith(other.toLowerCase());
  }

  /// Get search relevance score (0.0 to 1.0)
  double searchRelevanceScore(String query) {
    if (query.isEmpty) return 0.0;

    final lowerThis = toLowerCase();
    final lowerQuery = query.toLowerCase();

    // Exact match
    if (lowerThis == lowerQuery) return 1.0;

    // Starts with query
    if (lowerThis.startsWith(lowerQuery)) return 0.9;

    // Contains query at word boundary
    if (lowerThis.contains(' $lowerQuery')) return 0.8;

    // Contains query
    if (lowerThis.contains(lowerQuery)) return 0.7;

    // Contains all characters of query in order
    int queryIndex = 0;
    for (int i = 0; i < lowerThis.length && queryIndex < lowerQuery.length; i++) {
      if (lowerThis[i] == lowerQuery[queryIndex]) {
        queryIndex++;
      }
    }

    if (queryIndex == lowerQuery.length) {
      return 0.5 * (queryIndex / lowerThis.length);
    }

    return 0.0;
  }

  // ==== TRUNCATION ====

  /// Truncate string to specified length with ellipsis
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;

    final truncateLength = maxLength - ellipsis.length;
    if (truncateLength <= 0) return ellipsis;

    return substring(0, truncateLength) + ellipsis;
  }

  /// Truncate to fit in one line (UI helper)
  String get truncateForDisplay => truncate(30);

  /// Truncate for file name display
  String get truncateForFileName => truncate(25);

  // ==== COSMIC THEME HELPERS ====

  /// Get mystical variant of string (for UI theming)
  String get mysticalVariant {
    const mysticalWords = {
      'recording': 'transmission',
      'folder': 'realm',
      'audio': 'essence',
      'file': 'fragment',
      'play': 'channel',
      'stop': 'silence',
      'record': 'capture',
      'pause': 'suspend',
      'delete': 'dissolve',
      'save': 'preserve',
      'settings': 'configuration',
      'volume': 'resonance',
      'duration': 'temporal span',
    };

    String result = toLowerCase();
    for (final entry in mysticalWords.entries) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }

    return result.capitalizeWords;
  }

  // ==== PARSING ====

  /// Try to parse as integer
  int? get tryParseInt {
    return int.tryParse(this);
  }

  /// Try to parse as double
  double? get tryParseDouble {
    return double.tryParse(this);
  }

  /// Try to parse as boolean
  bool? get tryParseBool {
    final lower = toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
    return null;
  }

  // ==== ENCODING ====

  /// Encode for URL
  String get urlEncoded => Uri.encodeComponent(this);

  /// Decode from URL
  String get urlDecoded => Uri.decodeComponent(this);

  /// Base64 encode
  String get base64Encoded {
    try {
      final bytes = utf8.encode(this);
      return base64.encode(bytes);
    } catch (e) {
      return this;
    }
  }
}