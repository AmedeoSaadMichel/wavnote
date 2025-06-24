// File: presentation/bloc/settings/settings_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/enums/audio_format.dart';
import '../../../data/database/database_helper.dart';

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
    on<UpdateLastOpenedFolder>(_onUpdateLastOpenedFolder);
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

      // Load settings from database
      final settings = await _loadSettingsFromDatabase();

      emit(SettingsLoaded(settings: settings));
      print('✅ Settings loaded successfully');

    } catch (e) {
      print('❌ Error loading settings: $e');
      emit(SettingsError('Failed to load settings: ${e.toString()}'));
    }
  }

  /// Load settings from database
  Future<AppSettings> _loadSettingsFromDatabase() async {
    try {
      final db = await DatabaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(DatabaseHelper.settingsTable);
      
      // Convert to key-value map
      final Map<String, String> settingsMap = {};
      for (final map in maps) {
        settingsMap[map[DatabaseHelper.settingKeyColumn]] = map[DatabaseHelper.settingValueColumn];
      }
      
      print('📊 Loaded ${settingsMap.length} settings from database');
      print('📊 Settings map: $settingsMap');
      
      // Create AppSettings from stored values, with defaults for missing values
      return AppSettings(
        audioFormat: _parseAudioFormat(settingsMap['audioFormat']),
        audioQuality: _parseAudioQuality(settingsMap['audioQuality']),
        sampleRate: int.tryParse(settingsMap['sampleRate'] ?? '') ?? 44100,
        bitRate: int.tryParse(settingsMap['bitRate'] ?? '') ?? 128000,
        enableRealTimeWaveform: _parseBool(settingsMap['enableRealTimeWaveform'], true),
        enableAmplitudeVisualization: _parseBool(settingsMap['enableAmplitudeVisualization'], true),
        enableHapticFeedback: _parseBool(settingsMap['enableHapticFeedback'], true),
        enableAnimations: _parseBool(settingsMap['enableAnimations'], true),
        lastOpenedFolderId: () {
          final rawValue = settingsMap['lastOpenedFolderId'];
          final processedValue = (rawValue?.isEmpty == true || rawValue == null) ? 'main' : rawValue;
          print('📁 Loading lastOpenedFolderId - Raw: "$rawValue", Processed: "$processedValue"');
          return processedValue;
        }(),
        lastModified: DateTime.tryParse(settingsMap['lastModified'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      print('❌ Error loading settings from database: $e');
      // Return default settings if loading fails
      return AppSettings.defaultSettings();
    }
  }

  /// Parse audio format from string
  AudioFormat _parseAudioFormat(String? value) {
    try {
      final index = int.tryParse(value ?? '');
      if (index != null && index >= 0 && index < AudioFormat.values.length) {
        return AudioFormat.values[index];
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return AudioFormat.m4a; // Default
  }

  /// Parse audio quality from string
  AudioQuality _parseAudioQuality(String? value) {
    try {
      final index = int.tryParse(value ?? '');
      if (index != null && index >= 0 && index < AudioQuality.values.length) {
        return AudioQuality.values[index];
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return AudioQuality.high; // Default
  }

  /// Parse boolean from string
  bool _parseBool(String? value, bool defaultValue) {
    if (value == null) return defaultValue;
    return value.toLowerCase() == 'true';
  }

  /// Save settings to database
  Future<void> _saveSettingsToDatabase(AppSettings settings) async {
    try {
      final db = await DatabaseHelper.database;
      final now = DateTime.now().toIso8601String();
      
      // Prepare all settings as key-value pairs
      final settingsToSave = {
        'audioFormat': settings.audioFormat.index.toString(),
        'audioQuality': settings.audioQuality.index.toString(),
        'sampleRate': settings.sampleRate.toString(),
        'bitRate': settings.bitRate.toString(),
        'enableRealTimeWaveform': settings.enableRealTimeWaveform.toString(),
        'enableAmplitudeVisualization': settings.enableAmplitudeVisualization.toString(),
        'enableHapticFeedback': settings.enableHapticFeedback.toString(),
        'enableAnimations': settings.enableAnimations.toString(),
        'lastOpenedFolderId': settings.lastOpenedFolderId ?? 'main',
        'lastModified': settings.lastModified.toIso8601String(),
      };
      
      // Save each setting (insert or update)
      for (final entry in settingsToSave.entries) {
        await db.execute('''
          INSERT OR REPLACE INTO ${DatabaseHelper.settingsTable} 
          (${DatabaseHelper.settingKeyColumn}, ${DatabaseHelper.settingValueColumn}, ${DatabaseHelper.settingUpdatedAtColumn}) 
          VALUES (?, ?, ?)
        ''', [entry.key, entry.value, now]);
      }
      
      print('💾 Saved ${settingsToSave.length} settings to database');
      print('💾 Saved settings: $settingsToSave');
    } catch (e) {
      print('❌ Error saving settings to database: $e');
      throw e;
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

      // Save to database
      await _saveSettingsToDatabase(updatedSettings);

      emit(SettingsLoaded(settings: updatedSettings));
      print('✅ Audio format updated and saved: ${event.format.name}');

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

  /// Update last opened folder for navigation persistence
  Future<void> _onUpdateLastOpenedFolder(
      UpdateLastOpenedFolder event,
      Emitter<SettingsState> emit,
      ) async {
    if (state is! SettingsLoaded) return;

    final currentState = state as SettingsLoaded;

    try {
      final updatedSettings = currentState.settings.copyWith(
        lastOpenedFolderId: event.folderId,
      );

      // Save to database
      await _saveSettingsToDatabase(updatedSettings);

      emit(SettingsLoaded(settings: updatedSettings));
      final displayName = event.folderId == 'main' ? 'main screen' : event.folderId;
      print('📁 Last opened folder updated and saved: $displayName');
      print('📁 Database should now contain lastOpenedFolderId: ${event.folderId}');

    } catch (e) {
      print('❌ Error updating last opened folder: $e');
      emit(SettingsError('Failed to update folder navigation'));
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

      emit(SettingsLoaded(settings: defaultSettings));
      print('✅ Settings reset to defaults');

    } catch (e) {
      print('❌ Error resetting settings: $e');
      emit(SettingsError('Failed to reset settings: ${e.toString()}'));
    }
  }

  /// Load only the lastOpenedFolderId for fast router initialization
  static Future<String> loadLastOpenedFolderIdSync() async {
    try {
      final db = await DatabaseHelper.database;
      final result = await db.query(
        DatabaseHelper.settingsTable,
        columns: [DatabaseHelper.settingValueColumn],
        where: '${DatabaseHelper.settingKeyColumn} = ?',
        whereArgs: ['lastOpenedFolderId'],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final rawValue = result.first[DatabaseHelper.settingValueColumn] as String?;
        final processedValue = (rawValue?.isEmpty == true || rawValue == null) ? 'main' : rawValue;
        print('📁 Fast loading lastOpenedFolderId - Raw: "$rawValue", Processed: "$processedValue"');
        return processedValue;
      } else {
        print('📁 No lastOpenedFolderId found, defaulting to main');
        return 'main';
      }
    } catch (e) {
      print('❌ Error fast loading lastOpenedFolderId: $e');
      return 'main'; // Default to main screen if loading fails
    }
  }

  /// Load settings synchronously for router initialization (DEPRECATED - use loadLastOpenedFolderIdSync)
  static Future<AppSettings> loadSettingsSync() async {
    try {
      final db = await DatabaseHelper.database;
      final settingsData = await db.query(DatabaseHelper.settingsTable);
      
      print('📊 Sync loading ${settingsData.length} settings from database');
      
      // Convert list of maps to single settings map
      final settingsMap = <String, String>{};
      for (final row in settingsData) {
        final key = row[DatabaseHelper.settingKeyColumn] as String;
        final value = row[DatabaseHelper.settingValueColumn] as String;
        settingsMap[key] = value;
      }

      print('📊 Sync settings map: $settingsMap');
      
      // Process lastOpenedFolderId
      final rawValue = settingsMap['lastOpenedFolderId'];
      final processedValue = (rawValue?.isEmpty == true || rawValue == null) ? 'main' : rawValue;
      print('📁 Sync loading lastOpenedFolderId - Raw: "$rawValue", Processed: "$processedValue"');
      
      return AppSettings(
        audioFormat: _parseAudioFormatStatic(settingsMap['audioFormat']),
        audioQuality: _parseAudioQualityStatic(settingsMap['audioQuality']),
        sampleRate: int.tryParse(settingsMap['sampleRate'] ?? '') ?? 44100,
        bitRate: int.tryParse(settingsMap['bitRate'] ?? '') ?? 128000,
        enableRealTimeWaveform: _parseBoolStatic(settingsMap['enableRealTimeWaveform'], true),
        enableAmplitudeVisualization: _parseBoolStatic(settingsMap['enableAmplitudeVisualization'], true),
        enableHapticFeedback: _parseBoolStatic(settingsMap['enableHapticFeedback'], true),
        enableAnimations: _parseBoolStatic(settingsMap['enableAnimations'], true),
        lastOpenedFolderId: processedValue,
        lastModified: DateTime.tryParse(settingsMap['lastModified'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      print('❌ Error sync loading settings: $e');
      // Return default settings if loading fails
      return AppSettings.defaultSettings();
    }
  }

  /// Static version of _parseAudioFormat for sync loading
  static AudioFormat _parseAudioFormatStatic(String? value) {
    try {
      final index = int.tryParse(value ?? '');
      if (index != null && index >= 0 && index < AudioFormat.values.length) {
        return AudioFormat.values[index];
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return AudioFormat.m4a; // Default
  }

  /// Static version of _parseAudioQuality for sync loading
  static AudioQuality _parseAudioQualityStatic(String? value) {
    try {
      final index = int.tryParse(value ?? '');
      if (index != null && index >= 0 && index < AudioQuality.values.length) {
        return AudioQuality.values[index];
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return AudioQuality.high; // Default
  }

  /// Static version of _parseBool for sync loading
  static bool _parseBoolStatic(String? value, bool defaultValue) {
    if (value == null) return defaultValue;
    return value.toLowerCase() == 'true';
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
  final String? lastOpenedFolderId; // Track last opened folder for navigation persistence
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
    this.lastOpenedFolderId,
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
      lastOpenedFolderId: 'main', // Default to main screen
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
      lastOpenedFolderId: json['lastOpenedFolderId'],
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
      'lastOpenedFolderId': lastOpenedFolderId,
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
    String? lastOpenedFolderId,
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
      lastOpenedFolderId: lastOpenedFolderId ?? this.lastOpenedFolderId,
      lastModified: lastModified ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    audioFormat,
    audioQuality,
    sampleRate,
    bitRate,
    enableRealTimeWaveform,
    enableAmplitudeVisualization,
    enableHapticFeedback,
    enableAnimations,
    lastOpenedFolderId,
    lastModified,
  ];

  @override
  String toString() => 'AppSettings(format: ${audioFormat.name}, quality: ${audioQuality.name})';
}