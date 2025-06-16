// File: presentation/blocs/settings/settings_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/enums/audio_format.dart';

part 'settings_event.dart';
part 'settings_state.dart';

/// Bloc responsible for managing app settings and configuration
///
/// Handles audio format preferences, quality settings, and other app preferences.
/// Provides persistent storage of user preferences.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {

  SettingsBloc() : super(const SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateAudioFormat>(_onUpdateAudioFormat);
    on<UpdateAudioQuality>(_onUpdateAudioQuality);
    on<UpdateSampleRate>(_onUpdateSampleRate);
    on<UpdateBitRate>(_onUpdateBitRate);
    on<ToggleRealTimeWaveform>(_onToggleRealTimeWaveform);
    on<ToggleAmplitudeVisualization>(_onToggleAmplitudeVisualization);
    on<ToggleHapticFeedback>(_onToggleHapticFeedback);
    on<ToggleAnimations>(_onToggleAnimations);
    on<ResetSettings>(_onResetSettings);
    on<ExportSettings>(_onExportSettings);
    on<ImportSettings>(_onImportSettings);
  }

  /// Load settings from storage
  Future<void> _onLoadSettings(
      LoadSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      emit(const SettingsLoading());

      // TODO: Load from actual storage service
      // For now, return default settings
      final settings = AppSettings.defaultSettings();

      emit(SettingsLoaded(settings: settings));
      print('✅ Settings loaded successfully');

    } catch (e) {
      print('❌ Error loading settings: $e');
      emit(SettingsError('Failed to load settings: ${e.toString()}'));
    }
  }

  /// Update audio format preference
  Future<void> _onUpdateAudioFormat(
      UpdateAudioFormat event,
      Emitter<SettingsState> emit,
      ) async {
    if (state is! SettingsLoaded) return;

    final currentState = state as SettingsLoaded;

    try {
      final updatedSettings = currentState.settings.copyWith(
        audioFormat: event.format,
      );

      // TODO: Save to storage service
      emit(SettingsLoaded(settings: updatedSettings));
      print('✅ Audio format updated to: ${event.format.name}');

    } catch (e) {
      print('❌ Error updating audio format: $e');
      emit(SettingsError('Failed to update audio format: ${e.toString()}'));
    }
  }

  /// Update audio quality setting
  Future<void> _onUpdateAudioQuality(
      UpdateAudioQuality event,
      Emitter<SettingsState> emit,
      ) async {
    if (state is! SettingsLoaded) return;

    final currentState = state as SettingsLoaded;

    try {
      final updatedSettings = currentState.settings.copyWith(
        audioQuality: event.quality,
      );

      emit(SettingsLoaded(settings: updatedSettings));
      print('✅ Audio quality updated to: ${event.quality.name}');

    } catch (e) {
      print('❌ Error updating audio quality: $e');
      emit(SettingsError('Failed to update audio quality: ${e.toString()}'));
    }
  }

  /// Update sample rate
  Future<void> _onUpdateSampleRate(
      UpdateSampleRate event,
      Emitter<SettingsState> emit,
      ) async {
    if (state is! SettingsLoaded) return;

    final currentState = state as SettingsLoaded;

    try {
      final updatedSettings = currentState.settings.copyWith(
        sampleRate: event.sampleRate,
      );

      emit(SettingsLoaded(settings: updatedSettings));
      print('✅ Sample rate updated to: ${event.sampleRate} Hz');

    } catch (e) {
      print('❌ Error updating sample rate: $e');
      emit(SettingsError('Failed to update sample rate: ${e.toString()}'));
    }
  }

  /// Update bit rate
  Future<void> _onUpdateBitRate(
      UpdateBitRate event,
      Emitter<SettingsState> emit,
      ) async {
    if (state is! SettingsLoaded) return;

    final currentState = state as SettingsLoaded;

    try {
      final updatedSettings = currentState.settings.copyWith(
        bitRate: event.bitRate,
      );

      emit(SettingsLoaded(settings: updatedSettings));
      print('✅ Bit rate updated to: ${event.bitRate} kbps');

    } catch (e) {
      print('❌ Error updating bit rate: $e');
      emit(SettingsError('Failed to update bit rate: ${e.toString()}'));
    }
  }

  /// Toggle real-time waveform setting
  Future<void> _onToggleRealTimeWaveform(
      ToggleRealTimeWaveform event,
      Emitter<SettingsState> emit,
      ) async {
    if (state is! SettingsLoaded) return;

    final currentState = state as SettingsLoaded;

    try {
      final updatedSettings = currentState.settings.copyWith(
        enableRealTimeWaveform: !currentState.settings.enableRealTimeWaveform,
      );

      emit(SettingsLoaded(settings: updatedSettings));
      print('✅ Real-time waveform: ${updatedSettings.enableRealTimeWaveform}');

    } catch (e) {
      print('❌ Error toggling real-time waveform: $e');
      emit(SettingsError('Failed to toggle waveform setting'));
    }
  }

  /// Toggle amplitude visualization setting
  Future<void> _onToggleAmplitudeVisualization(
      ToggleAmplitudeVisualization event,
      Emitter<SettingsState> emit,
      ) async {
    if (state is! SettingsLoaded) return;

    final currentState = state as SettingsLoaded;

    try {
      final updatedSettings = currentState.settings.copyWith(
        enableAmplitudeVisualization: !currentState.settings.enableAmplitudeVisualization,
      );

      emit(SettingsLoaded(settings: updatedSettings));
      print('✅ Amplitude visualization: ${updatedSettings.enableAmplitudeVisualization}');

    } catch (e) {
      print('❌ Error toggling amplitude visualization: $e');
      emit(SettingsError('Failed to toggle amplitude visualization'));
    }
  }

  /// Toggle haptic feedback setting
  Future<void> _onToggleHapticFeedback(
      ToggleHapticFeedback event,
      Emitter<SettingsState> emit,
      ) async {
    if (state is! SettingsLoaded) return;

    final currentState = state as SettingsLoaded;

    try {
      final updatedSettings = currentState.settings.copyWith(
        enableHapticFeedback: !currentState.settings.enableHapticFeedback,
      );

      emit(SettingsLoaded(settings: updatedSettings));
      print('✅ Haptic feedback: ${updatedSettings.enableHapticFeedback}');

    } catch (e) {
      print('❌ Error toggling haptic feedback: $e');
      emit(SettingsError('Failed to toggle haptic feedback'));
    }
  }

  /// Toggle animations setting
  Future<void> _onToggleAnimations(
      ToggleAnimations event,
      Emitter<SettingsState> emit,
      ) async {
    if (state is! SettingsLoaded) return;

    final currentState = state as SettingsLoaded;

    try {
      final updatedSettings = currentState.settings.copyWith(
        enableAnimations: !currentState.settings.enableAnimations,
      );

      emit(SettingsLoaded(settings: updatedSettings));
      print('✅ Animations: ${updatedSettings.enableAnimations}');

    } catch (e) {
      print('❌ Error toggling animations: $e');
      emit(SettingsError('Failed to toggle animations'));
    }
  }

  /// Reset all settings to defaults
  Future<void> _onResetSettings(
      ResetSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      emit(const SettingsLoading());

      final defaultSettings = AppSettings.defaultSettings();

      // TODO: Clear from storage service
      emit(SettingsLoaded(settings: defaultSettings));
      print('✅ Settings reset to defaults');

    } catch (e) {
      print('❌ Error resetting settings: $e');
      emit(SettingsError('Failed to reset settings: ${e.toString()}'));
    }
  }

  /// Export settings to JSON
  Future<void> _onExportSettings(
      ExportSettings event,
      Emitter<SettingsState> emit,
      ) async {
    if (state is! SettingsLoaded) return;

    final currentState = state as SettingsLoaded;

    try {
      final exportData = currentState.settings.toJson();

      // TODO: Handle actual export logic
      print('✅ Settings exported: $exportData');

      // For now, just maintain current state
      emit(currentState);

    } catch (e) {
      print('❌ Error exporting settings: $e');
      emit(SettingsError('Failed to export settings: ${e.toString()}'));
    }
  }

  /// Import settings from JSON
  Future<void> _onImportSettings(
      ImportSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      emit(const SettingsLoading());

      final settings = AppSettings.fromJson(event.settingsData);

      // TODO: Save to storage service
      emit(SettingsLoaded(settings: settings));
      print('✅ Settings imported successfully');

    } catch (e) {
      print('❌ Error importing settings: $e');
      emit(SettingsError('Failed to import settings: ${e.toString()}'));
    }
  }
}

