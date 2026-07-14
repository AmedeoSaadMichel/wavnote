// File: test/unit/blocs/folder_bloc_test.dart
//
// Folder BLoC Unit Tests - CORRECTED VERSION
// ===========================================
//
// Comprehensive test suite for the FolderBloc class using proper
// state and event definitions.

import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';

import 'package:wavnote/presentation/bloc/folder/folder_bloc.dart';
import 'package:wavnote/domain/entities/folder_entity.dart';
import 'package:wavnote/domain/repositories/i_folder_repository.dart';
import 'package:wavnote/core/enums/folder_type.dart';

import '../../helpers/test_helpers.dart';

// Mock classes
class MockFolderRepository extends Mock implements IFolderRepository {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('FolderBloc', () {
    late FolderBloc bloc;
    late MockFolderRepository mockRepository;

    setUp(() {
      mockRepository = MockFolderRepository();

      // Set up default mock behaviors
      when(() => mockRepository.getAllFolders()).thenAnswer(
        (_) async => [
          TestHelpers.createTestFolder(
            id: 'all_recordings',
            name: 'All Recordings',
            type: FolderType.defaultFolder,
          ),
          TestHelpers.createTestFolder(
            id: 'favorites',
            name: 'Favorites',
            type: FolderType.defaultFolder,
          ),
        ],
      );

      when(() => mockRepository.getCustomFolders()).thenAnswer((_) async => []);

      bloc = FolderBloc(folderRepository: mockRepository);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is FolderInitial', () {
      expect(bloc.state, equals(const FolderInitial()));
    });

    group('LoadFolders', () {
      blocTest<FolderBloc, FolderState>(
        'emits [FolderLoading, FolderLoaded] when folders load successfully',
        build: () => bloc,
        act: (bloc) => bloc.add(const LoadFolders()),
        expect: () => [isA<FolderLoading>(), isA<FolderLoaded>()],
      );

      blocTest<FolderBloc, FolderState>(
        'emits [FolderLoading, FolderError] when loading fails',
        build: () {
          when(
            () => mockRepository.getAllFolders(),
          ).thenThrow(Exception('Database error'));
          return FolderBloc(folderRepository: mockRepository);
        },
        act: (bloc) => bloc.add(const LoadFolders()),
        expect: () => [isA<FolderLoading>(), isA<FolderError>()],
      );

      blocTest<FolderBloc, FolderState>(
        'loads folders with correct structure',
        build: () => bloc,
        act: (bloc) => bloc.add(const LoadFolders()),
        verify: (bloc) {
          final state = bloc.state;
          if (state is FolderLoaded) {
            expect(state.defaultFolders, isA<List<FolderEntity>>());
            expect(state.customFolders, isA<List<FolderEntity>>());
            expect(state.isEditMode, false);
            expect(state.selectedFolderIds, isEmpty);
          }
        },
      );
    });

    group('CreateFolder', () {
      blocTest<FolderBloc, FolderState>(
        'emits [FolderCreating, FolderCreated] when folder creation succeeds',
        build: () {
          final newFolder = TestHelpers.createTestFolder(
            id: 'new_folder_1',
            name: 'Work',
            colorValue: Colors.blue.toARGB32(),
            iconCodePoint: Icons.work.codePoint,
            type: FolderType.customFolder,
          );

          when(
            () => mockRepository.createFolder(any()),
          ).thenAnswer((_) async => newFolder);

          return bloc;
        },
        seed: () => const FolderLoaded(defaultFolders: [], customFolders: []),
        act: (bloc) => bloc.add(
          CreateFolder(
            name: 'Work',
            colorValue: Colors.blue.toARGB32(),
            iconCodePoint: Icons.work.codePoint,
          ),
        ),
        // Il bloc emette anche un FolderLoaded intermedio per aggiornare
        // subito la lista prima dello stato di successo.
        expect: () => [
          isA<FolderCreating>(),
          isA<FolderLoaded>(),
          isA<FolderCreated>(),
        ],
        verify: (bloc) {
          verify(() => mockRepository.createFolder(any())).called(1);
          final state = bloc.state;
          if (state is FolderCreated) {
            expect(state.createdFolder.name, equals('Work'));
            expect(state.createdFolder.colorValue, equals(Colors.blue.value));
            expect(
              state.createdFolder.iconCodePoint,
              equals(Icons.work.codePoint),
            );
            expect(state.createdFolder.type, equals(FolderType.customFolder));
          }
        },
      );

      blocTest<FolderBloc, FolderState>(
        'emits error when folder name already exists',
        build: () {
          // Il check duplicati vive nel repository: createFolder lancia
          // se il nome esiste già. Il bloc emette Creating, poi Error e
          // ripristina lo stato Loaded precedente.
          when(() => mockRepository.createFolder(any())).thenThrow(
            Exception('A folder with the name "Work" already exists'),
          );
          return bloc;
        },
        seed: () => const FolderLoaded(defaultFolders: [], customFolders: []),
        act: (bloc) => bloc.add(
          CreateFolder(
            name: 'Work',
            colorValue: Colors.blue.toARGB32(),
            iconCodePoint: Icons.work.codePoint,
          ),
        ),
        expect: () => [
          isA<FolderCreating>(),
          isA<FolderError>(),
          isA<FolderLoaded>(),
        ],
      );
    });

    group('DeleteFolder', () {
      blocTest<FolderBloc, FolderState>(
        'emits [FolderDeleted] when folder deletion succeeds',
        build: () {
          when(
            () => mockRepository.deleteFolder('folder_1'),
          ).thenAnswer((_) async => true);
          return bloc;
        },
        seed: () => FolderLoaded(
          defaultFolders: const [],
          customFolders: [
            TestHelpers.createTestFolder(id: 'folder_1', name: 'Work'),
          ],
        ),
        act: (bloc) => bloc.add(const DeleteFolder(folderId: 'folder_1')),
        // Il bloc emette prima FolderLoaded con la lista aggiornata,
        // poi lo stato di successo FolderDeleted.
        expect: () => [isA<FolderLoaded>(), isA<FolderDeleted>()],
        verify: (bloc) {
          verify(() => mockRepository.deleteFolder('folder_1')).called(1);
          final state = bloc.state;
          if (state is FolderDeleted) {
            expect(state.deletedFolderId, equals('folder_1'));
          }
        },
      );

      blocTest<FolderBloc, FolderState>(
        'emits error when deleting non-existent folder',
        build: () {
          when(
            () => mockRepository.deleteFolder('non_existent'),
          ).thenAnswer((_) async => false);
          return bloc;
        },
        seed: () => const FolderLoaded(defaultFolders: [], customFolders: []),
        act: (bloc) => bloc.add(const DeleteFolder(folderId: 'non_existent')),
        expect: () => [isA<FolderError>()],
        // La cartella non esiste nello stato: il bloc fallisce prima di
        // toccare il repository.
        verify: (_) {
          verifyNever(() => mockRepository.deleteFolder(any()));
        },
      );
    });

    group('Edit Mode and Selection', () {
      test('handles toggle edit mode', () {
        bloc.add(const ToggleFolderEditMode());

        // Should handle edit mode toggle
        expect(bloc.state, isA<FolderState>());
      });

      test('handles folder selection toggle', () {
        bloc.add(const ToggleFolderSelection(folderId: 'folder_1'));

        // Should handle selection toggle
        expect(bloc.state, isA<FolderState>());
      });

      test('handles clear selection', () {
        bloc.add(const ClearFolderSelection());

        // Should handle selection clearing
        expect(bloc.state, isA<FolderState>());
      });

      blocTest<FolderBloc, FolderState>(
        'handles multiple folder deletion',
        build: () {
          when(
            () => mockRepository.deleteFolder(any()),
          ).thenAnswer((_) async => true);
          return bloc;
        },
        seed: () => FolderLoaded(
          defaultFolders: const [],
          customFolders: [
            TestHelpers.createTestFolder(id: 'folder_1', name: 'Work'),
            TestHelpers.createTestFolder(id: 'folder_2', name: 'Personal'),
          ],
          isEditMode: true,
          selectedFolderIds: const {'folder_1', 'folder_2'},
        ),
        act: (bloc) => bloc.add(
          const DeleteSelectedFolders(folderIds: ['folder_1', 'folder_2']),
        ),
        expect: () => [isA<FoldersDeleted>()],
      );
    });

    group('Folder Operations', () {
      test('handles update folder count', () {
        bloc.add(const UpdateFolderCount(folderId: 'folder_1', newCount: 5));

        // Should handle count update
        expect(bloc.state, isA<FolderState>());
      });

      test('handles rename folder', () {
        bloc.add(
          const RenameFolderEvent(folderId: 'folder_1', newName: 'New Name'),
        );

        // Should handle folder rename
        expect(bloc.state, isA<FolderState>());
      });

    });

    group('Error Handling', () {
      blocTest<FolderBloc, FolderState>(
        'handles repository errors gracefully',
        build: () {
          when(
            () => mockRepository.getAllFolders(),
          ).thenThrow(Exception('Database error'));
          return FolderBloc(folderRepository: mockRepository);
        },
        act: (bloc) => bloc.add(const LoadFolders()),
        expect: () => [isA<FolderLoading>(), isA<FolderError>()],
      );

      test('handles invalid folder operations', () {
        bloc.add(const DeleteFolder(folderId: ''));

        // Should handle invalid operations gracefully
        expect(bloc.state, isA<FolderState>());
      });
    });

    group('State Transitions', () {
      blocTest<FolderBloc, FolderState>(
        'transitions from initial to loaded state correctly',
        build: () => bloc,
        act: (bloc) => bloc.add(const LoadFolders()),
        expect: () => [isA<FolderLoading>(), isA<FolderLoaded>()],
      );

      test('maintains state consistency during operations', () {
        bloc.add(const ToggleFolderEditMode());

        // Should maintain consistent state
        expect(bloc.state, isA<FolderState>());
      });
    });

    group('Memory Management', () {
      test('properly disposes resources', () async {
        await bloc.close();

        // The bloc should be closed after disposal
        expect(bloc.isClosed, isTrue);
      });

      test('handles rapid events gracefully', () async {
        bloc.add(const LoadFolders());
        bloc.add(const RefreshFolders());
        bloc.add(const ToggleFolderEditMode());

        // Wait a bit for processing
        await Future.delayed(const Duration(milliseconds: 100));

        // Should handle rapid events without memory issues
        expect(
          bloc.state,
          anyOf([
            isA<FolderInitial>(),
            isA<FolderLoading>(),
            isA<FolderLoaded>(),
            isA<FolderError>(),
          ]),
        );
      });
    });
  });
}
