// File: config/app_config.dart
import '../core/enums/audio_format.dart';

/// Application configuration settings
///
/// Centralizes app configuration and feature flags
/// for easy management across environments.
class AppConfig {

  // ==== RECORDING SETTINGS ====
  static const AudioFormat defaultRecordingFormat = AudioFormat.m4a;
  static const int defaultSampleRate = 44100;
  static const int defaultBitRate = 128000;
  static const bool enableRealTimeWaveform = true;
  static const bool enableAmplitudeVisualization = true;

  // ==== FEATURE FLAGS ====
  static const bool useRealAudioRecording = true; // Toggle for development
  static const bool enableLocationRecording = false; // Location metadata
  static const bool enableCloudSync = false; // Future cloud backup
  static const bool enableDeveloperMode = false; // Debug features
  static const bool enableBetaFeatures = false; // Experimental features

  // ==== UI SETTINGS ====
  static const bool enableDarkModeOnly = true;
  static const bool enableAnimations = true;
  static const bool enableHapticFeedback = true;
  static const double defaultAnimationSpeed = 1.0;

  // ==== PERFORMANCE SETTINGS ====
  static const int maxConcurrentRecordings = 1;
  static const int maxRecordingsPerFolder = 1000;
  static const int maxFolders = 50;
  static const Duration recordingTimeout = Duration(hours: 2);

  // ==== STORAGE SETTINGS ====
  static const int maxTotalStorageMB = 2048; // 2GB
  static const int warningStorageThresholdMB = 1536; // 1.5GB
  static const bool enableAutomaticCleanup = true;
  static const Duration cleanupInterval = Duration(days: 30);

  // ==== BACKUP SETTINGS ====
  static const bool enableAutoBackup = false;
  static const Duration backupInterval = Duration(days: 7);
  static const int maxBackupFiles = 10;
  static const bool compressBackups = true;

  // ==== AUDIO PROCESSING ====
  static const bool enableNoiseReduction = false; // Future feature
  static const bool enableAudioEnhancement = false; // Future feature
  static const bool enableAutoGainControl = false; // Future feature

  // ==== SECURITY SETTINGS ====
  static const bool enableBiometricLock = false; // Future feature
  static const bool enableRecordingEncryption = false; // Future feature
  static const Duration lockTimeout = Duration(minutes: 5);

  // ==== DEVELOPMENT SETTINGS ====
  static const bool enableDebugLogs = true;
  static const bool enablePerformanceMonitoring = false;
  static const bool enableCrashReporting = false;
  static const bool showDebugInfo = false;

  // ==== HELPER METHODS ====

  /// Check if feature is enabled
  static bool isFeatureEnabled(String featureName) {
    switch (featureName.toLowerCase()) {
      case 'real_audio':
        return useRealAudioRecording;
      case 'location':
        return enableLocationRecording;
      case 'cloud_sync':
        return enableCloudSync;
      case 'developer_mode':
        return enableDeveloperMode;
      case 'beta_features':
        return enableBetaFeatures;
      case 'dark_mode_only':
        return enableDarkModeOnly;
      case 'animations':
        return enableAnimations;
      case 'haptic_feedback':
        return enableHapticFeedback;
      case 'auto_backup':
        return enableAutoBackup;
      case 'biometric_lock':
        return enableBiometricLock;
      case 'debug_logs':
        return enableDebugLogs;
      default:
        return false;
    }
  }

  /// Get app version info
  static Map<String, dynamic> getVersionInfo() {
    return {
      'app_version': '1.0.0',
      'build_number': '1',
      'build_date': DateTime.now().toIso8601String(),
      'features_enabled': [
        if (useRealAudioRecording) 'real_audio',
        if (enableLocationRecording) 'location',
        if (enableCloudSync) 'cloud_sync',
        if (enableDeveloperMode) 'developer_mode',
        if (enableBetaFeatures) 'beta_features',
      ],
    };
  }

  /// Get storage configuration
  static Map<String, dynamic> getStorageConfig() {
    return {
      'max_total_storage_mb': maxTotalStorageMB,
      'warning_threshold_mb': warningStorageThresholdMB,
      'max_recordings_per_folder': maxRecordingsPerFolder,
      'max_folders': maxFolders,
      'enable_automatic_cleanup': enableAutomaticCleanup,
      'cleanup_interval_days': cleanupInterval.inDays,
    };
  }

  /// Get recording configuration
  static Map<String, dynamic> getRecordingConfig() {
    return {
      'default_format': _getFormatName(defaultRecordingFormat),
      'default_sample_rate': defaultSampleRate,
      'default_bit_rate': defaultBitRate,
      'max_concurrent_recordings': maxConcurrentRecordings,
      'recording_timeout_hours': recordingTimeout.inHours,
      'enable_real_time_waveform': enableRealTimeWaveform,
      'enable_amplitude_visualization': enableAmplitudeVisualization,
    };
  }

  /// Get development configuration
  static Map<String, dynamic> getDeveloperConfig() {
    return {
      'enable_debug_logs': enableDebugLogs,
      'enable_performance_monitoring': enablePerformanceMonitoring,
      'enable_crash_reporting': enableCrashReporting,
      'show_debug_info': showDebugInfo,
      'developer_mode': enableDeveloperMode,
    };
  }

  /// Export all configuration
  static Map<String, dynamic> exportConfiguration() {
    return {
      'version_info': getVersionInfo(),
      'storage_config': getStorageConfig(),
      'recording_config': getRecordingConfig(),
      'developer_config': getDeveloperConfig(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Validate configuration consistency
  static List<String> validateConfiguration() {
    final issues = <String>[];

    // Check storage limits
    if (maxTotalStorageMB <= warningStorageThresholdMB) {
      issues.add('Warning threshold should be less than max storage');
    }

    // Check recording limits
    if (maxRecordingsPerFolder <= 0) {
      issues.add('Max recordings per folder must be positive');
    }

    if (maxFolders <= 0) {
      issues.add('Max folders must be positive');
    }

    // Check timeout values
    if (recordingTimeout.inSeconds <= 0) {
      issues.add('Recording timeout must be positive');
    }

    if (lockTimeout.inSeconds <= 0) {
      issues.add('Lock timeout must be positive');
    }

    return issues;
  }

  /// Get environment-specific settings
  static Map<String, dynamic> getEnvironmentSettings() {
    // This could be expanded to handle different environments
    // (development, staging, production)
    return {
      'environment': 'development',
      'api_base_url': null, // No API yet
      'enable_analytics': false,
      'enable_remote_config': false,
      'log_level': enableDebugLogs ? 'debug' : 'info',
    };
  }

  // ==== PRIVATE HELPER METHODS ====

  /// Get format name from audio format enum
  static String _getFormatName(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return 'WAV';
      case AudioFormat.m4a:
        return 'M4A';
      case AudioFormat.flac:
        return 'FLAC';
    }
  }
}