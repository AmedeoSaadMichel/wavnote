// File: data/repositories/recording_repository_crud.dart
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/recording_entity.dart';
import '../database/database_helper.dart';
import '../models/recording_model.dart';
import 'recording_repository_base.dart';

/// CRUD operations for recording repository
///
/// Handles basic Create, Read, Update, Delete operations
/// for recordings with proper error handling and logging.
class RecordingRepositoryCrud extends RecordingRepositoryBase {

  /// Get all recordings across all folders
  Future<List<RecordingEntity>> getAllRecordings() async {
    try {
      print('🔍 Getting all recordings...');
      final db = await DatabaseHelper.database;

      // First ensure recordings table exists
      await ensureRecordingsTable(db);

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        orderBy: 'created_at DESC',
      );

      print('📊 Database query returned ${maps.length} recordings');

      final recordings = maps.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Loaded ${recordings.length} recordings');
      return recordings;
    } catch (e) {
      print('❌ Error getting all recordings: $e');
      return [];
    }
  }

  /// Get recordings for a specific folder
  /// Special handling for "all_recordings" to include recordings from all folders except "recently_deleted"
  Future<List<RecordingEntity>> getRecordingsByFolder(String folderId) async {
    try {
      print('🔍 Getting recordings for folder: $folderId');
      final db = await DatabaseHelper.database;

      await ensureRecordingsTable(db);

      List<Map<String, dynamic>> maps;

      if (folderId == 'all_recordings') {
        // For "All Recordings", get recordings from all folders except "recently_deleted"
        // Also exclude soft-deleted recordings (is_deleted = 0)
        maps = await db.query(
          DatabaseHelper.recordingsTable,
          where: 'folder_id != ? AND (is_deleted = 0 OR is_deleted IS NULL)',
          whereArgs: ['recently_deleted'],
          orderBy: 'created_at DESC',
        );
        print('📊 All Recordings: Getting recordings from all folders except recently_deleted');
        print('📊 All Recordings: Found ${maps.length} recordings');
        
        // Debug: Let's also check total count in database
        final totalCount = await db.query(
          DatabaseHelper.recordingsTable,
          columns: ['COUNT(*) as count'],
        );
        print('📊 Total recordings in database: ${totalCount.first['count']}');
        
        // Debug: Let's see what folder_ids exist
        final folderIds = await db.query(
          DatabaseHelper.recordingsTable,
          columns: ['DISTINCT folder_id'],
        );
        print('📊 Folder IDs in database: ${folderIds.map((e) => e['folder_id']).toList()}');
      } else if (folderId == 'favourites') {
        // For "Favourites", get favorite recordings from all folders except "recently_deleted"
        // Also exclude soft-deleted recordings
        maps = await db.query(
          DatabaseHelper.recordingsTable,
          where: 'folder_id != ? AND is_favorite = 1 AND (is_deleted = 0 OR is_deleted IS NULL)',
          whereArgs: ['recently_deleted'],
          orderBy: 'created_at DESC',
        );
        print('❤️ Favourites: Getting favorite recordings from all folders except recently_deleted');
      } else if (folderId == 'recently_deleted') {
        // For "Recently Deleted", get only soft-deleted recordings
        maps = await db.query(
          DatabaseHelper.recordingsTable,
          where: 'is_deleted = 1',
          orderBy: 'deleted_at DESC',
        );
        print('🗑️ Recently Deleted: Getting only soft-deleted recordings');
      } else {
        // For other folders, get recordings specifically in that folder (excluding soft-deleted)
        maps = await db.query(
          DatabaseHelper.recordingsTable,
          where: 'folder_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
          whereArgs: [folderId],
          orderBy: 'created_at DESC',
        );
        print('📁 Specific folder: Getting recordings in folder $folderId (excluding soft-deleted)');
      }

      final recordings = maps.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Found ${recordings.length} recordings for folder $folderId');
      return recordings;
    } catch (e) {
      print('❌ Error getting recordings by folder: $e');
      return [];
    }
  }

  /// Get recording by ID
  Future<RecordingEntity?> getRecordingById(String id) async {
    try {
      print('🔍 Looking for recording with ID: $id');
      final db = await DatabaseHelper.database;

      await ensureRecordingsTable(db);

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final recording = RecordingModel.fromDatabase(maps.first).toEntity();
        print('✅ Found recording: ${recording.name}');
        return recording;
      }

      print('❌ Recording not found with ID: $id');
      return null;
    } catch (e) {
      print('❌ Error getting recording by ID: $e');
      return null;
    }
  }

  /// Create a new recording
  Future<RecordingEntity> createRecording(RecordingEntity recording) async {
    try {
      print('📝 Creating recording: ${recording.name}');
      final db = await DatabaseHelper.database;

      await ensureRecordingsTable(db);

      final model = RecordingModel.fromEntity(recording);

      if (!model.isValid) {
        throw Exception('Invalid recording data');
      }

      try {
        await db.insert(
          DatabaseHelper.recordingsTable,
          model.toDatabase(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        // If waveform_data column doesn't exist, retry without it
        if (e.toString().contains('waveform_data')) {
          print('⚠️ waveform_data column not found, retrying without it...');
          final dbMap = model.toDatabase();
          dbMap.remove('waveform_data'); // Remove the problematic field
          
          await db.insert(
            DatabaseHelper.recordingsTable,
            dbMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          rethrow; // Re-throw other errors
        }
      }

      print('✅ Recording created: ${recording.name}');
      return recording;
    } catch (e) {
      print('❌ Error creating recording: $e');
      rethrow;
    }
  }

  /// Update an existing recording
  Future<RecordingEntity> updateRecording(RecordingEntity recording) async {
    try {
      print('📝 Updating recording: ${recording.name}');
      final db = await DatabaseHelper.database;

      await ensureRecordingsTable(db);

      final model = RecordingModel.fromEntity(recording.copyWith(
        updatedAt: DateTime.now(),
      ));

      int rowsAffected;
      try {
        rowsAffected = await db.update(
          DatabaseHelper.recordingsTable,
          model.toDatabase(),
          where: 'id = ?',
          whereArgs: [recording.id],
        );
      } catch (e) {
        // If waveform_data column doesn't exist, retry without it
        if (e.toString().contains('waveform_data')) {
          print('⚠️ waveform_data column not found in update, retrying without it...');
          final dbMap = model.toDatabase();
          dbMap.remove('waveform_data'); // Remove the problematic field
          
          rowsAffected = await db.update(
            DatabaseHelper.recordingsTable,
            dbMap,
            where: 'id = ?',
            whereArgs: [recording.id],
          );
        } else {
          rethrow; // Re-throw other errors
        }
      }

      if (rowsAffected == 0) {
        throw Exception('Recording not found for update: ${recording.id}');
      }

      print('✅ Updated recording: ${recording.name} ($rowsAffected rows affected)');
      return model.toEntity();
    } catch (e) {
      print('❌ Error updating recording: $e');
      rethrow;
    }
  }

  /// Delete a recording by ID
  Future<bool> deleteRecording(String id) async {
    try {
      print('🗑️ Deleting recording with ID: $id');
      final db = await DatabaseHelper.database;

      await ensureRecordingsTable(db);

      final rowsAffected = await db.delete(
        DatabaseHelper.recordingsTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        print('✅ Deleted recording ($rowsAffected rows affected)');
        return true;
      } else {
        print('❌ No rows affected when deleting recording: $id');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting recording: $e');
      return false;
    }
  }

  // ==== SOFT DELETE OPERATIONS ====

  /// Soft delete a recording (move to Recently Deleted folder)
  Future<bool> softDeleteRecording(String id) async {
    try {
      print('🗑️ Soft deleting recording: $id');
      final db = await getDatabaseWithTable();

      // Get the recording first
      final recording = await getRecordingById(id);
      if (recording == null) {
        print('❌ Recording not found for soft delete: $id');
        return false;
      }

      // Apply soft delete using entity method
      final deletedRecording = recording.softDelete();
      
      // Update in database
      final recordingModel = RecordingModel.fromEntity(deletedRecording);
      final rowsAffected = await db.update(
        DatabaseHelper.recordingsTable,
        recordingModel.toDatabase(),
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        print('✅ Recording soft deleted: ${recording.name}');
        return true;
      } else {
        print('❌ Failed to soft delete recording: $id');
        return false;
      }
    } catch (e) {
      print('❌ Error soft deleting recording: $e');
      return false;
    }
  }

  /// Restore a recording from Recently Deleted folder
  Future<bool> restoreRecording(String id) async {
    try {
      print('🔄 Restoring recording: $id');
      final db = await getDatabaseWithTable();

      // Get the recording first
      final recording = await getRecordingById(id);
      if (recording == null) {
        print('❌ Recording not found for restore: $id');
        return false;
      }

      if (!recording.isDeleted) {
        print('❌ Recording is not deleted, cannot restore: $id');
        return false;
      }

      // Apply restore using entity method
      final restoredRecording = recording.restore();
      
      // Update in database
      final recordingModel = RecordingModel.fromEntity(restoredRecording);
      final rowsAffected = await db.update(
        DatabaseHelper.recordingsTable,
        recordingModel.toDatabase(),
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        print('✅ Recording restored: ${recording.name}');
        return true;
      } else {
        print('❌ Failed to restore recording: $id');
        return false;
      }
    } catch (e) {
      print('❌ Error restoring recording: $e');
      return false;
    }
  }

  /// Permanently delete a recording (hard delete from database)
  Future<bool> permanentlyDeleteRecording(String id) async {
    try {
      print('💀 Permanently deleting recording: $id');
      final db = await getDatabaseWithTable();

      // Get the recording first for file cleanup
      final recording = await getRecordingById(id);
      if (recording != null) {
        print('🗑️ Deleting file: ${recording.filePath}');
        
        // Delete the actual audio file
        try {
          final file = File(recording.filePath);
          if (await file.exists()) {
            await file.delete();
            print('✅ Audio file deleted: ${recording.filePath}');
          }
        } catch (fileError) {
          print('⚠️ Could not delete audio file: $fileError');
          // Continue with database deletion even if file deletion fails
        }
      }

      // Delete from database (hard delete)
      final rowsAffected = await db.delete(
        DatabaseHelper.recordingsTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        print('✅ Recording permanently deleted from database: $id');
        return true;
      } else {
        print('❌ Failed to permanently delete recording: $id');
        return false;
      }
    } catch (e) {
      print('❌ Error permanently deleting recording: $e');
      return false;
    }
  }

  /// Get recordings that should be auto-deleted (older than 15 days in Recently Deleted)
  Future<List<RecordingEntity>> getExpiredDeletedRecordings() async {
    try {
      print('🕒 Getting expired deleted recordings...');
      final db = await getDatabaseWithTable();

      // Get recordings deleted more than 15 days ago
      final fifteenDaysAgo = DateTime.now().subtract(const Duration(days: 15));
      
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'is_deleted = ? AND deleted_at < ?',
        whereArgs: [1, fifteenDaysAgo.toIso8601String()],
        orderBy: 'deleted_at ASC',
      );

      final recordings = maps.map((map) => RecordingModel.fromDatabase(map).toEntity()).toList();
      print('📊 Found ${recordings.length} expired recordings');
      
      return recordings;
    } catch (e) {
      print('❌ Error getting expired recordings: $e');
      return [];
    }
  }

  /// Clean up expired recordings (auto-delete after 15 days)
  Future<int> cleanupExpiredRecordings() async {
    try {
      print('🧹 Cleaning up expired recordings...');
      
      // Get expired recordings
      final expiredRecordings = await getExpiredDeletedRecordings();
      
      int deletedCount = 0;
      for (final recording in expiredRecordings) {
        if (await permanentlyDeleteRecording(recording.id)) {
          deletedCount++;
        }
      }

      print('✅ Cleaned up $deletedCount expired recordings');
      return deletedCount;
    } catch (e) {
      print('❌ Error during cleanup: $e');
      return 0;
    }
  }
}