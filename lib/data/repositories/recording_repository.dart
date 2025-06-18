// File: data/repositories/recording_repository.dart
import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_recording_repository.dart';
import '../../core/enums/audio_format.dart';
import 'recording_repository_crud.dart';
import 'recording_repository_search.dart';
import 'recording_repository_bulk.dart';
import 'recording_repository_stats.dart';
import 'recording_repository_utils.dart';

/// Main SQLite implementation of recording repository
///
/// Delegates operations to specialized service classes to maintain
/// single responsibility and keep file sizes manageable.
class RecordingRepository implements IRecordingRepository {
  late final RecordingRepositoryCrud _crudOps;
  late final RecordingRepositorySearch _searchOps;
  late final RecordingRepositoryBulk _bulkOps;
  late final RecordingRepositoryStats _statsOps;
  late final RecordingRepositoryUtils _utilsOps;

  RecordingRepository() {
    _crudOps = RecordingRepositoryCrud();
    _searchOps = RecordingRepositorySearch();
    _bulkOps = RecordingRepositoryBulk();
    _statsOps = RecordingRepositoryStats();
    _utilsOps = RecordingRepositoryUtils();
  }

  // ==== RECORDING CRUD OPERATIONS ====

  @override
  Future<List<RecordingEntity>> getAllRecordings() async {
    return _crudOps.getAllRecordings();
  }

  @override
  Future<List<RecordingEntity>> getRecordingsByFolder(String folderId) async {
    return _crudOps.getRecordingsByFolder(folderId);
  }

  @override
  Future<RecordingEntity?> getRecordingById(String id) async {
    return _crudOps.getRecordingById(id);
  }

  @override
  Future<RecordingEntity> createRecording(RecordingEntity recording) async {
    return _crudOps.createRecording(recording);
  }

  @override
  Future<RecordingEntity> updateRecording(RecordingEntity recording) async {
    return _crudOps.updateRecording(recording);
  }

  @override
  Future<bool> deleteRecording(String id) async {
    return _crudOps.deleteRecording(id);
  }

  // ==== SEARCH & FILTER OPERATIONS ====

  @override
  Future<List<RecordingEntity>> searchRecordings(String query) async {
    return _searchOps.searchRecordings(query);
  }

  @override
  Future<List<RecordingEntity>> getRecordingsByFormat(AudioFormat format) async {
    return _searchOps.getRecordingsByFormat(format);
  }

  @override
  Future<List<RecordingEntity>> getFavoriteRecordings() async {
    return _searchOps.getFavoriteRecordings();
  }

  @override
  Future<List<RecordingEntity>> getRecordingsByDateRange(
      DateTime startDate,
      DateTime endDate,
      ) async {
    return _searchOps.getRecordingsByDateRange(startDate, endDate);
  }

  @override
  Future<List<RecordingEntity>> getRecordingsByDurationRange(
      Duration minDuration,
      Duration maxDuration,
      ) async {
    return _searchOps.getRecordingsByDurationRange(minDuration, maxDuration);
  }

  @override
  Future<List<RecordingEntity>> getRecordingsSorted(
      RecordingSortCriteria criteria,
      ) async {
    return _searchOps.getRecordingsSorted(criteria);
  }

  // ==== BULK OPERATIONS ====

  @override
  Future<bool> moveRecordingsToFolder(
      List<String> recordingIds,
      String folderId,
      ) async {
    return _bulkOps.moveRecordingsToFolder(recordingIds, folderId);
  }

  @override
  Future<bool> deleteRecordings(List<String> recordingIds) async {
    return _bulkOps.deleteRecordings(recordingIds);
  }

  @override
  Future<bool> updateRecordingsFavoriteStatus(
      List<String> recordingIds,
      bool isFavorite,
      ) async {
    return _bulkOps.updateRecordingsFavoriteStatus(recordingIds, isFavorite);
  }

  @override
  Future<bool> addTagsToRecordings(
      List<String> recordingIds,
      List<String> tags,
      ) async {
    return _bulkOps.addTagsToRecordings(recordingIds, tags);
  }

  // ==== STATISTICS OPERATIONS ====

  @override
  Future<int> getRecordingCountByFolder(String folderId) async {
    return _statsOps.getRecordingCountByFolder(folderId);
  }

  @override
  Future<Duration> getTotalDurationByFolder(String folderId) async {
    return _statsOps.getTotalDurationByFolder(folderId);
  }

  @override
  Future<int> getTotalFileSizeByFolder(String folderId) async {
    return _statsOps.getTotalFileSizeByFolder(folderId);
  }

  @override
  Future<Map<AudioFormat, int>> getRecordingCountsByFormat() async {
    return _statsOps.getRecordingCountsByFormat();
  }

  @override
  Future<Map<DateTime, int>> getRecordingCountsByDate(
      DateTime startDate,
      DateTime endDate,
      ) async {
    return _statsOps.getRecordingCountsByDate(startDate, endDate);
  }

  // ==== MAINTENANCE OPERATIONS ====

  @override
  Future<List<String>> getOrphanedRecordings() async {
    return _utilsOps.getOrphanedRecordings();
  }

  @override
  Future<int> cleanupOrphanedRecordings() async {
    return _utilsOps.cleanupOrphanedRecordings();
  }

  @override
  Future<bool> rebuildIndices() async {
    return _utilsOps.rebuildIndices();
  }

  @override
  Future<List<String>> validateRecordingIntegrity() async {
    return _utilsOps.validateRecordingIntegrity();
  }

  // ==== BACKUP & EXPORT OPERATIONS ====

  @override
  Future<Map<String, dynamic>> exportRecordings() async {
    return _utilsOps.exportRecordings();
  }

  @override
  Future<bool> importRecordings(Map<String, dynamic> data) async {
    return _utilsOps.importRecordings(data);
  }

  @override
  Future<bool> clearAllRecordings() async {
    return _utilsOps.clearAllRecordings();
  }

  @override
  Future<List<RecordingEntity>> getRecordingsForBackup() async {
    return _utilsOps.getRecordingsForBackup();
  }
}