/// Audio quality enum
enum AudioQuality {
  low,
  medium,
  high,
  lossless,
}

extension AudioQualityExtension on AudioQuality {
  String get name {
    switch (this) {
      case AudioQuality.low:
        return 'Low';
      case AudioQuality.medium:
        return 'Medium';
      case AudioQuality.high:
        return 'High';
      case AudioQuality.lossless:
        return 'Lossless';
    }
  }

  String get description {
    switch (this) {
      case AudioQuality.low:
        return 'Smallest files, basic quality';
      case AudioQuality.medium:
        return 'Balanced size and quality';
      case AudioQuality.high:
        return 'Larger files, excellent quality';
      case AudioQuality.lossless:
        return 'Largest files, perfect quality';
    }
  }

  int get sampleRate {
    switch (this) {
      case AudioQuality.low:
        return 22050;
      case AudioQuality.medium:
        return 44100;
      case AudioQuality.high:
        return 48000;
      case AudioQuality.lossless:
        return 96000;
    }
  }

  int get bitRate {
    switch (this) {
      case AudioQuality.low:
        return 64000;
      case AudioQuality.medium:
        return 128000;
      case AudioQuality.high:
        return 256000;
      case AudioQuality.lossless:
        return 512000;
    }
  }
}

/// App settings data class
class AppSettings extends Equatable {
  final AudioFormat audioFormat;
  final AudioQuality audioQuality;
  final int sampleRate;
  final int bitRate;
  final bool enableRealTimeWaveform;
  final bool enableAmplitudeVisualization;
  final bool enableHapticFeedback;
  final bool enableAnimations;
  final DateTime lastModified;

