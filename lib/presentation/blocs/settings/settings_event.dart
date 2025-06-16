// File: presentation/blocs/settings/settings_event.dart
part of 'settings_bloc.dart';

/// Base class for all settings-related events
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load settings from storage
class LoadSettings extends SettingsEvent {
  const LoadSettings();

  @override
  String toString() => 'LoadSettings';
}

/// Event to update audio format preference
class UpdateAudioFormat extends SettingsEvent {
  final AudioFormat format;

  const UpdateAudioFormat(this.format);

  @override
  List<Object> get props => [format];

  @override
  String toString() => 'UpdateAudioFormat { format: ${format.name} }';
}

/// Event to update audio quality setting
class UpdateAudioQuality extends SettingsEvent {
  final AudioQuality quality;

  const UpdateAudioQuality(this.quality);

  @override
  List<Object> get props => [quality];

  @override
  String toString() => 'UpdateAudioQuality { quality: ${quality.name} }';
}

/// Event to update sample rate
class UpdateSampleRate extends SettingsEvent {
  final int sampleRate;

  const UpdateSampleRate(this.sampleRate);

  @override
  List<Object> get props => [sampleRate];

  @override
  String toString() => 'UpdateSampleRate { sampleRate: $sampleRate }';
}

/// Event to update bit rate
class UpdateBitRate extends SettingsEvent {
  final int bitRate;

  const UpdateBitRate(this.bitRate);

  @override
  List<Object> get props => [bitRate];

  @override
  String toString() => 'UpdateBitRate { bitRate: $bitRate }';
}

/// Event to toggle real-time waveform visualization
class ToggleRealTimeWaveform extends SettingsEvent {
  const ToggleRealTimeWaveform();

  @override
  String toString() => 'ToggleRealTimeWaveform';
}

/// Event to toggle amplitude visualization
class ToggleAmplitudeVisualization extends SettingsEvent {
  const ToggleAmplitudeVisualization();

  @override
  String toString() => 'ToggleAmplitudeVisualization';
}

/// Event to toggle haptic feedback
class ToggleHapticFeedback extends SettingsEvent {
  const ToggleHapticFeedback();

  @override
  String toString() => 'ToggleHapticFeedback';
}

/// Event to toggle animations
class ToggleAnimations extends SettingsEvent {
  const ToggleAnimations();

  @override
  String toString() => 'ToggleAnimations';
}

/// Event to reset all settings to defaults
class ResetSettings extends SettingsEvent {
  const ResetSettings();

  @override
  String toString() => 'ResetSettings';
}

/// Event to export settings
class ExportSettings extends SettingsEvent {
  const ExportSettings();

  @override
  String toString() => 'ExportSettings';
}

/// Event to import settings from data
class ImportSettings extends SettingsEvent {
  final Map<String, dynamic> settingsData;

  const ImportSettings(this.settingsData);

  @override
  List<Object> get props => [settingsData];

  @override
  String toString() => 'ImportSettings { data: $settingsData }';
}