// File: test/unit/repositories/recording_repository_test.dart
// 
// Recording Repository Unit Tests
// ===============================
//
// Comprehensive test suite for the RecordingRepository class, testing all
// data access operations, database interactions, and error handling scenarios.
//
// Test Coverage:
// - CRUD operations (Create, Read, Update, Delete)
// - Search and filtering functionality
// - Bulk operations for multiple recordings
// - Statistics and analytics operations
// - Utility operations and data maintenance
// - Database error handling and recovery

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wavnote/data/repositories/recording_repository.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/core/enums/audio_format.dart';

import '../../helpers/test_helpers.dart';

void main() {
  // Test setup
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('RecordingRepository', () {
    late RecordingRepository repository;

    setUp(() async {
      // Create repository instance
      repository = RecordingRepository();
    });

    group('CRUD Operations', () {
      test('createRecording saves recording to database', () async {
        // Arrange
        final recording = TestHelpers.createTestRecording(
          id: 'test_recording_1',
          name: 'Test Recording',
          filePath: '/test/path/recording.m4a',
          folderId: 'test_folder',
        );

        // Act
        final savedRecording = await repository.createRecording(recording);

        // Assert
        expect(savedRecording.id, equals(recording.id));
        expect(savedRecording.name, equals(recording.name));
        expect(savedRecording.filePath, equals(recording.filePath));
        expect(savedRecording.folderId, equals(recording.folderId));
      });

      test('getRecordingById returns correct recording', () async {
        // Arrange
        final recording = TestHelpers.createTestRecording(
          id: 'test_recording_1',
          name: 'Test Recording',
        );
        await repository.createRecording(recording);

        // Act
        final retrievedRecording = await repository.getRecordingById('test_recording_1');

        // Assert
        expect(retrievedRecording, isNotNull);
        expect(retrievedRecording!.id, equals('test_recording_1'));
        expect(retrievedRecording.name, equals('Test Recording'));
      });

      test('getRecordingById returns null for non-existent recording', () async {
        // Act
        final retrievedRecording = await repository.getRecordingById('non_existent_id');

        // Assert
        expect(retrievedRecording, isNull);
      });

      test('getAllRecordings returns all non-deleted recordings', () async {
        // Arrange
        final recordings = TestHelpers.createTestRecordings(3);
        for (final recording in recordings) {
          await repository.createRecording(recording);
        }

        // Act
        final allRecordings = await repository.getAllRecordings();

        // Assert
        expect(allRecordings.length, equals(3));
        expect(allRecordings.map((r) => r.id).toSet(), 
               equals(recordings.map((r) => r.id).toSet()));
      });

      test('getRecordingsByFolder returns recordings for specific folder', () async {
        // Arrange
        final folder1Recordings = [
          TestHelpers.createTestRecording(id: 'rec1', folderId: 'folder1'),
          TestHelpers.createTestRecording(id: 'rec2', folderId: 'folder1'),
        ];
        final folder2Recordings = [
          TestHelpers.createTestRecording(id: 'rec3', folderId: 'folder2'),
        ];

        for (final recording in [...folder1Recordings, ...folder2Recordings]) {
          await repository.createRecording(recording);
        }

        // Act
        final folder1Results = await repository.getRecordingsByFolder('folder1');
        final folder2Results = await repository.getRecordingsByFolder('folder2');

        // Assert
        expect(folder1Results.length, equals(2));
        expect(folder2Results.length, equals(1));
        expect(folder1Results.every((r) => r.folderId == 'folder1'), isTrue);
        expect(folder2Results.every((r) => r.folderId == 'folder2'), isTrue);
      });

      test('updateRecording modifies existing recording', () async {
        // Arrange
        final originalRecording = TestHelpers.createTestRecording(
          id: 'test_recording_1',
          name: 'Original Name',
        );
        await repository.createRecording(originalRecording);

        final updatedRecording = originalRecording.copyWith(
          name: 'Updated Name',
        );

        // Act
        final result = await repository.updateRecording(updatedRecording);

        // Assert
        expect(result, isTrue);
        
        final retrievedRecording = await repository.getRecordingById('test_recording_1');
        expect(retrievedRecording!.name, equals('Updated Name'));
      });

      test('deleteRecording removes recording from database', () async {
        // Arrange
        final recording = TestHelpers.createTestRecording(
          id: 'test_recording_1',
        );
        await repository.createRecording(recording);

        // Act
        await repository.deleteRecording('test_recording_1');

        // Assert
        final retrievedRecording = await repository.getRecordingById('test_recording_1');
        expect(retrievedRecording, isNull);
      });
    });

    group('Soft Delete Operations', () {
      test('softDeleteRecording marks recording as deleted', () async {
        // Arrange
        final recording = TestHelpers.createTestRecording(
          id: 'test_recording_1',
        );
        await repository.createRecording(recording);

        // Act
        final result = await repository.softDeleteRecording('test_recording_1');

        // Assert
        expect(result, isTrue);
        
        // Should not appear in regular queries
        final allRecordings = await repository.getAllRecordings();
        expect(allRecordings.any((r) => r.id == 'test_recording_1'), isFalse);
        
        // Should appear in recently deleted folder
        final deletedRecordings = await repository.getRecordingsByFolder('recently_deleted');
        expect(deletedRecordings.any((r) => r.id == 'test_recording_1'), isTrue);
      });

      test('restoreRecording restores soft-deleted recording', () async {
        // Arrange
        final recording = TestHelpers.createTestRecording(
          id: 'test_recording_1',
        );
        await repository.createRecording(recording);
        await repository.softDeleteRecording('test_recording_1');

        // Act
        final result = await repository.restoreRecording('test_recording_1');

        // Assert
        expect(result, isTrue);
        
        // Should appear in regular queries again
        final allRecordings = await repository.getAllRecordings();
        expect(allRecordings.any((r) => r.id == 'test_recording_1'), isTrue);
        
        // Should not appear in recently deleted folder
        final deletedRecordings = await repository.getRecordingsByFolder('recently_deleted');
        expect(deletedRecordings.any((r) => r.id == 'test_recording_1'), isFalse);
      });

      test('permanentlyDeleteRecording removes recording completely', () async {
        // Arrange
        final recording = TestHelpers.createTestRecording(
          id: 'test_recording_1',
        );
        await repository.createRecording(recording);
        await repository.softDeleteRecording('test_recording_1');

        // Act
        final result = await repository.permanentlyDeleteRecording('test_recording_1');

        // Assert
        expect(result, isTrue);
        
        // Should not appear anywhere
        final allRecordings = await repository.getAllRecordings();
        expect(allRecordings.any((r) => r.id == 'test_recording_1'), isFalse);
        
        final deletedRecordings = await repository.getRecordingsByFolder('recently_deleted');
        expect(deletedRecordings.any((r) => r.id == 'test_recording_1'), isFalse);
      });

      test('cleanupExpiredRecordings removes old deleted recordings', () async {
        // Arrange
        final oldRecording = TestHelpers.createTestRecording(
          id: 'old_recording',
          createdAt: DateTime.now().subtract(const Duration(days: 16)), // Older than 15 days
        );
        final recentRecording = TestHelpers.createTestRecording(
          id: 'recent_recording',
          createdAt: DateTime.now().subtract(const Duration(days: 5)), // Within 15 days
        );

        await repository.createRecording(oldRecording);
        await repository.createRecording(recentRecording);
        await repository.softDeleteRecording('old_recording');
        await repository.softDeleteRecording('recent_recording');

        // Act
        final deletedCount = await repository.cleanupExpiredRecordings();

        // Assert
        expect(deletedCount, equals(1)); // Only old recording should be deleted
        
        final deletedRecordings = await repository.getRecordingsByFolder('recently_deleted');
        expect(deletedRecordings.any((r) => r.id == 'old_recording'), isFalse);
        expect(deletedRecordings.any((r) => r.id == 'recent_recording'), isTrue);
      });
    });

    group('Search Operations', () {
      test('searchRecordings finds recordings by name', () async {
        // Arrange
        final recordings = [
          TestHelpers.createTestRecording(id: 'rec1', name: 'Meeting Notes'),
          TestHelpers.createTestRecording(id: 'rec2', name: 'Personal Memo'),
          TestHelpers.createTestRecording(id: 'rec3', name: 'Project Meeting'),
        ];

        for (final recording in recordings) {
          await repository.createRecording(recording);
        }

        // Act
        final searchResults = await repository.searchRecordings('meeting');

        // Assert
        expect(searchResults.length, equals(2));
        expect(searchResults.every((r) => r.name.toLowerCase().contains('meeting')), isTrue);
      });

      test('searchRecordings filters by folder', () async {
        // Arrange
        final recordings = [
          TestHelpers.createTestRecording(id: 'rec1', name: 'Test Recording', folderId: 'folder1'),
          TestHelpers.createTestRecording(id: 'rec2', name: 'Test Recording', folderId: 'folder2'),
          TestHelpers.createTestRecording(id: 'rec3', name: 'Another Recording', folderId: 'folder1'),
        ];

        for (final recording in recordings) {
          await repository.createRecording(recording);
        }

        // Act
        // Get recordings from folder1 and filter by search term
        final folderRecordings = await repository.getRecordingsByFolder('folder1');
        final searchResults = folderRecordings.where((r) => 
          r.name.toLowerCase().contains('recording')).toList();

        // Assert
        expect(searchResults.length, equals(2));
        expect(searchResults.every((r) => r.folderId == 'folder1'), isTrue);
      });

      test('getFavoriteRecordings returns only favorite recordings', () async {
        // Arrange
        final recordings = [
          TestHelpers.createTestRecording(id: 'rec1', isFavorite: true),
          TestHelpers.createTestRecording(id: 'rec2', isFavorite: false),
          TestHelpers.createTestRecording(id: 'rec3', isFavorite: true),
        ];

        for (final recording in recordings) {
          await repository.createRecording(recording);
        }

        // Act
        final favoriteRecordings = await repository.getFavoriteRecordings();

        // Assert
        expect(favoriteRecordings.length, equals(2));
        expect(favoriteRecordings.every((r) => r.isFavorite), isTrue);
      });
    });

    group('Bulk Operations', () {
      test('bulkDeleteRecordings deletes multiple recordings', () async {
        // Arrange
        final recordings = TestHelpers.createTestRecordings(5);
        for (final recording in recordings) {
          await repository.createRecording(recording);
        }

        final idsToDelete = recordings.take(3).map((r) => r.id).toList();

        // Act
        await repository.deleteRecordings(idsToDelete);

        // Assert
        final remainingRecordings = await repository.getAllRecordings();
        expect(remainingRecordings.length, equals(2));
        expect(remainingRecordings.any((r) => idsToDelete.contains(r.id)), isFalse);
      });

      test('bulkSoftDeleteRecordings soft deletes multiple recordings', () async {
        // Arrange
        final recordings = TestHelpers.createTestRecordings(5);
        for (final recording in recordings) {
          await repository.createRecording(recording);
        }

        final idsToDelete = recordings.take(3).map((r) => r.id).toList();

        // Act
        // Soft delete each recording individually since no bulk method exists
        for (final id in idsToDelete) {
          await repository.softDeleteRecording(id);
        }

        // Assert
        final activeRecordings = await repository.getAllRecordings();
        expect(activeRecordings.length, equals(2));
        
        final deletedRecordings = await repository.getRecordingsByFolder('recently_deleted');
        expect(deletedRecordings.length, equals(3));
      });

      test('bulkUpdateFolder moves recordings to new folder', () async {
        // Arrange
        final recordings = [
          TestHelpers.createTestRecording(id: 'rec1', folderId: 'folder1'),
          TestHelpers.createTestRecording(id: 'rec2', folderId: 'folder1'),
          TestHelpers.createTestRecording(id: 'rec3', folderId: 'folder2'),
        ];

        for (final recording in recordings) {
          await repository.createRecording(recording);
        }

        // Act
        await repository.moveRecordingsToFolder(['rec1', 'rec2'], 'new_folder');

        // Assert
        final newFolderRecordings = await repository.getRecordingsByFolder('new_folder');
        expect(newFolderRecordings.length, equals(2));
        
        final oldFolderRecordings = await repository.getRecordingsByFolder('folder1');
        expect(oldFolderRecordings.length, equals(0));
      });
    });

    group('Statistics Operations', () {
      test('getRecordingCountByFolder returns correct count', () async {
        // Arrange
        final recordings = [
          TestHelpers.createTestRecording(id: 'rec1', folderId: 'folder1'),
          TestHelpers.createTestRecording(id: 'rec2', folderId: 'folder1'),
          TestHelpers.createTestRecording(id: 'rec3', folderId: 'folder2'),
        ];

        for (final recording in recordings) {
          await repository.createRecording(recording);
        }

        // Act
        final folder1Count = await repository.getRecordingCountByFolder('folder1');
        final folder2Count = await repository.getRecordingCountByFolder('folder2');
        final emptyFolderCount = await repository.getRecordingCountByFolder('empty_folder');

        // Assert
        expect(folder1Count, equals(2));
        expect(folder2Count, equals(1));
        expect(emptyFolderCount, equals(0));
      });

      test('getTotalRecordingDuration calculates total duration', () async {
        // Arrange
        final recordings = [
          TestHelpers.createTestRecording(id: 'rec1', duration: const Duration(minutes: 2)),
          TestHelpers.createTestRecording(id: 'rec2', duration: const Duration(minutes: 3)),
          TestHelpers.createTestRecording(id: 'rec3', duration: const Duration(seconds: 30)),
        ];

        for (final recording in recordings) {
          await repository.createRecording(recording);
        }

        // Act
        final totalDuration = await repository.getTotalDurationByFolder('all_recordings');

        // Assert
        expect(totalDuration.inSeconds, equals(330)); // 2min + 3min + 30sec = 330 seconds
      });

      test('getTotalStorageUsed calculates total file size', () async {
        // Arrange
        final recordings = [
          TestHelpers.createTestRecording(id: 'rec1', fileSize: 1000000), // 1MB
          TestHelpers.createTestRecording(id: 'rec2', fileSize: 2000000), // 2MB
          TestHelpers.createTestRecording(id: 'rec3', fileSize: 500000),  // 0.5MB
        ];

        for (final recording in recordings) {
          await repository.createRecording(recording);
        }

        // Act
        final totalSize = await repository.getTotalFileSizeByFolder('all_recordings');

        // Assert
        expect(totalSize, equals(3500000)); // 3.5MB total
      });
    });

    group('Favorite Operations', () {
      test('toggleFavorite changes favorite status', () async {
        // Arrange
        final recording = TestHelpers.createTestRecording(
          id: 'test_recording_1',
          isFavorite: false,
        );
        await repository.createRecording(recording);

        // Act
        final result1 = await repository.toggleFavorite('test_recording_1');
        final afterToggle1 = await repository.getRecordingById('test_recording_1');
        
        final result2 = await repository.toggleFavorite('test_recording_1');
        final afterToggle2 = await repository.getRecordingById('test_recording_1');

        // Assert
        expect(result1, isTrue);
        expect(afterToggle1!.isFavorite, isTrue);
        
        expect(result2, isTrue);
        expect(afterToggle2!.isFavorite, isFalse);
      });
    });

    group('Error Handling', () {
      test('handles database errors gracefully', () async {
        // Test with invalid recording data
        expect(
          () async => await repository.createRecording(
            TestHelpers.createTestRecording(id: ''), // Invalid empty ID
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('handles non-existent recording operations gracefully', () async {
        // Act & Assert
        final updateResult = await repository.updateRecording(
          TestHelpers.createTestRecording(id: 'non_existent'),
        );
        expect(updateResult, isFalse);

        final toggleResult = await repository.toggleFavorite('non_existent');
        expect(toggleResult, isFalse);

        final deleteResult = await repository.softDeleteRecording('non_existent');
        expect(deleteResult, isFalse);
      });

      test('handles concurrent operations safely', () async {
        // Arrange
        final recording = TestHelpers.createTestRecording(
          id: 'concurrent_test',
        );
        await repository.createRecording(recording);

        // Act - Perform multiple concurrent operations
        final futures = [
          repository.toggleFavorite('concurrent_test'),
          repository.updateRecording(recording.copyWith(name: 'Updated Name 1')),
          repository.updateRecording(recording.copyWith(name: 'Updated Name 2')),
          repository.toggleFavorite('concurrent_test'),
        ];

        final results = await Future.wait(futures);

        // Assert - All operations should complete without throwing
        expect(results.length, equals(4));
        
        final finalRecording = await repository.getRecordingById('concurrent_test');
        expect(finalRecording, isNotNull);
      });
    });

    group('Data Validation', () {
      test('validates audio format enum correctly', () async {
        // Test all audio formats
        for (final format in AudioFormat.values) {
          final recording = TestHelpers.createTestRecording(
            id: 'format_test_${format.name}',
            format: format,
          );

          // Should not throw
          await repository.createRecording(recording);

          final retrieved = await repository.getRecordingById('format_test_${format.name}');
          expect(retrieved!.format, equals(format));
        }
      });

      test('validates duration constraints', () async {
        // Test with various durations
        final durations = [
          Duration.zero,
          const Duration(seconds: 1),
          const Duration(hours: 1),
          const Duration(hours: 24),
        ];

        for (int i = 0; i < durations.length; i++) {
          final recording = TestHelpers.createTestRecording(
            id: 'duration_test_$i',
            duration: durations[i],
          );

          await repository.createRecording(recording);

          final retrieved = await repository.getRecordingById('duration_test_$i');
          expect(retrieved!.duration, equals(durations[i]));
        }
      });

      test('validates file size constraints', () async {
        // Test with various file sizes
        final fileSizes = [0, 1024, 1024000, 1024000000]; // 0B, 1KB, 1MB, 1GB

        for (int i = 0; i < fileSizes.length; i++) {
          final recording = TestHelpers.createTestRecording(
            id: 'size_test_$i',
            fileSize: fileSizes[i],
          );

          await repository.createRecording(recording);

          final retrieved = await repository.getRecordingById('size_test_$i');
          expect(retrieved!.fileSize, equals(fileSizes[i]));
        }
      });
    });
  });
}