  const AppSettings({
    required this.audioFormat,
    required this.audioQuality,
    required this.sampleRate,
    required this.bitRate,
    required this.enableRealTimeWaveform,
    required this.enableAmplitudeVisualization,
    required this.enableHapticFeedback,
    required this.enableAnimations,
    required this.lastModified,
  });

  /// Create default settings
  factory AppSettings.defaultSettings() {
    return AppSettings(
      audioFormat: AudioFormat.m4a,
      audioQuality: AudioQuality.high,
      sampleRate: 44100,
      bitRate: 128000,
      enableRealTimeWaveform: true,
      enableAmplitudeVisualization: true,
      enableHapticFeedback: true,
      enableAnimations: true,
      lastModified: DateTime.now(),
    );
  }

  /// Create from JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      audioFormat: AudioFormat.values[json['audioFormat'] ?? 1],
      audioQuality: AudioQuality.values[json['audioQuality'] ?? 2],
      sampleRate: json['sampleRate'] ?? 44100,
      bitRate: json['bitRate'] ?? 128000,
      enableRealTimeWaveform: json['enableRealTimeWaveform'] ?? true,
      enableAmplitudeVisualization: json['enableAmplitudeVisualization'] ?? true,
      enableHapticFeedback: json['enableHapticFeedback'] ?? true,
      enableAnimations: json['enableAnimations'] ?? true,
      lastModified: DateTime.parse(json['lastModified'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'audioFormat': audioFormat.index,
      'audioQuality': audioQuality.index,
      'sampleRate': sampleRate,
      'bitRate': bitRate,
      'enableRealTimeWaveform': enableRealTimeWaveform,
      'enableAmplitudeVisualization': enableAmplitudeVisualization,
      'enableHapticFeedback': enableHapticFeedback,
      'enableAnimations': enableAnimations,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  /// Create copy with updated values
  AppSettings copyWith({
    AudioFormat? audioFormat,
    AudioQuality? audioQuality,
    int? sampleRate,
    int? bitRate,
    bool? enableRealTimeWaveform,
    bool? enableAmplitudeVisualization,
    bool? enableHapticFeedback,
    bool? enableAnimations,
    DateTime? lastModified,
  }) {
    return AppSettings(
      audioFormat: audioFormat ?? this.audioFormat,
      audioQuality: audioQuality ?? this.audioQuality,
      sampleRate: sampleRate ?? this.sampleRate,
      bitRate: bitRate ?? this.bitRate,
      enableRealTimeWaveform: enableRealTimeWaveform ?? this.enableRealTimeWaveform,
      enableAmplitudeVisualization: enableAmplitudeVisualization ?? this.enableAmplitudeVisualization,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      lastModified: lastModified ?? DateTime.now(),
    );
  }

  @override
  List<Object> get props => [
    audioFormat,
    audioQuality,
    sampleRate,
    bitRate,
    enableRealTimeWaveform,
    enableAmplitudeVisualization,
    enableHapticFeedback,
    enableAnimations,
    lastModified,
  ];

  @override
  String toString() => 'AppSettings(format: ${audioFormat.name}, quality: ${audioQuality.name})';
}