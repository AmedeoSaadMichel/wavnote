// File: core/constants/app_constants.dart
import 'package:flutter/material.dart';
import '../enums/audio_format.dart';

/// Application-wide constants
///
/// Contains all shared constants including colors, dimensions,
/// audio settings, and configuration values used throughout the app.
/// Enhanced with mystical cosmic theme and new audio service configuration.
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

  // ==== AUDIO CONFIGURATION (ENHANCED) ====

  /// Default audio settings
  static const AudioFormat defaultAudioFormat = AudioFormat.m4a;
  static const int defaultSampleRate = 44100;
  static const int defaultBitRate = 128000;
  static const int maxRecordingDurationMinutes = 60;
  static const int maxRecordingsPerFolder = 1000;
  static const double minAmplitudeThreshold = 0.01;
  static const double maxAmplitudeValue = 1.0;

  /// Audio quality presets
  static const Map<String, Map<String, dynamic>> audioQualityPresets = {
    'low': {
      'sampleRate': 22050,
      'bitRate': 64000,
      'description': 'Smallest files, basic quality',
    },
    'medium': {
      'sampleRate': 44100,
      'bitRate': 128000,
      'description': 'Balanced size and quality',
    },
    'high': {
      'sampleRate': 48000,
      'bitRate': 256000,
      'description': 'Larger files, excellent quality',
    },
    'lossless': {
      'sampleRate': 96000,
      'bitRate': 512000,
      'description': 'Largest files, perfect quality',
    },
  };

  /// Playback speed options
  static const List<double> playbackSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

  /// Audio service configuration (NEW)
  static const bool enableRealAudioRecording = true;
  static const bool enableAudioVisualization = true;
  static const bool enableAmplitudeMonitoring = true;
  static const bool enableAdvancedAudioControls = true;
  static const bool enableAudioEffects = false; // Future feature
  static const bool enableBackgroundRecording = false; // Future feature

  // ==== FILE SYSTEM CONSTANTS ====
  static const String recordingsDirectory = 'recordings';
  static const String tempDirectory = 'temp';
  static const String backupDirectory = 'backups';
  static const String appDirectoryName = 'CosmicVoiceMemos';
  static const String defaultRecordingPrefix = 'Recording';
  static const String defaultFolderName = 'Voice Memos';
  static const int maxFileNameLength = 255;
  static const List<String> invalidFileNameChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];

  /// File size limits (in bytes)
  static const int maxRecordingFileSize = 500 * 1024 * 1024; // 500MB
  static const int maxTotalStorageSize = 2 * 1024 * 1024 * 1024; // 2GB

  // ==== MYSTICAL COSMIC THEME COLORS (ENHANCED) ====

  /// Primary cosmic colors for the Midnight Gospel inspired theme
  static const Color primaryPink = Color(0xFFDA22FF);
  static const Color primaryPurple = Color(0xFF8E2DE2);
  static const Color primaryBlue = Color(0xFF4A00E0);
  static const Color primaryOrange = Color(0xFFFF4E50);

  /// Accent colors for highlights and interactive elements
  static const Color accentCyan = Color(0xFF00F5FF);
  static const Color accentYellow = Color(0xFFFFD700);

  /// Background and surface colors
  static const Color backgroundDark = Color(0xFF0D1117);
  static const Color backgroundSpace = Color(0xFF1A1A2E);
  static const Color surfaceCard = Color(0xFF16213E);
  static const Color surfacePurple = Color(0xFF5A2B8C);

  /// Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B3B8);
  static const Color textMuted = Color(0xFF6E7681);

  // Legacy color compatibility (FIXED NAMING)
  static const Color accentCyanLegacy = Color(0xFF00BCD4);
  static const Color accentYellowLegacy = Color(0xFFFFEB3B);

  /// Folder colors (expanded with cosmic theme)
  static const List<Color> folderColors = [
    primaryPink,
    primaryPurple,
    primaryBlue,
    accentCyan,
    accentYellow,
    primaryOrange,
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

  // ==== COSMIC GRADIENTS (NEW) ====

  /// Cosmic gradients
  static const LinearGradient cosmicGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPurple, primaryPink, primaryOrange],
  );

  static const LinearGradient spaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundSpace, backgroundDark],
  );

  /// Legacy gradients (maintained for compatibility)
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

  // ==== DIMENSIONS & SPACING (ENHANCED) ====

  /// Standard spacing values following 8px grid
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  /// Legacy padding values (maintained for compatibility)
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;
  static const double smallPadding = 8.0;

  /// Border radius values
  static const double borderRadiusS = 8.0;
  static const double borderRadiusM = 12.0;
  static const double borderRadiusL = 16.0;
  static const double borderRadiusXL = 24.0;

  /// Legacy border radius (maintained for compatibility)
  static const double defaultBorderRadius = 12.0;
  static const double largeBorderRadius = 20.0;
  static const double smallBorderRadius = 8.0;

  /// Icon sizes
  static const double iconSizeS = 16.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;
  static const double iconSizeXL = 48.0;

  /// Button heights
  static const double buttonHeightS = 36.0;
  static const double buttonHeightM = 48.0;
  static const double buttonHeightL = 56.0;

  /// UI layout constants
  static const double defaultElevation = 4.0;
  static const double listItemHeight = 72.0;
  static const double folderItemHeight = 80.0;

  // ==== ANIMATIONS (ENHANCED) ====

  /// Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration defaultAnimationDuration = animationMedium;

  /// Legacy durations (maintained for compatibility)
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  static const Duration recordingPulseInterval = Duration(milliseconds: 100);
  static const Duration amplitudeUpdateInterval = Duration(milliseconds: 50);

  /// Animation curves
  static const Curve defaultAnimationCurve = Curves.easeInOut;
  static const Curve bounceAnimationCurve = Curves.elasticOut;

  // ==== TEXT STYLES (ENHANCED) ====
  static const TextStyle titleLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textMuted,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  // ==== FOLDER ICON OPTIONS (ENHANCED) ====
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

  // ==== WAVEFORM CONSTANTS (ENHANCED) ====
  static const int maxWaveformBars = 100;
  static const double waveformBarWidth = 3.0;
  static const double waveformBarSpacing = 1.0;
  static const double waveformMinHeight = 4.0;
  static const double waveformMaxHeight = 60.0;
  static const int waveformSampleRate = 20; // Updates per second

  /// Enhanced waveform visualization
  static const int waveformBars = 50;
  static const double maxWaveformHeight = 100.0;

  // ==== RECORDING CONSTANTS (ENHANCED) ====
  static const double recordButtonSize = 80.0;
  static const double playButtonSize = 50.0;
  static const double controlButtonSize = 40.0;
  static const Duration maxRecordingDuration = Duration(hours: 2);
  static const Duration minRecordingDuration = Duration(seconds: 1);

  /// Enhanced recording controls
  static const double controlButtonSizeEnhanced = 48.0;

  // ==== MYSTICAL UI ELEMENTS (NEW) ====

  /// Cosmic particle effects
  static const int particleCount = 50;
  static const double particleMinSize = 1.0;
  static const double particleMaxSize = 4.0;

  /// Glow effects
  static const double glowBlurRadius = 10.0;
  static const double glowSpreadRadius = 2.0;

  /// Shimmer animation
  static const Duration shimmerDuration = Duration(milliseconds: 1500);

  // ==== SEARCH & FILTER CONSTANTS ====
  static const int maxSearchResults = 100;
  static const int searchDebounceMs = 500;
  static const int minSearchQueryLength = 2;

  // ==== PERFORMANCE CONSTANTS ====
  static const int listViewCacheExtent = 1000;
  static const int maxConcurrentOperations = 3;
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration databaseTimeout = Duration(seconds: 10);

  // ==== PERMISSIONS (NEW) ====

  /// Required permissions
  static const List<String> requiredPermissions = [
    'microphone',
    'storage',
  ];

  /// Optional permissions
  static const List<String> optionalPermissions = [
    'location',
  ];

  // ==== ERROR MESSAGES (ENHANCED WITH MYSTICAL THEME) ====

  /// User-friendly error messages with mystical theme
  static const String errorGeneric = 'The cosmic energies are misaligned. Please try again.';
  static const String errorPermission = 'We need your permission to access the ethereal realm of audio.';
  static const String errorStorage = 'The astral storage dimension is full. Please free some space.';
  static const String errorRecording = 'The recording spell was interrupted. Please try again.';
  static const String errorPlayback = 'Unable to channel the audio frequencies. Please check the file.';

  /// Legacy error messages (maintained for compatibility)
  static const String errorNetwork = 'Network connection error';
  static const String errorFileNotFound = 'File not found';
  static const String errorInvalidFormat = 'Invalid audio format';
  static const String errorStorageFull = 'Storage space full';
  static const String errorRecordingFailed = 'Recording failed';
  static const String errorPlaybackFailed = 'Playback failed';

  // ==== SUCCESS MESSAGES (ENHANCED WITH MYSTICAL THEME) ====

  /// Success messages with mystical theme
  static const String successRecordingStarted = 'Recording begins... capturing your cosmic voice.';
  static const String successRecordingSaved = 'Your voice has been inscribed in the eternal memory.';
  static const String successPlaybackStarted = 'Channeling the stored frequencies...';

  /// Legacy success messages (maintained for compatibility)
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

  // ==== FEATURE FLAGS (ENHANCED) ====
  static const bool enableLocationServices = true;
  static const bool enableCloudBackup = false;
  static const bool enableWaveformVisualization = true;
  static const bool enableBiometricSecurity = false;
  static const bool enableDarkModeOnly = true;

  /// Development and testing flags
  static const bool enableDebugMode = false;
  static const bool enableLogging = true;
  static const bool enableAnalytics = false;
  static const bool enableBetaFeatures = false;

  /// Cloud and sync features
  static const bool enableCloudSync = false; // Future feature

  // ==== HELPER METHODS (ENHANCED) ====

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

  /// Get theme data for app (FIXED - removed deprecated properties)
  static ThemeData get themeData => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.dark(
      primary: accentYellow,
      secondary: accentCyan,
      surface: surfacePurple,
      onSurface: textPrimary,
      // Removed deprecated 'background' and 'onBackground'
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: titleMedium,
      foregroundColor: textPrimary,
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
    cardTheme: CardThemeData(
      color: surfaceCard,
      elevation: defaultElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(defaultBorderRadius),
      ),
    ),
  );

  // ==== PRIVATE CONSTRUCTOR ====

  /// Prevent instantiation
  AppConstants._();
}