// File: data/repositories/recording_repository_stats.dart
import 'package:sqflite/sqflite.dart';
import '../../core/enums/audio_format.dart';
import '../database/database_helper.dart';
import 'recording_repository_base.dart';

/// Statistics operations for recording repository
///
/// Handles all statistical queries and aggregations
/// for recordings with optimized database operations.
class RecordingRepositoryStats extends RecordingRepositoryBase {

  /// Get recording count for a folder
  /// Special handling for "all_recordings" and "recently_deleted" folders
  Future<int> getRecordingCountByFolder(String folderId) async {
    try {
      final db = await getDatabaseWithTable();

      List<Map<String, dynamic>> result;

      if (folderId == 'all_recordings') {
        // For "All Recordings", count recordings from all folders except "recently_deleted"
        // Also exclude soft-deleted recordings
        result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM ${DatabaseHelper.recordingsTable} WHERE folder_id != ? AND (is_deleted = 0 OR is_deleted IS NULL)',
          ['recently_deleted'],
        );
        print('📊 All Recordings count: excluding recently_deleted and soft-deleted');
      } else if (folderId == 'favourites') {
        // For "Favourites", count favorite recordings from all folders except "recently_deleted"
        result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM ${DatabaseHelper.recordingsTable} WHERE folder_id != ? AND is_favorite = 1 AND (is_deleted = 0 OR is_deleted IS NULL)',
          ['recently_deleted'],
        );
        print('❤️ Favourites count: favorite recordings excluding recently_deleted and soft-deleted');
      } else if (folderId == 'recently_deleted') {
        // For "Recently Deleted", count only soft-deleted recordings
        result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM ${DatabaseHelper.recordingsTable} WHERE is_deleted = 1',
        );
        print('🗑️ Recently Deleted count: only soft-deleted recordings');
      } else {
        // For other folders, count recordings specifically in that folder (excluding soft-deleted)
        result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM ${DatabaseHelper.recordingsTable} WHERE folder_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
          [folderId],
        );
        print('📁 Specific folder count: folder $folderId (excluding soft-deleted)');
      }

      final count = Sqflite.firstIntValue(result) ?? 0;
      print('📊 Recording count for folder $folderId: $count');
      return count;
    } catch (e) {
      print('❌ Error getting recording count: $e');
      return 0;
    }
  }

  /// Get total duration for recordings in a folder
  /// Special handling for "all_recordings" and "recently_deleted" folders
  Future<Duration> getTotalDurationByFolder(String folderId) async {
    try {
      final db = await getDatabaseWithTable();

      List<Map<String, dynamic>> result;

      if (folderId == 'all_recordings') {
        // For "All Recordings", sum duration from all folders except "recently_deleted"
        result = await db.rawQuery(
          'SELECT SUM(duration_seconds) as total FROM ${DatabaseHelper.recordingsTable} WHERE folder_id != ? AND (is_deleted = 0 OR is_deleted IS NULL)',
          ['recently_deleted'],
        );
      } else if (folderId == 'favourites') {
        // For "Favourites", sum duration for favorite recordings from all folders except "recently_deleted"
        result = await db.rawQuery(
          'SELECT SUM(duration_seconds) as total FROM ${DatabaseHelper.recordingsTable} WHERE folder_id != ? AND is_favorite = 1 AND (is_deleted = 0 OR is_deleted IS NULL)',
          ['recently_deleted'],
        );
      } else if (folderId == 'recently_deleted') {
        // For "Recently Deleted", sum duration for soft-deleted recordings
        result = await db.rawQuery(
          'SELECT SUM(duration_seconds) as total FROM ${DatabaseHelper.recordingsTable} WHERE is_deleted = 1',
        );
      } else {
        // For other folders, sum duration for recordings in that folder (excluding soft-deleted)
        result = await db.rawQuery(
          'SELECT SUM(duration_seconds) as total FROM ${DatabaseHelper.recordingsTable} WHERE folder_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
          [folderId],
        );
      }

      final totalSeconds = Sqflite.firstIntValue(result) ?? 0;
      return Duration(seconds: totalSeconds);
    } catch (e) {
      print('❌ Error getting total duration: $e');
      return Duration.zero;
    }
  }

  /// Get total file size for recordings in a folder
  /// Special handling for "all_recordings" and "recently_deleted" folders
  Future<int> getTotalFileSizeByFolder(String folderId) async {
    try {
      final db = await getDatabaseWithTable();

      List<Map<String, dynamic>> result;

      if (folderId == 'all_recordings') {
        // For "All Recordings", sum file size from all folders except "recently_deleted"
        result = await db.rawQuery(
          'SELECT SUM(file_size) as total FROM ${DatabaseHelper.recordingsTable} WHERE folder_id != ? AND (is_deleted = 0 OR is_deleted IS NULL)',
          ['recently_deleted'],
        );
      } else if (folderId == 'favourites') {
        // For "Favourites", sum file size for favorite recordings from all folders except "recently_deleted"
        result = await db.rawQuery(
          'SELECT SUM(file_size) as total FROM ${DatabaseHelper.recordingsTable} WHERE folder_id != ? AND is_favorite = 1 AND (is_deleted = 0 OR is_deleted IS NULL)',
          ['recently_deleted'],
        );
      } else if (folderId == 'recently_deleted') {
        // For "Recently Deleted", sum file size for soft-deleted recordings
        result = await db.rawQuery(
          'SELECT SUM(file_size) as total FROM ${DatabaseHelper.recordingsTable} WHERE is_deleted = 1',
        );
      } else {
        // For other folders, sum file size for recordings in that folder (excluding soft-deleted)
        result = await db.rawQuery(
          'SELECT SUM(file_size) as total FROM ${DatabaseHelper.recordingsTable} WHERE folder_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
          [folderId],
        );
      }

      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error getting total file size: $e');
      return 0;
    }
  }

  /// Get recording statistics by format
  Future<Map<AudioFormat, int>> getRecordingCountsByFormat() async {
    try {
      final db = await getDatabaseWithTable();

      final result = await db.rawQuery(
        'SELECT format_index, COUNT(*) as count FROM ${DatabaseHelper.recordingsTable} GROUP BY format_index',
      );

      final Map<AudioFormat, int> counts = {};

      for (final row in result) {
        final formatIndex = row['format_index'] as int;
        final count = row['count'] as int;

        if (formatIndex < AudioFormat.values.length) {
          counts[AudioFormat.values[formatIndex]] = count;
        }
      }

      return counts;
    } catch (e) {
      print('❌ Error getting recording counts by format: $e');
      return {};
    }
  }

  /// Get recording statistics by date
  Future<Map<DateTime, int>> getRecordingCountsByDate(
      DateTime startDate,
      DateTime endDate,
      ) async {
    try {
      final db = await getDatabaseWithTable();

      final result = await db.rawQuery('''
        SELECT DATE(created_at) as date, COUNT(*) as count 
        FROM ${DatabaseHelper.recordingsTable} 
        WHERE created_at BETWEEN ? AND ? 
        GROUP BY DATE(created_at)
        ORDER BY date
      ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

      final Map<DateTime, int> counts = {};

      for (final row in result) {
        final dateString = row['date'] as String;
        final count = row['count'] as int;
        final date = DateTime.parse(dateString);
        counts[date] = count;
      }

      return counts;
    } catch (e) {
      print('❌ Error getting recording counts by date: $e');
      return {};
    }
  }

  /// Get average recording duration by folder
  Future<Duration> getAverageRecordingDuration(String folderId) async {
    try {
      final db = await getDatabaseWithTable();

      final result = await db.rawQuery(
        'SELECT AVG(duration_seconds) as avg FROM ${DatabaseHelper.recordingsTable} WHERE folder_id = ?',
        [folderId],
      );

      final averageSeconds = (result.first['avg'] as num?)?.round() ?? 0;
      return Duration(seconds: averageSeconds);
    } catch (e) {
      print('❌ Error getting average duration: $e');
      return Duration.zero;
    }
  }

  /// Get recording statistics summary
  Future<Map<String, dynamic>> getRecordingStatsSummary() async {
    try {
      final db = await getDatabaseWithTable();

      // Get total counts
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as total, SUM(duration_seconds) as total_duration, SUM(file_size) as total_size FROM ${DatabaseHelper.recordingsTable}',
      );

      final total = Sqflite.firstIntValue(totalResult) ?? 0;
      final totalDuration = Duration(seconds: (totalResult.first['total_duration'] as int?) ?? 0);
      final totalSize = (totalResult.first['total_size'] as int?) ?? 0;

      // Get favorites count
      final favoritesResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseHelper.recordingsTable} WHERE is_favorite = 1',
      );
      final favoritesCount = Sqflite.firstIntValue(favoritesResult) ?? 0;

      // Get format distribution
      final formatCounts = await getRecordingCountsByFormat();

      // Get recent recordings (last 7 days)
      final recentDate = DateTime.now().subtract(const Duration(days: 7));
      final recentResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseHelper.recordingsTable} WHERE created_at >= ?',
        [recentDate.toIso8601String()],
      );
      final recentCount = Sqflite.firstIntValue(recentResult) ?? 0;

      return {
        'total_recordings': total,
        'total_duration_seconds': totalDuration.inSeconds,
        'total_size_bytes': totalSize,
        'favorites_count': favoritesCount,
        'recent_count': recentCount,
        'format_distribution': formatCounts.map((key, value) => MapEntry(key.name, value)),
        'average_size_bytes': total > 0 ? (totalSize / total).round() : 0,
        'average_duration_seconds': total > 0 ? (totalDuration.inSeconds / total).round() : 0,
      };
    } catch (e) {
      print('❌ Error getting recording stats summary: $e');
      return {};
    }
  }

  /// Get folder statistics
  Future<Map<String, dynamic>> getFolderStatistics(String folderId) async {
    try {
      final db = await getDatabaseWithTable();

      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as count,
          SUM(duration_seconds) as total_duration,
          SUM(file_size) as total_size,
          AVG(duration_seconds) as avg_duration,
          AVG(file_size) as avg_size,
          MIN(created_at) as oldest_recording,
          MAX(created_at) as newest_recording
        FROM ${DatabaseHelper.recordingsTable} 
        WHERE folder_id = ?
      ''', [folderId]);

      if (result.isEmpty) {
        return {
          'count': 0,
          'total_duration_seconds': 0,
          'total_size_bytes': 0,
          'average_duration_seconds': 0,
          'average_size_bytes': 0,
        };
      }

      final row = result.first;
      return {
        'count': row['count'] as int,
        'total_duration_seconds': (row['total_duration'] as int?) ?? 0,
        'total_size_bytes': (row['total_size'] as int?) ?? 0,
        'average_duration_seconds': ((row['avg_duration'] as num?)?.round()) ?? 0,
        'average_size_bytes': ((row['avg_size'] as num?)?.round()) ?? 0,
        'oldest_recording': row['oldest_recording'] as String?,
        'newest_recording': row['newest_recording'] as String?,
      };
    } catch (e) {
      print('❌ Error getting folder statistics: $e');
      return {};
    }
  }

  /// Get top tags by usage
  Future<Map<String, int>> getTopTags({int limit = 10}) async {
    try {
      final db = await getDatabaseWithTable();

      // Get all recordings with tags
      final result = await db.query(
        DatabaseHelper.recordingsTable,
        columns: ['tags'],
        where: 'tags IS NOT NULL AND tags != ""',
      );

      final Map<String, int> tagCounts = {};

      for (final row in result) {
        final tagsString = row['tags'] as String?;
        if (tagsString != null && tagsString.isNotEmpty) {
          final tags = tagsString.split(',');
          for (final tag in tags) {
            final trimmedTag = tag.trim();
            if (trimmedTag.isNotEmpty) {
              tagCounts[trimmedTag] = (tagCounts[trimmedTag] ?? 0) + 1;
            }
          }
        }
      }

      // Sort by count and take top N
      final sortedEntries = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Map.fromEntries(sortedEntries.take(limit));
    } catch (e) {
      print('❌ Error getting top tags: $e');
      return {};
    }
  }
}