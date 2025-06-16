// File: core/constants/app_constants.dart
import 'package:flutter/material.dart';
import '../enums/audio_format.dart';

/// Application-wide constants
///
/// Centralized location for all app constants including colors,
/// sizes, durations, and configuration values.
class AppConstants {

  // ==== APP INFORMATION ====
  static const String appName = 'WavNote';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Voice memo app for iOS';

  // ==== DATABASE CONSTANTS ====
  static const String databaseName = 'voice_memo.db';
  static const int databaseVersion = 1;
  static const String foldersTable = 'folders';
  static const String recordingsTable = 'recordings';
  static const String settingsTable = 'settings';

  // ==== AUDIO CONSTANTS ====
  static const AudioFormat defaultAudioFormat = AudioFormat.m4a;
  static const int defaultSampleRate = 44100;
  static const int defaultBitRate = 128000;
  static const int maxRecordingDurationMinutes = 60;
  static const int maxRecordingsPerFolder = 1000;
  static const double minAmplitudeThreshold = 0.01;
  static const double maxAmplitudeValue = 1.0;

  // ==== FILE SYSTEM CONSTANTS ====
  static const String recordingsDirectory = 'recordings';
  static const String tempDirectory = 'temp';
  static const String backupDirectory = 'backups';
  static const int maxFileNameLength = 255;
  static const List<String> invalidFileNameChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];

  // ==== UI CONSTANTS ====
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;
  static const double smallPadding = 8.0;
  static const double defaultBorderRadius = 12.0;
  static const double largeBorderRadius = 20.0;
  static const double smallBorderRadius = 8.0;
  static const double defaultElevation = 4.0;
  static const double listItemHeight = 72.0;
  static const double folderItemHeight = 80.0;

  // ==== ANIMATION DURATIONS ====
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  static const Duration recordingPulseInterval = Duration(milliseconds: 100);
  static const Duration amplitudeUpdateInterval = Duration(milliseconds: 50);

  // ==== COLOR PALETTE ====
  static const Color primaryPurple = Color(0xFF8E2DE2);
  static const Color primaryPink = Color(0xFFDA22FF);
  static const Color primaryOrange = Color(0xFFFF4E50);
  static const Color accentYellow = Color(0xFFFFEB3B);
  static const Color accentCyan = Color(0xFF00BCD4);
  static const Color surfacePurple = Color(0xFF5A2B8C);
  static const Color backgroundDark = Color(0xFF2D1B69);

  // Folder colors
  static const List<Color> folderColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.indigo,
    Colors.blue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
  ];

  // ==== GRADIENT DEFINITIONS ====
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPurple, primaryPink, primaryOrange],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundDark, surfacePurple],
  );

  // ==== TEXT STYLES ====
  static const TextStyle titleLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: Colors.white,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Colors.white70,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Colors.white60,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  // ==== FOLDER ICON OPTIONS ====
  static const List<IconData> folderIcons = [
    Icons.folder,
    Icons.folder_outlined,
    Icons.work,
    Icons.home,
    Icons.school,
    Icons.music_note,
    Icons.mic,
    Icons.headphones,
    Icons.radio,
    Icons.album,
    Icons.audiotrack,
    Icons.library_music,
    Icons.queue_music,
    Icons.record_voice_over,
    Icons.speaker,
    Icons.volume_up,
    Icons.favorite,
    Icons.star,
    Icons.bookmark,
    Icons.label,
  ];

  // ==== WAVEFORM CONSTANTS ====
  static const int maxWaveformBars = 100;
  static const double waveformBarWidth = 3.0;
  static const double waveformBarSpacing = 1.0;
  static const double waveformMinHeight = 4.0;
  static const double waveformMaxHeight = 60.0;
  static const int waveformSampleRate = 20; // Updates per second

  // ==== RECORDING CONSTANTS ====
  static const double recordButtonSize = 80.0;
  static const double playButtonSize = 50.0;
  static const double controlButtonSize = 40.0;
  static const Duration maxRecordingDuration = Duration(hours: 2);
  static const Duration minRecordingDuration = Duration(seconds: 1);

  // ==== SEARCH & FILTER CONSTANTS ====
  static const int maxSearchResults = 100;
  static const int searchDebounceMs = 500;
  static const int minSearchQueryLength = 2;

  // ==== PERFORMANCE CONSTANTS ====
  static const int listViewCacheExtent = 1000;
  static const int maxConcurrentOperations = 3;
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration databaseTimeout = Duration(seconds: 10);

  // ==== ERROR MESSAGES ====
  static const String errorGeneric = 'An unexpected error occurred';
  static const String errorNetwork = 'Network connection error';
  static const String errorPermission = 'Permission denied';
  static const String errorFileNotFound = 'File not found';
  static const String errorInvalidFormat = 'Invalid audio format';
  static const String errorStorageFull = 'Storage space full';
  static const String errorRecordingFailed = 'Recording failed';
  static const String errorPlaybackFailed = 'Playback failed';

  // ==== SUCCESS MESSAGES ====
  static const String successRecordingSaved = 'Recording saved successfully';
  static const String successFolderCreated = 'Folder created successfully';
  static const String successRecordingDeleted = 'Recording deleted';
  static const String successFolderDeleted = 'Folder deleted';
  static const String successExported = 'Data exported successfully';
  static const String successImported = 'Data imported successfully';

  // ==== VALIDATION CONSTANTS ====
  static const int maxFolderNameLength = 50;
  static const int maxRecordingNameLength = 100;
  static const int minNameLength = 1;
  static const int maxTagLength = 20;
  static const int maxTagsPerRecording = 10;

  // ==== BACKUP CONSTANTS ====
  static const String backupFileExtension = '.wavnote';
  static const String exportFileExtension = '.json';
  static const int maxBackupFiles = 10;
  static const Duration backupInterval = Duration(days: 7);

  // ==== FEATURE FLAGS ====
  static const bool enableLocationServices = true;
  static const bool enableCloudBackup = false;
  static const bool enableWaveformVisualization = true;
  static const bool enableBiometricSecurity = false;
  static const bool enableDarkModeOnly = true;

  // ==== HELPER METHODS ====

  /// Get folder color by index
  static Color getFolderColor(int index) {
    return folderColors[index % folderColors.length];
  }

  /// Get folder icon by index
  static IconData getFolderIcon(int index) {
    return folderIcons[index % folderIcons.length];
  }

  /// Validate folder name
  static bool isValidFolderName(String name) {
    final trimmed = name.trim();
    return trimmed.length >= minNameLength &&
        trimmed.length <= maxFolderNameLength &&
        !invalidFileNameChars.any((char) => trimmed.contains(char));
  }

  /// Validate recording name
  static bool isValidRecordingName(String name) {
    final trimmed = name.trim();
    return trimmed.length >= minNameLength &&
        trimmed.length <= maxRecordingNameLength &&
        !invalidFileNameChars.any((char) => trimmed.contains(char));
  }

  /// Get safe file name (remove invalid characters)
  static String getSafeFileName(String name) {
    String safeName = name.trim();
    for (final char in invalidFileNameChars) {
      safeName = safeName.replaceAll(char, '_');
    }
    return safeName.length > maxFileNameLength
        ? safeName.substring(0, maxFileNameLength)
        : safeName;
  }

  /// Get theme data for app
  static ThemeData get themeData => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.dark(
      primary: accentYellow,
      secondary: accentCyan,
      surface: surfacePurple,
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: titleMedium,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentYellow,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
        ),
        elevation: defaultElevation,
      ),
    ),
  );
}