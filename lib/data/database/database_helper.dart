import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Database helper for managing SQLite database operations
///
/// Handles database creation, migrations, and provides access to database instance.
/// Follows singleton pattern to ensure single database connection.
class DatabaseHelper {
  static Database? _database;
  static const String _databaseName = 'voice_memo.db';
  static const int _databaseVersion = 4;

  // Table names
  static const String foldersTable = 'folders';
  static const String recordingsTable = 'recordings';
  static const String settingsTable = 'settings';

  // Folders table columns
  static const String folderIdColumn = 'id';
  static const String folderNameColumn = 'name';
  static const String folderIconColumn = 'icon_code_point';
  static const String folderColorColumn = 'color_value';
  static const String folderCountColumn = 'recording_count';
  static const String folderTypeColumn = 'type';
  static const String folderIsDeletableColumn = 'is_deletable';
  static const String folderCreatedAtColumn = 'created_at';
  static const String folderUpdatedAtColumn = 'updated_at';

  // Settings table columns
  static const String settingKeyColumn = 'key';
  static const String settingValueColumn = 'value';
  static const String settingUpdatedAtColumn = 'updated_at';

  /// Private constructor for singleton pattern
  DatabaseHelper._();

  /// Get database instance (singleton)
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database with tables and indices
  static Future<Database> _initDatabase() async {
    try {
      // Get the documents directory path
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);

      print('📂 Initializing database at: $path');

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
        onOpen: _onOpen,
      );
    } catch (e) {
      print('❌ Error initializing database: $e');
      rethrow;
    }
  }

  /// Create database tables
  static Future<void> _createDatabase(Database db, int version) async {
    try {
      print('🏗️ Creating database tables...');

      // Create folders table
      await db.execute('''
        CREATE TABLE $foldersTable (
          $folderIdColumn TEXT PRIMARY KEY,
          $folderNameColumn TEXT NOT NULL,
          $folderIconColumn INTEGER NOT NULL,
          $folderColorColumn INTEGER NOT NULL,
          $folderCountColumn INTEGER DEFAULT 0,
          $folderTypeColumn INTEGER NOT NULL,
          $folderIsDeletableColumn INTEGER NOT NULL,
          $folderCreatedAtColumn TEXT NOT NULL,
          $folderUpdatedAtColumn TEXT
        )
      ''');

      // Create settings table
      await db.execute('''
        CREATE TABLE $settingsTable (
          $settingKeyColumn TEXT PRIMARY KEY,
          $settingValueColumn TEXT NOT NULL,
          $settingUpdatedAtColumn TEXT NOT NULL
        )
      ''');

      // Create indices for better performance
      await db.execute('''
        CREATE INDEX idx_folder_name ON $foldersTable($folderNameColumn)
      ''');

      await db.execute('''
        CREATE INDEX idx_folder_type ON $foldersTable($folderTypeColumn)
      ''');

      print('✅ Database tables created successfully');

      // Insert default settings
      await _insertDefaultSettings(db);

    } catch (e) {
      print('❌ Error creating database tables: $e');
      rethrow;
    }
  }

  /// Handle database upgrades (for future versions)
  static Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from version $oldVersion to $newVersion');

    try {
      // Version 2: Add soft delete columns to recordings table
      if (oldVersion < 2) {
        print('🔄 Migrating to version 2: Adding soft delete columns...');
        
        // Add soft delete columns to recordings table
        await db.execute('ALTER TABLE $recordingsTable ADD COLUMN is_deleted INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE $recordingsTable ADD COLUMN deleted_at TEXT');
        await db.execute('ALTER TABLE $recordingsTable ADD COLUMN original_folder_id TEXT');
        
        // Create indices for new columns
        await db.execute('CREATE INDEX idx_recordings_is_deleted ON $recordingsTable(is_deleted)');
        await db.execute('CREATE INDEX idx_recordings_deleted_at ON $recordingsTable(deleted_at)');
        
        print('✅ Successfully migrated to version 2');
      }

      // Version 3: Add waveform_data column to recordings table
      if (oldVersion < 3) {
        print('🔄 Migrating to version 3: Adding waveform_data column...');
        
        // Add waveform_data column to recordings table
        await db.execute('ALTER TABLE $recordingsTable ADD COLUMN waveform_data TEXT');
        
        print('✅ Successfully migrated to version 3');
      }

      // Version 4: Add duration_milliseconds column for precise duration storage
      if (oldVersion < 4) {
        print('🔄 Migrating to version 4: Adding duration_milliseconds column...');
        
        // Add duration_milliseconds column to recordings table
        await db.execute('ALTER TABLE $recordingsTable ADD COLUMN duration_milliseconds INTEGER');
        
        // Migrate existing data: convert seconds to milliseconds
        await db.execute('''
          UPDATE $recordingsTable 
          SET duration_milliseconds = duration_seconds * 1000 
          WHERE duration_milliseconds IS NULL
        ''');
        
        print('✅ Successfully migrated to version 4');
        print('📊 Converted existing duration_seconds to duration_milliseconds');
      }
    } catch (e) {
      print('❌ Error during database migration: $e');
      rethrow;
    }
  }

  /// Called when database is opened
  static Future<void> _onOpen(Database db) async {
    print('📖 Database opened successfully');
  }

  /// Reset database instance (forces reconnection and migration check)
  static Future<void> resetDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    print('🔄 Database instance reset - will reconnect on next access');
  }

  /// Insert default app settings
  static Future<void> _insertDefaultSettings(Database db) async {
    try {
      await db.insert(
        settingsTable,
        {
          settingKeyColumn: 'audio_format',
          settingValueColumn: 'WAV',
          settingUpdatedAtColumn: DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      await db.insert(
        settingsTable,
        {
          settingKeyColumn: 'audio_quality',
          settingValueColumn: '44100',
          settingUpdatedAtColumn: DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      print('✅ Default settings inserted');
    } catch (e) {
      print('⚠️ Error inserting default settings: $e');
    }
  }

  /// Get database info for debugging
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final db = await database;

      // Count folders
      final folderResult = await db.rawQuery('SELECT COUNT(*) as count FROM $foldersTable');
      final folderCount = Sqflite.firstIntValue(folderResult) ?? 0;

      // Count settings
      final settingsResult = await db.rawQuery('SELECT COUNT(*) as count FROM $settingsTable');
      final settingsCount = Sqflite.firstIntValue(settingsResult) ?? 0;

      return {
        'database_path': db.path,
        'database_version': await db.getVersion(),
        'folders_count': folderCount,
        'settings_count': settingsCount,
        'database_size_mb': await _getDatabaseSize(db.path),
      };
    } catch (e) {
      print('❌ Error getting database info: $e');
      return {};
    }
  }

  /// Get database file size in MB
  static Future<double> _getDatabaseSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.length();
        return bytes / (1024 * 1024); // Convert to MB
      }
      return 0.0;
    } catch (e) {
      print('❌ Error getting database size: $e');
      return 0.0;
    }
  }

  /// Close database connection
  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('🔒 Database connection closed');
    }
  }

  /// Delete database (for testing/debugging)
  static Future<void> deleteDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        _database = null;
        print('🗑️ Database deleted');
      }
    } catch (e) {
      print('❌ Error deleting database: $e');
    }
  }

  /// Execute a raw query (for debugging)
  static Future<List<Map<String, Object?>>> rawQuery(String sql) async {
    try {
      final db = await database;
      return await db.rawQuery(sql);
    } catch (e) {
      print('❌ Error executing raw query: $e');
      return [];
    }
  }

  /// Get all table names
  static Future<List<String>> getTableNames() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
      );
      return result.map((row) => row['name'] as String).toList();
    } catch (e) {
      print('❌ Error getting table names: $e');
      return [];
    }
  }

  /// Clear all data from tables (for testing)
  static Future<void> clearAllData() async {
    try {
      final db = await database;

      await db.delete(foldersTable);
      await db.delete(settingsTable);

      // Re-insert default settings
      await _insertDefaultSettings(db);

      print('🧹 All data cleared from database');
    } catch (e) {
      print('❌ Error clearing database data: $e');
    }
  }
}