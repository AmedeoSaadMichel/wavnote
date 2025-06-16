// File: data/repositories/recording_repository_bulk.dart
import '../database/database_helper.dart';
import 'recording_repository_base.dart';

/// Bulk operations for recording repository
///
/// Handles operations that affect multiple recordings
/// using database transactions for consistency.
class RecordingRepositoryBulk extends RecordingRepositoryBase {

  /// Move multiple recordings to a different folder
  Future<bool> moveRecordingsToFolder(
      List<String> recordingIds,
      String folderId,
      ) async {
    try {
      print('📁 Moving ${recordingIds.length} recordings to folder: $folderId');
      final db = await getDatabaseWithTable();

      await db.transaction((txn) async {
        for (final recordingId in recordingIds) {
          await txn.update(
            DatabaseHelper.recordingsTable,
            {
              'folder_id': folderId,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [recordingId],
          );
        }
      });

      print('✅ Moved ${recordingIds.length} recordings to folder $folderId');
      return true;
    } catch (e) {
      print('❌ Error moving recordings: $e');
      return false;
    }
  }

  /// Delete multiple recordings
  Future<bool> deleteRecordings(List<String> recordingIds) async {
    try {
      print('🗑️ Deleting ${recordingIds.length} recordings');
      final db = await getDatabaseWithTable();

      await db.transaction((txn) async {
        for (final recordingId in recordingIds) {
          await txn.delete(
            DatabaseHelper.recordingsTable,
            where: 'id = ?',
            whereArgs: [recordingId],
          );
        }
      });

      print('✅ Deleted ${recordingIds.length} recordings');
      return true;
    } catch (e) {
      print('❌ Error deleting recordings: $e');
      return false;
    }
  }

  /// Mark multiple recordings as favorite/unfavorite
  Future<bool> updateRecordingsFavoriteStatus(
      List<String> recordingIds,
      bool isFavorite,
      ) async {
    try {
      final db = await getDatabaseWithTable();

      await db.transaction((txn) async {
        for (final recordingId in recordingIds) {
          await txn.update(
            DatabaseHelper.recordingsTable,
            {
              'is_favorite': isFavorite ? 1 : 0,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [recordingId],
          );
        }
      });

      print('✅ Updated favorite status for ${recordingIds.length} recordings');
      return true;
    } catch (e) {
      print('❌ Error updating favorite status: $e');
      return false;
    }
  }

  /// Add tags to multiple recordings
  Future<bool> addTagsToRecordings(
      List<String> recordingIds,
      List<String> tags,
      ) async {
    try {
      final db = await getDatabaseWithTable();

      await db.transaction((txn) async {
        for (final recordingId in recordingIds) {
          // Get current tags
          final result = await txn.query(
            DatabaseHelper.recordingsTable,
            columns: ['tags'],
            where: 'id = ?',
            whereArgs: [recordingId],
          );

          if (result.isNotEmpty) {
            final currentTagsString = result.first['tags'] as String? ?? '';
            final currentTags = currentTagsString.isNotEmpty
                ? currentTagsString.split(',')
                : <String>[];

            // Add new tags if not already present
            final updatedTags = {...currentTags, ...tags}.toList();

            await txn.update(
              DatabaseHelper.recordingsTable,
              {
                'tags': updatedTags.join(','),
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [recordingId],
            );
          }
        }
      });

      print('✅ Added tags to ${recordingIds.length} recordings');
      return true;
    } catch (e) {
      print('❌ Error adding tags: $e');
      return false;
    }
  }

  /// Remove tags from multiple recordings
  Future<bool> removeTagsFromRecordings(
      List<String> recordingIds,
      List<String> tags,
      ) async {
    try {
      final db = await getDatabaseWithTable();

      await db.transaction((txn) async {
        for (final recordingId in recordingIds) {
          // Get current tags
          final result = await txn.query(
            DatabaseHelper.recordingsTable,
            columns: ['tags'],
            where: 'id = ?',
            whereArgs: [recordingId],
          );

          if (result.isNotEmpty) {
            final currentTagsString = result.first['tags'] as String? ?? '';
            final currentTags = currentTagsString.isNotEmpty
                ? currentTagsString.split(',')
                : <String>[];

            // Remove specified tags
            final updatedTags = currentTags
                .where((tag) => !tags.contains(tag))
                .toList();

            await txn.update(
              DatabaseHelper.recordingsTable,
              {
                'tags': updatedTags.join(','),
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [recordingId],
            );
          }
        }
      });

      print('✅ Removed tags from ${recordingIds.length} recordings');
      return true;
    } catch (e) {
      print('❌ Error removing tags: $e');
      return false;
    }
  }

  /// Update multiple recordings with same data
  Future<bool> bulkUpdateRecordings(
      List<String> recordingIds,
      Map<String, dynamic> updates,
      ) async {
    try {
      final db = await getDatabaseWithTable();

      // Add updated timestamp
      final finalUpdates = {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await db.transaction((txn) async {
        for (final recordingId in recordingIds) {
          await txn.update(
            DatabaseHelper.recordingsTable,
            finalUpdates,
            where: 'id = ?',
            whereArgs: [recordingId],
          );
        }
      });

      print('✅ Bulk updated ${recordingIds.length} recordings');
      return true;
    } catch (e) {
      print('❌ Error in bulk update: $e');
      return false;
    }
  }

  /// Copy recordings to another folder (duplicate)
  Future<bool> copyRecordingsToFolder(
      List<String> recordingIds,
      String targetFolderId,
      ) async {
    try {
      final db = await getDatabaseWithTable();

      await db.transaction((txn) async {
        for (final recordingId in recordingIds) {
          // Get original recording
          final result = await txn.query(
            DatabaseHelper.recordingsTable,
            where: 'id = ?',
            whereArgs: [recordingId],
          );

          if (result.isNotEmpty) {
            final original = result.first;
            final newId = DateTime.now().millisecondsSinceEpoch.toString();

            // Create copy with new ID and folder
            final copy = Map<String, dynamic>.from(original);
            copy['id'] = newId;
            copy['folder_id'] = targetFolderId;
            copy['name'] = '${copy['name']} (Copy)';
            copy['created_at'] = DateTime.now().toIso8601String();
            copy['updated_at'] = DateTime.now().toIso8601String();

            await txn.insert(
              DatabaseHelper.recordingsTable,
              copy,
            );
          }
        }
      });

      print('✅ Copied ${recordingIds.length} recordings to folder $targetFolderId');
      return true;
    } catch (e) {
      print('❌ Error copying recordings: $e');
      return false;
    }
  }
}