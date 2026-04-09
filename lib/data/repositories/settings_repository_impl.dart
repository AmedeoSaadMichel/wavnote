// File: data/repositories/settings_repository_impl.dart
//
// Settings Repository Implementation - Data Layer
// ================================================
//
// SQLite implementation of ISettingsRepository.
// Wraps DatabaseHelper to provide clean repository pattern.

import '../../domain/repositories/i_settings_repository.dart';
import '../database/database_helper.dart';

/// SQLite implementation of settings repository
class SettingsRepositoryImpl implements ISettingsRepository {
  @override
  Future<Map<String, String>> loadAllSettings() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.settingsTable,
    );

    return {
      for (var map in maps)
        map[DatabaseHelper.settingKeyColumn] as String:
            map[DatabaseHelper.settingValueColumn] as String,
    };
  }

  @override
  Future<String?> loadSetting(String key) async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.settingsTable,
      columns: [DatabaseHelper.settingValueColumn],
      where: '${DatabaseHelper.settingKeyColumn} = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first[DatabaseHelper.settingValueColumn] as String?;
    }
    return null;
  }

  @override
  Future<void> saveSetting(String key, String value) async {
    final db = await DatabaseHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.execute(
      '''
      INSERT OR REPLACE INTO ${DatabaseHelper.settingsTable}
      (${DatabaseHelper.settingKeyColumn}, ${DatabaseHelper.settingValueColumn}, ${DatabaseHelper.settingUpdatedAtColumn})
      VALUES (?, ?, ?)
    ''',
      [key, value, now],
    );
  }

  @override
  Future<void> saveSettings(Map<String, String> settings) async {
    final db = await DatabaseHelper.database;
    final now = DateTime.now().toIso8601String();

    // Batch insert for performance
    final batch = db.batch();
    for (final entry in settings.entries) {
      batch.execute(
        '''
        INSERT OR REPLACE INTO ${DatabaseHelper.settingsTable}
        (${DatabaseHelper.settingKeyColumn}, ${DatabaseHelper.settingValueColumn}, ${DatabaseHelper.settingUpdatedAtColumn})
        VALUES (?, ?, ?)
      ''',
        [entry.key, entry.value, now],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> clearAllSettings() async {
    final db = await DatabaseHelper.database;
    await db.delete(DatabaseHelper.settingsTable);
  }

  @override
  Future<bool> hasSetting(String key) async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.settingsTable,
      columns: [DatabaseHelper.settingKeyColumn],
      where: '${DatabaseHelper.settingKeyColumn} = ?',
      whereArgs: [key],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  @override
  Future<void> deleteSetting(String key) async {
    final db = await DatabaseHelper.database;
    await db.delete(
      DatabaseHelper.settingsTable,
      where: '${DatabaseHelper.settingKeyColumn} = ?',
      whereArgs: [key],
    );
  }
}
