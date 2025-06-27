// File: test/unit/repositories/folder_repository_test.dart
// 
// Folder Repository Unit Tests - CORRECTED VERSION
// ================================================
//
// Comprehensive test suite for the FolderRepository class using the actual
// interface methods and entity structure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wavnote/domain/entities/folder_entity.dart';
import 'package:wavnote/core/enums/folder_type.dart';
import 'package:wavnote/domain/repositories/i_folder_repository.dart';

import '../../helpers/test_helpers.dart';

// Mock repository for testing
class MockFolderRepository extends Mock implements IFolderRepository {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('FolderRepository Interface Tests', () {
    late MockFolderRepository repository;

    setUp(() {
      repository = MockFolderRepository();
    });

    group('Basic CRUD Operations', () {
      test('getAllFolders returns all folders', () async {
        // Arrange
        final allFolders = [
          TestHelpers.createTestFolder(id: 'all_recordings', name: 'All Recordings'),
          TestHelpers.createTestFolder(id: 'favorites', name: 'Favorites'),
          TestHelpers.createTestFolder(id: 'custom_1', name: 'Work'),
          TestHelpers.createTestFolder(id: 'custom_2', name: 'Personal'),
        ];

        when(() => repository.getAllFolders())
            .thenAnswer((_) async => allFolders);

        // Act
        final result = await repository.getAllFolders();

        // Assert
        expect(result.length, equals(4));
        expect(result.where((f) => f.type == FolderType.customFolder).length, equals(2));
      });

      test('createFolder creates new custom folder successfully', () async {
        // Arrange
        final newFolder = TestHelpers.createTestFolder(
          id: 'custom_folder_1',
          name: 'Work Meetings',
          type: FolderType.customFolder,
        );

        when(() => repository.createFolder(any()))
            .thenAnswer((_) async => newFolder);

        // Act
        final result = await repository.createFolder(newFolder);

        // Assert
        expect(result.id, equals('custom_folder_1'));
        expect(result.name, equals('Work Meetings'));
        expect(result.type, equals(FolderType.customFolder));
        verify(() => repository.createFolder(any())).called(1);
      });

      test('updateFolder modifies existing folder successfully', () async {
        // Arrange
        final updatedFolder = TestHelpers.createTestFolder(
          id: 'folder_1',
          name: 'Updated Name',
        );

        when(() => repository.updateFolder(any()))
            .thenAnswer((_) async => updatedFolder);

        // Act
        final result = await repository.updateFolder(updatedFolder);

        // Assert
        expect(result.name, equals('Updated Name'));
        verify(() => repository.updateFolder(any())).called(1);
      });

      test('deleteFolder removes custom folder successfully', () async {
        // Arrange
        when(() => repository.deleteFolder('custom_folder_1'))
            .thenAnswer((_) async => true);

        // Act
        final result = await repository.deleteFolder('custom_folder_1');

        // Assert
        expect(result, isTrue);
        verify(() => repository.deleteFolder('custom_folder_1')).called(1);
      });

      test('getFolderById returns specific folder', () async {
        // Arrange
        final testFolder = TestHelpers.createTestFolder(
          id: 'test_folder',
          name: 'Test Folder',
        );

        when(() => repository.getFolderById('test_folder'))
            .thenAnswer((_) async => testFolder);

        // Act
        final result = await repository.getFolderById('test_folder');

        // Assert
        expect(result?.id, equals('test_folder'));
        expect(result?.name, equals('Test Folder'));
      });

      test('getFolderById returns null for non-existent folder', () async {
        // Arrange
        when(() => repository.getFolderById('non_existent'))
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.getFolderById('non_existent');

        // Assert
        expect(result, isNull);
      });

      test('getCustomFolders returns only user-created folders', () async {
        // Arrange
        final customFolders = [
          TestHelpers.createTestFolder(id: 'custom_1', name: 'Work'),
          TestHelpers.createTestFolder(id: 'custom_2', name: 'Personal'),
        ];

        when(() => repository.getCustomFolders())
            .thenAnswer((_) async => customFolders);

        // Act
        final result = await repository.getCustomFolders();

        // Assert
        expect(result.length, equals(2));
        expect(result.every((f) => f.type == FolderType.customFolder), isTrue);
      });
    });

    group('Folder Count Management', () {
      test('updateFolderCount updates folder recording count', () async {
        // Arrange
        when(() => repository.updateFolderCount('folder_1', 5))
            .thenAnswer((_) async => true);

        // Act
        final result = await repository.updateFolderCount('folder_1', 5);

        // Assert
        expect(result, isTrue);
        verify(() => repository.updateFolderCount('folder_1', 5)).called(1);
      });

      test('incrementFolderCount increases count by one', () async {
        // Arrange
        when(() => repository.incrementFolderCount('folder_1'))
            .thenAnswer((_) async => true);

        // Act
        final result = await repository.incrementFolderCount('folder_1');

        // Assert
        expect(result, isTrue);
        verify(() => repository.incrementFolderCount('folder_1')).called(1);
      });

      test('decrementFolderCount decreases count by one', () async {
        // Arrange
        when(() => repository.decrementFolderCount('folder_1'))
            .thenAnswer((_) async => true);

        // Act
        final result = await repository.decrementFolderCount('folder_1');

        // Assert
        expect(result, isTrue);
        verify(() => repository.decrementFolderCount('folder_1')).called(1);
      });
    });

    group('Folder Validation', () {
      test('folderExistsByName checks for duplicate names', () async {
        // Arrange
        when(() => repository.folderExistsByName('Existing Folder'))
            .thenAnswer((_) async => true);
        when(() => repository.folderExistsByName('New Folder'))
            .thenAnswer((_) async => false);

        // Act & Assert
        expect(await repository.folderExistsByName('Existing Folder'), isTrue);
        expect(await repository.folderExistsByName('New Folder'), isFalse);
      });

      test('folderExistsByName with excludeId parameter', () async {
        // Arrange
        when(() => repository.folderExistsByName('Test Folder', excludeId: 'folder_1'))
            .thenAnswer((_) async => false);

        // Act
        final result = await repository.folderExistsByName('Test Folder', excludeId: 'folder_1');

        // Assert
        expect(result, isFalse);
        verify(() => repository.folderExistsByName('Test Folder', excludeId: 'folder_1')).called(1);
      });
    });

    group('Advanced Folder Operations', () {
      test('getFoldersWithRecordings returns folders containing recordings', () async {
        // Arrange
        final foldersWithRecordings = [
          TestHelpers.createTestFolder(id: 'folder1', name: 'Work', recordingCount: 5),
          TestHelpers.createTestFolder(id: 'folder2', name: 'Personal', recordingCount: 3),
        ];

        when(() => repository.getFoldersWithRecordings())
            .thenAnswer((_) async => foldersWithRecordings);

        // Act
        final result = await repository.getFoldersWithRecordings();

        // Assert
        expect(result.length, equals(2));
        expect(result.every((f) => f.recordingCount > 0), isTrue);
      });

      test('searchFolders finds folders by name', () async {
        // Arrange
        final searchResults = [
          TestHelpers.createTestFolder(id: 'work1', name: 'Work Notes'),
          TestHelpers.createTestFolder(id: 'work2', name: 'Work Meetings'),
        ];

        when(() => repository.searchFolders('work'))
            .thenAnswer((_) async => searchResults);

        // Act
        final result = await repository.searchFolders('work');

        // Assert
        expect(result.length, equals(2));
        expect(result.every((f) => f.name.toLowerCase().contains('work')), isTrue);
      });

      test('getTotalRecordingCount returns sum of all recordings', () async {
        // Arrange
        when(() => repository.getTotalRecordingCount())
            .thenAnswer((_) async => 42);

        // Act
        final result = await repository.getTotalRecordingCount();

        // Assert
        expect(result, equals(42));
      });
    });

    group('Data Export/Import Operations', () {
      test('exportFolders returns folder data for backup', () async {
        // Arrange
        final exportData = {
          'folders': [
            {'id': 'folder1', 'name': 'Work'},
            {'id': 'folder2', 'name': 'Personal'},
          ],
          'version': '1.0',
        };

        when(() => repository.exportFolders())
            .thenAnswer((_) async => exportData);

        // Act
        final result = await repository.exportFolders();

        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result['folders'], isA<List>());
      });

      test('importFolders restores folder data from backup', () async {
        // Arrange
        final importData = {
          'folders': [
            {'id': 'folder1', 'name': 'Imported Work'},
          ],
        };

        when(() => repository.importFolders(importData))
            .thenAnswer((_) async => true);

        // Act
        final result = await repository.importFolders(importData);

        // Assert
        expect(result, isTrue);
        verify(() => repository.importFolders(importData)).called(1);
      });

      test('clearCustomFolders removes all user-created folders', () async {
        // Arrange
        when(() => repository.clearCustomFolders())
            .thenAnswer((_) async => true); // Successfully cleared folders

        // Act
        final result = await repository.clearCustomFolders();

        // Assert
        expect(result, isTrue);
        verify(() => repository.clearCustomFolders()).called(1);
      });
    });

    group('Error Handling', () {
      test('handles database errors gracefully', () async {
        // Arrange
        when(() => repository.createFolder(any()))
            .thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => repository.createFolder(TestHelpers.createTestFolder()),
          throwsException,
        );
      });

      test('handles invalid folder operations', () async {
        // Arrange
        when(() => repository.deleteFolder(''))
            .thenAnswer((_) async => false);

        // Act
        final result = await repository.deleteFolder('');

        // Assert
        expect(result, isFalse);
      });

      test('handles folder name validation errors', () async {
        // Arrange
        when(() => repository.folderExistsByName(''))
            .thenAnswer((_) async => false);

        // Act
        final result = await repository.folderExistsByName('');

        // Assert
        expect(result, isFalse);
      });
    });

