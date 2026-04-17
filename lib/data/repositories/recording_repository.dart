// File: data/repositories/recording_repository.dart
import 'package:dartz/dartz.dart';
import '../../domain/entities/recording_entity.dart';
import '../../domain/repositories/i_recording_repository.dart';
import '../../core/enums/audio_format.dart';
import '../../core/errors/failures.dart';

import 'recording_repository_crud.dart';
import 'recording_repository_search.dart';
import 'recording_repository_bulk.dart';
import 'recording_repository_stats.dart';
import 'recording_repository_utils.dart';

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

  @override
  Future<List<RecordingEntity>> getAllRecordings() async =>
      _crudOps.getAllRecordings();

  @override
  Future<List<RecordingEntity>> getRecordingsByFolder(String folderId) async =>
      _crudOps.getRecordingsByFolder(folderId);

  @override
  Future<RecordingEntity?> getRecordingById(String id) async =>
      _crudOps.getRecordingById(id);

  @override
  Future<RecordingEntity> createRecording(RecordingEntity recording) async =>
      _crudOps.createRecording(recording);

  @override
  Future<RecordingEntity> updateRecording(RecordingEntity recording) async =>
      _crudOps.updateRecording(recording);

  @override
  Future<Either<Failure, Unit>> deleteRecording(String id) async =>
      _crudOps.deleteRecording(id);

  @override
  Future<Either<Failure, Unit>> softDeleteRecording(String id) async =>
      _crudOps.softDeleteRecording(id);

  @override
  Future<Either<Failure, Unit>> restoreRecording(String id) async =>
      _crudOps.restoreRecording(id);

  @override
  Future<Either<Failure, Unit>> permanentlyDeleteRecording(String id) async =>
      _crudOps.permanentlyDeleteRecording(id);

  @override
  Future<List<RecordingEntity>> getExpiredDeletedRecordings() async =>
      _crudOps.getExpiredDeletedRecordings();

  @override
  Future<int> cleanupExpiredRecordings() async =>
      _crudOps.cleanupExpiredRecordings();

  @override
  Future<List<RecordingEntity>> searchRecordings(String query) async =>
      _searchOps.searchRecordings(query);

  @override
  Future<List<RecordingEntity>> getRecordingsByFormat(
    AudioFormat format,
  ) async => _searchOps.getRecordingsByFormat(format);

  @override
  Future<List<RecordingEntity>> getFavoriteRecordings() async =>
      _searchOps.getFavoriteRecordings();

  @override
  Future<List<RecordingEntity>> getRecordingsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async => _searchOps.getRecordingsByDateRange(startDate, endDate);

  @override
  Future<List<RecordingEntity>> getRecordingsByDurationRange(
    Duration minDuration,
    Duration maxDuration,
  ) async => _searchOps.getRecordingsByDurationRange(minDuration, maxDuration);

  @override
  Future<List<RecordingEntity>> getRecordingsSorted(
    RecordingSortCriteria criteria,
  ) async => _searchOps.getRecordingsSorted(criteria);

  @override
  Future<Either<Failure, Unit>> moveRecordingsToFolder(
    List<String> recordingIds,
    String folderId,
  ) async => _bulkOps.moveRecordingsToFolder(recordingIds, folderId);

  @override
  Future<Either<Failure, Unit>> deleteRecordings(
    List<String> recordingIds,
  ) async => _bulkOps.deleteRecordings(recordingIds);

  @override
  Future<Either<Failure, Unit>> updateRecordingsFavoriteStatus(
    List<String> recordingIds,
    bool isFavorite,
  ) async => _bulkOps.updateRecordingsFavoriteStatus(recordingIds, isFavorite);

  @override
  Future<Either<Failure, Unit>> toggleFavorite(String recordingId) async =>
      _bulkOps.toggleFavorite(recordingId);

  @override
  Future<Either<Failure, Unit>> addTagsToRecordings(
    List<String> recordingIds,
    List<String> tags,
  ) async => _bulkOps.addTagsToRecordings(recordingIds, tags);

  @override
  Future<int> getRecordingCountByFolder(String folderId) async =>
      _statsOps.getRecordingCountByFolder(folderId);

  @override
  Future<Duration> getTotalDurationByFolder(String folderId) async =>
      _statsOps.getTotalDurationByFolder(folderId);

  @override
  Future<int> getTotalFileSizeByFolder(String folderId) async =>
      _statsOps.getTotalFileSizeByFolder(folderId);

  @override
  Future<Map<AudioFormat, int>> getRecordingCountsByFormat() async =>
      _statsOps.getRecordingCountsByFormat();

  @override
  Future<Map<DateTime, int>> getRecordingCountsByDate(
    DateTime startDate,
    DateTime endDate,
  ) async => _statsOps.getRecordingCountsByDate(startDate, endDate);

  @override
  Future<List<String>> getOrphanedRecordings() async =>
      _utilsOps.getOrphanedRecordings();

  @override
  Future<int> cleanupOrphanedRecordings() async =>
      _utilsOps.cleanupOrphanedRecordings();

  @override
  Future<Either<Failure, Unit>> rebuildIndices() async =>
      _utilsOps.rebuildIndices();

  @override
  Future<List<String>> validateRecordingIntegrity() async =>
      _utilsOps.validateRecordingIntegrity();

  @override
  Future<Map<String, dynamic>> exportRecordings() async =>
      _utilsOps.exportRecordings();

  @override
  Future<Either<Failure, Unit>> importRecordings(
    Map<String, dynamic> data,
  ) async => _utilsOps.importRecordings(data);

  @override
  Future<Either<Failure, Unit>> clearAllRecordings() async =>
      _utilsOps.clearAllRecordings();

  @override
  Future<List<RecordingEntity>> getRecordingsForBackup() async =>
      _utilsOps.getRecordingsForBackup();
}
