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

  /// Toggle favorite status of a single recording
  Future<bool> toggleFavorite(String recordingId) async {
    try {
      print('❤️ REPO DEBUG: Starting toggleFavorite for recording: $recordingId');
      final db = await getDatabaseWithTable();

      // Get current favorite status
      print('🔍 REPO DEBUG: Querying current favorite status...');
      final result = await db.query(
        DatabaseHelper.recordingsTable,
        columns: ['is_favorite', 'name'],
        where: 'id = ?',
        whereArgs: [recordingId],
      );

      if (result.isEmpty) {
        print('❌ REPO DEBUG: Recording not found: $recordingId');
        return false;
      }

      final recordingName = result.first['name'] as String? ?? 'Unknown';
      final currentFavoriteStatus = (result.first['is_favorite'] as int? ?? 0) == 1;
      final newFavoriteStatus = !currentFavoriteStatus;
      
      print('🔍 REPO DEBUG: Recording "$recordingName" current favorite: $currentFavoriteStatus');
      print('🔍 REPO DEBUG: Will change to: $newFavoriteStatus');

      // Update favorite status
      print('🔄 REPO DEBUG: Updating database...');
      final rowsAffected = await db.update(
        DatabaseHelper.recordingsTable,
        {
          'is_favorite': newFavoriteStatus ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [recordingId],
      );

      print('🔄 REPO DEBUG: Rows affected: $rowsAffected');

      if (rowsAffected > 0) {
        // Verify the change was actually made
        print('🔍 REPO DEBUG: Verifying database update...');
        final verifyResult = await db.query(
          DatabaseHelper.recordingsTable,
          columns: ['is_favorite'],
          where: 'id = ?',
          whereArgs: [recordingId],
        );
        
        if (verifyResult.isNotEmpty) {
          final verifiedStatus = (verifyResult.first['is_favorite'] as int? ?? 0) == 1;
          print('✅ REPO DEBUG: Verified database status: $verifiedStatus');
          
          if (verifiedStatus == newFavoriteStatus) {
            print('✅ REPO DEBUG: Successfully toggled favorite status for recording: $recordingId -> $newFavoriteStatus');
            return true;
          } else {
            print('❌ REPO DEBUG: Database verification failed - expected: $newFavoriteStatus, actual: $verifiedStatus');
            return false;
          }
        } else {
          print('❌ REPO DEBUG: Could not verify database update');
          return false;
        }
      } else {
        print('❌ REPO DEBUG: No rows affected - update failed for recording: $recordingId');
        return false;
      }
    } catch (e) {
      print('❌ REPO DEBUG: Exception in toggleFavorite: $e');
      print('❌ REPO DEBUG: Stack trace: ${StackTrace.current}');
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