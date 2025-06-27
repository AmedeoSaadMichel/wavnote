// File: data/repositories/recording_repository.dart
// 
// Recording Repository - Data Layer
// =================================
//
// Primary implementation of the recording repository interface using SQLite
// as the persistent storage mechanism. This repository serves as the main
// data access layer for all recording-related operations in the WavNote app.
//
// Architecture Pattern:
// - Implements Repository pattern from Clean Architecture
// - Uses composition to delegate to specialized operation classes
// - Maintains single responsibility by splitting concerns across files
// - Provides a unified interface while keeping implementation modular
//
// Key Responsibilities:
// - Provide data access interface implementation for domain layer
// - Coordinate between specialized operation classes
// - Maintain data consistency and integrity
// - Handle database transactions and error management
// - Abstract SQLite implementation details from business logic
//
// Specialized Operation Classes:
// - RecordingRepositoryCrud: Basic CRUD operations (Create, Read, Update, Delete)
// - RecordingRepositorySearch: Advanced search and filtering capabilities
// - RecordingRepositoryBulk: Bulk operations for multiple recordings
// - RecordingRepositoryStats: Statistics and analytics operations
// - RecordingRepositoryUtils: Utility operations and data maintenance
//
// Database Design:
// - Uses SQLite for local storage with high performance
// - Optimized queries with proper indexing
// - Supports complex filtering and search operations
// - Maintains referential integrity between recordings and folders
// - Includes soft delete functionality with 15-day retention
//
// Performance Features:
// - Connection pooling for optimal database access
// - Batch operations for bulk data manipulation
// - Efficient query optimization and indexing
// - Memory-conscious data loading strategies
// - Background cleanup of expired data

import '../../domain/entities/recording_entity.dart';      // Recording business entity
import '../../domain/repositories/i_recording_repository.dart'; // Repository interface
import '../../core/enums/audio_format.dart';               // Audio format definitions

// Specialized operation classes for modular design
import 'recording_repository_crud.dart';   // CRUD operations
import 'recording_repository_search.dart'; // Search and filtering
import 'recording_repository_bulk.dart';   // Bulk operations
import 'recording_repository_stats.dart';  // Statistics and analytics
import 'recording_repository_utils.dart';  // Utility operations

/// Main SQLite implementation of recording repository
///
/// Delegates operations to specialized service classes to maintain
/// single responsibility and keep file sizes manageable.
///
/// This repository provides a complete data access layer for recordings,
/// supporting all operations from basic CRUD to advanced analytics and
/// bulk operations. The modular design ensures maintainability and
/// allows for easy testing and extension of functionality.
///
/// Example usage:
/// ```dart
/// final repository = RecordingRepository();
/// 
/// // Save a new recording
/// await repository.saveRecording(recording);
/// 
/// // Get recordings by folder
/// final recordings = await repository.getRecordingsByFolder('folder_id');
/// 
/// // Search recordings
/// final searchResults = await repository.searchRecordings(
///   query: 'meeting',
///   folderId: 'work_folder',
/// );
/// ```
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

  // ==== SOFT DELETE OPERATIONS ====

  @override
  Future<bool> softDeleteRecording(String id) async {
    return _crudOps.softDeleteRecording(id);
  }

  @override
  Future<bool> restoreRecording(String id) async {
    return _crudOps.restoreRecording(id);
  }

  @override
  Future<bool> permanentlyDeleteRecording(String id) async {
    return _crudOps.permanentlyDeleteRecording(id);
  }

  @override
  Future<List<RecordingEntity>> getExpiredDeletedRecordings() async {
    return _crudOps.getExpiredDeletedRecordings();
  }

  @override
  Future<int> cleanupExpiredRecordings() async {
    return _crudOps.cleanupExpiredRecordings();
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
  Future<bool> toggleFavorite(String recordingId) async {
    return _bulkOps.toggleFavorite(recordingId);
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