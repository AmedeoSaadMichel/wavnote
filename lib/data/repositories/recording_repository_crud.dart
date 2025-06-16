// File: data/repositories/recording_repository_crud.dart
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
  Future<List<RecordingEntity>> getRecordingsByFolder(String folderId) async {
    try {
      print('🔍 Getting recordings for folder: $folderId');
      final db = await DatabaseHelper.database;

      await ensureRecordingsTable(db);

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'folder_id = ?',
        whereArgs: [folderId],
        orderBy: 'created_at DESC',
      );

      final recordings = maps.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Found ${recordings.length} recordings in folder $folderId');
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

      await db.insert(
        DatabaseHelper.recordingsTable,
        model.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

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

      final rowsAffected = await db.update(
        DatabaseHelper.recordingsTable,
        model.toDatabase(),
        where: 'id = ?',
        whereArgs: [recording.id],
      );

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
}