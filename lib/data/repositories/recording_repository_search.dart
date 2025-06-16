// File: data/repositories/recording_repository_search.dart
import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_recording_repository.dart';
import '../../core/enums/audio_format.dart';
import '../database/database_helper.dart';
import '../models/recording_model.dart';
import 'recording_repository_base.dart';

/// Search and filter operations for recording repository
///
/// Handles all search, filter, and sorting operations
/// for recordings with optimized database queries.
class RecordingRepositorySearch extends RecordingRepositoryBase {

  /// Search recordings by name or location
  Future<List<RecordingEntity>> searchRecordings(String query) async {
    try {
      print('🔍 Searching recordings for: "$query"');
      final db = await getDatabaseWithTable();

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'name LIKE ? OR location_name LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'created_at DESC',
      );

      final recordings = maps.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Found ${recordings.length} recordings matching "$query"');
      return recordings;
    } catch (e) {
      print('❌ Error searching recordings: $e');
      return [];
    }
  }

  /// Get recordings by audio format
  Future<List<RecordingEntity>> getRecordingsByFormat(AudioFormat format) async {
    try {
      final db = await getDatabaseWithTable();

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'format_index = ?',
        whereArgs: [format.index],
        orderBy: 'created_at DESC',
      );

      final recordings = maps.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Found ${recordings.length} recordings in ${format.name} format');
      return recordings;
    } catch (e) {
      print('❌ Error getting recordings by format: $e');
      return [];
    }
  }

  /// Get favorite recordings
  Future<List<RecordingEntity>> getFavoriteRecordings() async {
    try {
      final db = await getDatabaseWithTable();

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'is_favorite = ?',
        whereArgs: [1],
        orderBy: 'created_at DESC',
      );

      final recordings = maps.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Found ${recordings.length} favorite recordings');
      return recordings;
    } catch (e) {
      print('❌ Error getting favorite recordings: $e');
      return [];
    }
  }

  /// Get recordings within date range
  Future<List<RecordingEntity>> getRecordingsByDateRange(
      DateTime startDate,
      DateTime endDate,
      ) async {
    try {
      final db = await getDatabaseWithTable();

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'created_at BETWEEN ? AND ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'created_at DESC',
      );

      final recordings = maps.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Found ${recordings.length} recordings in date range');
      return recordings;
    } catch (e) {
      print('❌ Error getting recordings by date range: $e');
      return [];
    }
  }

  /// Get recordings by duration range
  Future<List<RecordingEntity>> getRecordingsByDurationRange(
      Duration minDuration,
      Duration maxDuration,
      ) async {
    try {
      final db = await getDatabaseWithTable();

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: 'duration_seconds BETWEEN ? AND ?',
        whereArgs: [minDuration.inSeconds, maxDuration.inSeconds],
        orderBy: 'duration_seconds DESC',
      );

      final recordings = maps.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Found ${recordings.length} recordings in duration range');
      return recordings;
    } catch (e) {
      print('❌ Error getting recordings by duration range: $e');
      return [];
    }
  }

  /// Get recordings sorted by criteria
  Future<List<RecordingEntity>> getRecordingsSorted(
      RecordingSortCriteria criteria,
      ) async {
    try {
      final db = await getDatabaseWithTable();

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        orderBy: criteria.sqlOrderBy,
      );

      final recordings = maps.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Found ${recordings.length} recordings sorted by ${criteria.name}');
      return recordings;
    } catch (e) {
      print('❌ Error getting sorted recordings: $e');
      return [];
    }
  }

  /// Get recordings with tags containing any of the provided tags
  Future<List<RecordingEntity>> getRecordingsByTags(List<String> tags) async {
    try {
      final db = await getDatabaseWithTable();

      // Create LIKE conditions for each tag
      final conditions = tags.map((tag) => 'tags LIKE ?').join(' OR ');
      final args = tags.map((tag) => '%$tag%').toList();

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: conditions,
        whereArgs: args,
        orderBy: 'created_at DESC',
      );

      final recordings = maps.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Found ${recordings.length} recordings with tags: ${tags.join(", ")}');
      return recordings;
    } catch (e) {
      print('❌ Error getting recordings by tags: $e');
      return [];
    }
  }

  /// Get recent recordings (last N days)
  Future<List<RecordingEntity>> getRecentRecordings(int days) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      return getRecordingsByDateRange(startDate, DateTime.now());
    } catch (e) {
      print('❌ Error getting recent recordings: $e');
      return [];
    }
  }

  /// Search recordings with advanced filters
  Future<List<RecordingEntity>> searchRecordingsWithFilters({
    String? query,
    AudioFormat? format,
    bool? isFavorite,
    Duration? minDuration,
    Duration? maxDuration,
    List<String>? tags,
    RecordingSortCriteria? sortBy,
  }) async {
    try {
      final db = await getDatabaseWithTable();

      final conditions = <String>[];
      final args = <dynamic>[];

      // Add query condition
      if (query != null && query.isNotEmpty) {
        conditions.add('(name LIKE ? OR location_name LIKE ?)');
        args.addAll(['%$query%', '%$query%']);
      }

      // Add format condition
      if (format != null) {
        conditions.add('format_index = ?');
        args.add(format.index);
      }

      // Add favorite condition
      if (isFavorite != null) {
        conditions.add('is_favorite = ?');
        args.add(isFavorite ? 1 : 0);
      }

      // Add duration conditions
      if (minDuration != null) {
        conditions.add('duration_seconds >= ?');
        args.add(minDuration.inSeconds);
      }

      if (maxDuration != null) {
        conditions.add('duration_seconds <= ?');
        args.add(maxDuration.inSeconds);
      }

      // Add tags condition
      if (tags != null && tags.isNotEmpty) {
        final tagConditions = tags.map((tag) => 'tags LIKE ?').join(' OR ');
        conditions.add('($tagConditions)');
        args.addAll(tags.map((tag) => '%$tag%'));
      }

      // Build final where clause
      final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;

      // Determine order by
      final orderBy = sortBy?.sqlOrderBy ?? 'created_at DESC';

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.recordingsTable,
        where: whereClause,
        whereArgs: args.isNotEmpty ? args : null,
        orderBy: orderBy,
      );

      final recordings = maps.map((map) =>
          RecordingModel.fromDatabase(map).toEntity()).toList();

      print('✅ Advanced search found ${recordings.length} recordings');
      return recordings;
    } catch (e) {
      print('❌ Error in advanced search: $e');
      return [];
    }
  }
}