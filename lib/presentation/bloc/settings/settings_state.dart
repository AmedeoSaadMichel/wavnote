// File: presentation/bloc/settings/settings_state.dart
part of 'settings_bloc.dart';

/// Base class for all settings states
abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

/// Initial state when settings bloc is first created
class SettingsInitial extends SettingsState {
  const SettingsInitial();

  @override
  String toString() => 'SettingsInitial';
}

/// State when settings are being loaded
class SettingsLoading extends SettingsState {
  const SettingsLoading();

  @override
  String toString() => 'SettingsLoading';
}

/// State when settings are successfully loaded
class SettingsLoaded extends SettingsState {
  final AppSettings settings;

  const SettingsLoaded({required this.settings});

  @override
  List<Object> get props => [settings];

  /// Quick access to audio format
  AudioFormat get audioFormat => settings.audioFormat;

  /// Quick access to audio quality
  AudioQuality get audioQuality => settings.audioQuality;

  /// Quick access to sample rate
  int get sampleRate => settings.sampleRate;

  /// Quick access to bit rate
  int get bitRate => settings.bitRate;

  /// Quick access to waveform setting
  bool get enableRealTimeWaveform => settings.enableRealTimeWaveform;

  /// Quick access to amplitude visualization setting
  bool get enableAmplitudeVisualization => settings.enableAmplitudeVisualization;

  /// Quick access to haptic feedback setting
  bool get enableHapticFeedback => settings.enableHapticFeedback;

  /// Quick access to animations setting
  bool get enableAnimations => settings.enableAnimations;

  /// Get formatted quality description
  String get qualityDescription => audioQuality.description;

  /// Get formatted file size estimation
  String get estimatedFileSize {
    // Rough calculation for 1 minute of audio
    final bytesPerSecond = (bitRate / 8) * 60; // Convert bits to bytes for 1 minute
    final kb = bytesPerSecond / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(0)} KB/min';
    } else {
      final mb = kb / 1024;
      return '${mb.toStringAsFixed(1)} MB/min';
    }
  }

  /// Check if settings have been modified recently
  bool get isRecentlyModified {
    final now = DateTime.now();
    final difference = now.difference(settings.lastModified);
    return difference.inMinutes < 5;
  }

  @override
  String toString() => 'SettingsLoaded { format: ${audioFormat.name}, quality: ${audioQuality.name} }';
}

/// State when an error occurs
class SettingsError extends SettingsState {
  final String message;
  final String? errorCode;
  final dynamic error;

  const SettingsError(
      this.message, {
        this.errorCode,
        this.error,
      });

  @override
  List<Object?> get props => [message, errorCode, error];

  /// Whether this is a validation error
  bool get isValidationError => errorCode == 'VALIDATION_ERROR';

  /// Whether this is a storage error
  bool get isStorageError => errorCode == 'STORAGE_ERROR';

  /// Whether this is a permission error
  bool get isPermissionError => errorCode == 'PERMISSION_ERROR';

  @override
  String toString() => 'SettingsError { message: $message, errorCode: $errorCode }';
}