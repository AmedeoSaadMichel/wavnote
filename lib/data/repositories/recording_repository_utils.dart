// File: data/repositories/recording_repository_utils.dart
import '../../domain/entities/recording_entity.dart';
import '../database/database_helper.dart';
import '../models/recording_model.dart';
import 'recording_repository_base.dart';

/// Utility operations for recording repository
///
/// Handles maintenance, backup, export/import, and cleanup
/// operations for recordings with comprehensive error handling.
class RecordingRepositoryUtils extends RecordingRepositoryBase {

  /// Verify recording files exist on disk
  Future<List<String>> getOrphanedRecordings() async {
    try {
      final db = await getDatabaseWithTable();

      final recordings = await db.query(DatabaseHelper.recordingsTable);
      final orphanedIds = <String>[];

      for (final recordingMap in recordings) {
        final recording = RecordingModel.fromDatabase(recordingMap).toEntity();

        // Here you would check if the file exists on disk
        // For now, we'll implement a basic check
        // In a real implementation, you'd use File(recording.filePath).exists()
        print('📁 Checking file: ${recording.filePath}');

        // TODO: Add actual file existence check
        // if (!await File(recording.filePath).exists()) {
        //   orphanedIds.add(recording.id);
        // }
      }

      print('✅ Found ${orphanedIds.length} orphaned recordings');
      return orphanedIds;
    } catch (e) {
      print('❌ Error getting orphaned recordings: $e');
      return [];
    }
  }

  /// Clean up orphaned recordings (database entries without files)
  Future<int> cleanupOrphanedRecordings() async {
    try {
      final orphanedIds = await getOrphanedRecordings();

      if (orphanedIds.isNotEmpty) {
        final db = await getDatabaseWithTable();

        await db.transaction((txn) async {
          for (final id in orphanedIds) {
            await txn.delete(
              DatabaseHelper.recordingsTable,
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        });
      }

      print('✅ Cleaned up ${orphanedIds.length} orphaned recordings');
      return orphanedIds.length;
    } catch (e) {
      print('❌ Error cleaning up orphaned recordings: $e');
      return 0;
    }
  }

  /// Rebuild recording indices for performance
  Future<bool> rebuildIndices() async {
    try {
      final db = await getDatabaseWithTable();
      await rebuildRecordingIndices(db);
      return true;
    } catch (e) {
      print('❌ Error rebuilding indices: $e');
      return false;
    }
  }

  /// Validate all recording data integrity
  Future<List<String>> validateRecordingIntegrity() async {
    try {
      final db = await getDatabaseWithTable();
      final recordings = await db.query(DatabaseHelper.recordingsTable);
      final issues = <String>[];

      for (final recordingMap in recordings) {
        try {
          final model = RecordingModel.fromDatabase(recordingMap);
          if (!model.isValid) {
            issues.add('Invalid recording data: ${recordingMap['id']}');
          }
        } catch (e) {
          issues.add('Corrupted recording data: ${recordingMap['id']} - $e');
        }
      }

      print('✅ Validated recordings, found ${issues.length} issues');
      return issues;
    } catch (e) {
      print('❌ Error validating recording integrity: $e');
      return [];
    }
  }

  /// Export recordings metadata to JSON
  Future<Map<String, dynamic>> exportRecordings() async {
    try {
      final db = await getDatabaseWithTable();
      final recordings = await db.query(DatabaseHelper.recordingsTable);

      final exportData = recordings.map((recordingMap) {
        final model = RecordingModel.fromDatabase(recordingMap);
        return model.toJson();
      }).toList();

      final result = {
        'version': 1,
        'export_date': DateTime.now().toIso8601String(),
        'app_name': 'WavNote',
        'total_recordings': recordings.length,
        'recordings': exportData,
      };

      print('✅ Exported ${recordings.length} recordings');
      return result;
    } catch (e) {
      print('❌ Error exporting recordings: $e');
      return {};
    }
  }

  /// Import recordings metadata from JSON
  Future<bool> importRecordings(Map<String, dynamic> data) async {
    try {
      final recordingsData = data['recordings'] as List<dynamic>?;
      if (recordingsData == null) {
        print('❌ No recordings data found in import');
        return false;
      }

      final db = await getDatabaseWithTable();
      int importedCount = 0;

      await db.transaction((txn) async {
        for (final recordingData in recordingsData) {
          try {
            final model = RecordingModel.fromJson(recordingData);
            final entity = model.toEntity();

            // Check if recording already exists
            final existing = await txn.query(
              DatabaseHelper.recordingsTable,
              where: 'id = ?',
              whereArgs: [entity.id],
            );

            if (existing.isEmpty) {
              await txn.insert(
                DatabaseHelper.recordingsTable,
                model.toDatabase(),
              );
              importedCount++;
            } else {
              print('⚠️ Skipping duplicate recording: ${entity.id}');
            }
          } catch (e) {
            print('⚠️ Error importing individual recording: $e');
          }
        }
      });

      print('✅ Imported $importedCount recordings');
      return importedCount > 0;
    } catch (e) {
      print('❌ Error importing recordings: $e');
      return false;
    }
  }

  /// Clear all recordings (for testing/reset)
  Future<bool> clearAllRecordings() async {
    try {
      final db = await getDatabaseWithTable();

      final countBefore = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseHelper.recordingsTable}',
      );
      final before = (countBefore.first['count'] as int?) ?? 0;

      await db.delete(DatabaseHelper.recordingsTable);

      print('🧹 Cleared $before recordings from database');
      return true;
    } catch (e) {
      print('❌ Error clearing recordings: $e');
      return false;
    }
  }