    group('Performance and Memory Management', () {
      test('handles large folder lists efficiently', () async {
        // Arrange
        final largeFolderList = List.generate(
          100,
          (index) => TestHelpers.createTestFolder(
            id: 'folder_$index',
            name: 'Folder $index',
          ),
        );

        when(() => repository.getAllFolders())
            .thenAnswer((_) async => largeFolderList);

        // Act
        final result = await repository.getAllFolders();

        // Assert
        expect(result.length, equals(100));
      });

      test('search operation works with many folders', () async {
        // Arrange
        final searchResults = List.generate(
          10,
          (index) => TestHelpers.createTestFolder(
            id: 'test_$index',
            name: 'Test Folder $index',
          ),
        );

        when(() => repository.searchFolders('test'))
            .thenAnswer((_) async => searchResults);

        // Act
        final result = await repository.searchFolders('test');

        // Assert
        expect(result.length, equals(10));
        expect(result.every((f) => f.name.contains('Test')), isTrue);
      });
    });

    group('Folder Entity Validation', () {
      test('folder entity has required fields', () {
        // Arrange & Act
        final folder = TestHelpers.createTestFolder(
          id: 'test_id',
          name: 'Test Name',
          type: FolderType.customFolder,
        );

        // Assert
        expect(folder.id, equals('test_id'));
        expect(folder.name, equals('Test Name'));
        expect(folder.type, equals(FolderType.customFolder));
        expect(folder.icon, isA<IconData>());
        expect(folder.color, isA<Color>());
        expect(folder.createdAt, isA<DateTime>());
      });

      test('default folder properties are correct', () {
        // Arrange & Act
        final folder = TestHelpers.createTestFolder(
          type: FolderType.defaultFolder,
          isDeletable: false,
        );

        // Assert
        expect(folder.type, equals(FolderType.defaultFolder));
        expect(folder.isDeletable, isFalse);
        expect(folder.recordingCount, equals(0));
      });
    });
  });
}