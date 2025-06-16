// File: data/repositories/recording_repository_base.dart
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

/// Base class for recording repository operations
///
/// Provides shared functionality like database table creation
/// and common utilities used across all repository classes.
abstract class RecordingRepositoryBase {

  /// Ensure recordings table exists in database
  Future<void> ensureRecordingsTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseHelper.recordingsTable} (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          file_path TEXT NOT NULL,
          folder_id TEXT NOT NULL,
          format_index INTEGER NOT NULL,
          duration_seconds INTEGER NOT NULL,
          file_size INTEGER NOT NULL,
          sample_rate INTEGER NOT NULL,
          latitude REAL,
          longitude REAL,
          location_name TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          is_favorite INTEGER DEFAULT 0,
          tags TEXT
        )
      ''');

      // Create indices for better performance
      await _createIndices(db);

    } catch (e) {
      print('❌ Error ensuring recordings table: $e');
      rethrow;
    }
  }

  /// Create database indices for better performance
  Future<void> _createIndices(Database db) async {
    try {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_recording_folder 
        ON ${DatabaseHelper.recordingsTable}(folder_id)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_recording_name 
        ON ${DatabaseHelper.recordingsTable}(name)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_recording_created 
        ON ${DatabaseHelper.recordingsTable}(created_at)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_recording_format 
        ON ${DatabaseHelper.recordingsTable}(format_index)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_recording_favorite 
        ON ${DatabaseHelper.recordingsTable}(is_favorite)
      ''');

    } catch (e) {
      print('⚠️ Warning: Could not create some indices: $e');
      // Don't rethrow as indices are optional for functionality
    }
  }

  /// Drop all recording indices
  Future<void> dropRecordingIndices(Database db) async {
    try {
      await db.execute('DROP INDEX IF EXISTS idx_recording_folder');
      await db.execute('DROP INDEX IF EXISTS idx_recording_name');
      await db.execute('DROP INDEX IF EXISTS idx_recording_created');
      await db.execute('DROP INDEX IF EXISTS idx_recording_format');
      await db.execute('DROP INDEX IF EXISTS idx_recording_favorite');

      print('✅ Dropped recording indices');
    } catch (e) {
      print('❌ Error dropping indices: $e');
      rethrow;
    }
  }

  /// Rebuild all recording indices
  Future<void> rebuildRecordingIndices(Database db) async {
    try {
      await dropRecordingIndices(db);
      await _createIndices(db);
      print('✅ Rebuilt recording indices');
    } catch (e) {
      print('❌ Error rebuilding indices: $e');
      rethrow;
    }
  }

  /// Get database instance with table ensured
  Future<Database> getDatabaseWithTable() async {
    final db = await DatabaseHelper.database;
    await ensureRecordingsTable(db);
    return db;
  }
}