  /// Get recordings that need to be backed up
  Future<List<RecordingEntity>> getRecordingsForBackup() async {
    try {
      final db = await getDatabaseWithTable();

      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

      final recordings = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'updated_at IS NULL OR updated_at >= ?',
        whereArgs: [cutoffDate.toIso8601String()],
        orderBy: 'created_at DESC',
      );

      final entities = recordings.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Found ${entities.length} recordings for backup');
      return entities;
    } catch (e) {
      print('❌ Error getting recordings for backup: $e');
      return [];
    }
  }

  /// Optimize database (vacuum and analyze)
  Future<bool> optimizeDatabase() async {
    try {
      final db = await getDatabaseWithTable();

      await db.execute('VACUUM');
      await db.execute('ANALYZE');

      print('✅ Database optimized');
      return true;
    } catch (e) {
      print('❌ Error optimizing database: $e');
      return false;
    }
  }

  /// Get database size information
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final db = await getDatabaseWithTable();

      // Get table info
      final tableInfo = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='${DatabaseHelper.recordingsTable}'",
      );

      // Get record count
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseHelper.recordingsTable}',
      );
      final recordCount = (countResult.first['count'] as int?) ?? 0;

      // Get index info
      final indexInfo = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='${DatabaseHelper.recordingsTable}'",
      );

      return {
        'table_exists': tableInfo.isNotEmpty,
        'record_count': recordCount,
        'indices_count': indexInfo.length,
        'indices': indexInfo.map((row) => row['name']).toList(),
        'database_path': db.path,
      };
    } catch (e) {
      print('❌ Error getting database info: $e');
      return {};
    }
  }

  /// Remove duplicate recordings based on file path
  Future<int> removeDuplicateRecordings() async {
    try {
      final db = await getDatabaseWithTable();
      int removedCount = 0;

      await db.transaction((txn) async {
        // Find duplicates by file path
        final duplicates = await txn.rawQuery('''
          SELECT file_path, COUNT(*) as count, MIN(created_at) as first_created
          FROM ${DatabaseHelper.recordingsTable}
          GROUP BY file_path
          HAVING COUNT(*) > 1
        ''');

        for (final duplicate in duplicates) {
          final filePath = duplicate['file_path'] as String;
          final firstCreated = duplicate['first_created'] as String;

          // Delete all but the oldest recording for this file path
          final deletedRows = await txn.delete(
            DatabaseHelper.recordingsTable,
            where: 'file_path = ? AND created_at != ?',
            whereArgs: [filePath, firstCreated],
          );

          removedCount += deletedRows;
        }
      });

      print('✅ Removed $removedCount duplicate recordings');
      return removedCount;
    } catch (e) {
      print('❌ Error removing duplicates: $e');
      return 0;
    }
  }
}