// File: domain/repositories/i_settings_repository.dart
//
// Settings Repository Interface - Domain Layer
// =============================================
//
// Defines the contract for settings persistence operations.
// Keeps the domain layer independent of specific storage implementations.

/// Repository interface for application settings and preferences
abstract class ISettingsRepository {
  /// Load all settings as key-value pairs
  Future<Map<String, String>> loadAllSettings();

  /// Load a specific setting by key
  Future<String?> loadSetting(String key);

  /// Save a single setting
  Future<void> saveSetting(String key, String value);

  /// Save multiple settings at once
  Future<void> saveSettings(Map<String, String> settings);

  /// Clear all settings (reset to empty)
  Future<void> clearAllSettings();

  /// Check if a setting exists
  Future<bool> hasSetting(String key);

  /// Delete a specific setting
  Future<void> deleteSetting(String key);
}
