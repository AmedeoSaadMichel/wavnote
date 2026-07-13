// File: test/unit/repositories/folder_repository_test.dart
//
// Test del FolderRepository REALE su SQLite host (sqflite_common_ffi).
// Sostituisce la versione precedente che testava un MockFolderRepository
// (verificava solo il comportamento del mock, non l'implementazione).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:wavnote/core/enums/folder_type.dart';
import 'package:wavnote/data/repositories/folder_repository.dart';
import 'package:wavnote/domain/entities/folder_entity.dart';
import 'package:wavnote/domain/repositories/i_folder_repository.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late FolderRepository repository;

  setUpAll(() async {
    // Init sqflite ffi + path_provider mock con directory unica per isolate.
    await TestHelpers.initializeTestEnvironment();
  });

  setUp(() async {
    repository = FolderRepository();
    await repository.clearCustomFolders();
  });

  FolderEntity buildFolder({
    String id = 'custom_1',
    String name = 'Custom Folder',
    int recordingCount = 0,
  }) {
    return TestHelpers.createTestFolder(
      id: id,
      name: name,
      recordingCount: recordingCount,
      type: FolderType.customFolder,
      isDeletable: true,
    );
  }

  group('FolderRepository — cartelle di default', () {
    test('getAllFolders restituisce le 3 cartelle di sistema', () async {
      final folders = await repository.getAllFolders();

      final ids = folders.map((f) => f.id).toList();
      expect(
        ids,
        containsAll(['all_recordings', 'favourites', 'recently_deleted']),
      );
      expect(folders.length, 3);
    });

    test('getFolderById risolve una cartella di default', () async {
      final folder = await repository.getFolderById('recently_deleted');

      expect(folder, isNotNull);
      expect(folder!.name, 'Recently Deleted');
      expect(folder.canBeDeleted, isFalse);
    });
  });

  group('FolderRepository — CRUD custom', () {
    test('createFolder inserisce e getFolderById la rilegge dal DB', () async {
      await repository.createFolder(buildFolder(id: 'f1', name: 'Musica'));

      final loaded = await repository.getFolderById('f1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Musica');
      expect(loaded.type, FolderType.customFolder);
    });

    test('createFolder rifiuta nome duplicato (case-insensitive)', () async {
      await repository.createFolder(buildFolder(id: 'f1', name: 'Musica'));

      expect(
        () => repository.createFolder(buildFolder(id: 'f2', name: 'musica')),
        throwsException,
      );
    });

    test('createFolder rifiuta il nome di una cartella di default', () async {
      expect(
        () =>
            repository.createFolder(buildFolder(id: 'f1', name: 'Favourites')),
        throwsException,
      );
    });

    test('updateFolder modifica una cartella esistente', () async {
      await repository.createFolder(buildFolder(id: 'f1', name: 'Vecchio'));

      final updated = await repository.updateFolder(
        buildFolder(id: 'f1', name: 'Nuovo'),
      );

      expect(updated.updatedAt, isNotNull);
      final loaded = await repository.getFolderById('f1');
      expect(loaded!.name, 'Nuovo');
    });

    test('updateFolder su id inesistente lancia eccezione', () async {
      expect(
        () => repository.updateFolder(buildFolder(id: 'ghost')),
        throwsException,
      );
    });

    test('deleteFolder rimuove una cartella custom', () async {
      await repository.createFolder(buildFolder(id: 'f1'));

      final deleted = await repository.deleteFolder('f1');

      expect(deleted, isTrue);
      expect(await repository.getFolderById('f1'), isNull);
    });

    test('deleteFolder restituisce false per id inesistente', () async {
      expect(await repository.deleteFolder('ghost'), isFalse);
    });

    test('deleteFolder restituisce false per cartella di default', () async {
      expect(await repository.deleteFolder('all_recordings'), isFalse);
      expect(await repository.getFolderById('all_recordings'), isNotNull);
    });

    test('getCustomFolders restituisce solo le cartelle utente', () async {
      await repository.createFolder(buildFolder(id: 'f1', name: 'Uno'));
      await repository.createFolder(buildFolder(id: 'f2', name: 'Due'));

      final custom = await repository.getCustomFolders();

      expect(custom.length, 2);
      expect(custom.map((f) => f.id), containsAll(['f1', 'f2']));
    });
  });

  group('FolderRepository — validazione nomi', () {
    test('folderExistsByName trova nomi esistenti ignorando il case', () async {
      await repository.createFolder(buildFolder(id: 'f1', name: 'Musica'));

      expect(await repository.folderExistsByName('MUSICA'), isTrue);
      expect(await repository.folderExistsByName('Podcast'), isFalse);
    });

    test('folderExistsByName con excludeId ignora la cartella stessa',
        () async {
      await repository.createFolder(buildFolder(id: 'f1', name: 'Musica'));

      expect(
        await repository.folderExistsByName('Musica', excludeId: 'f1'),
        isFalse,
      );
      expect(
        await repository.folderExistsByName('Musica', excludeId: 'other'),
        isTrue,
      );
    });
  });

  group('FolderRepository — contatori', () {
    test('updateFolderCount imposta il conteggio', () async {
      await repository.createFolder(buildFolder(id: 'f1'));

      expect(await repository.updateFolderCount('f1', 7), isTrue);
      final custom = await repository.getCustomFolders();
      expect(custom.single.recordingCount, 7);
    });

    test('increment e decrement aggiornano di uno', () async {
      await repository.createFolder(buildFolder(id: 'f1', recordingCount: 1));

      await repository.incrementFolderCount('f1');
      var folder = (await repository.getCustomFolders()).single;
      expect(folder.recordingCount, 2);

      await repository.decrementFolderCount('f1');
      folder = (await repository.getCustomFolders()).single;
      expect(folder.recordingCount, 1);
    });

    test('decrementFolderCount non scende sotto zero', () async {
      await repository.createFolder(buildFolder(id: 'f1', recordingCount: 0));

      await repository.decrementFolderCount('f1');

      final folder = (await repository.getCustomFolders()).single;
      expect(folder.recordingCount, 0);
    });

    test('updateFolderCount su id inesistente restituisce false', () async {
      expect(await repository.updateFolderCount('ghost', 5), isFalse);
    });

    test('getTotalRecordingCount somma i contatori delle custom', () async {
      await repository.createFolder(
        buildFolder(id: 'f1', name: 'Uno', recordingCount: 3),
      );
      await repository.createFolder(
        buildFolder(id: 'f2', name: 'Due', recordingCount: 4),
      );

      expect(await repository.getTotalRecordingCount(), 7);
    });
  });

  group('FolderRepository — ricerca e ordinamento', () {
    test('searchFolders trova per sottostringa, incluse le default', () async {
      await repository.createFolder(buildFolder(id: 'f1', name: 'Note vocali'));

      final byCustom = await repository.searchFolders('vocali');
      expect(byCustom.map((f) => f.id), ['f1']);

      final byDefault = await repository.searchFolders('recording');
      expect(byDefault.map((f) => f.id), contains('all_recordings'));
    });

    test('getFoldersSorted per nome ordina alfabeticamente', () async {
      await repository.createFolder(buildFolder(id: 'f1', name: 'Zebra'));
      await repository.createFolder(buildFolder(id: 'f2', name: 'Alfa'));

      final sorted =
          await repository.getFoldersSorted(FolderSortCriteria.name);
      final customNames = sorted
          .where((f) => f.type == FolderType.customFolder)
          .map((f) => f.name)
          .toList();

      expect(customNames, ['Alfa', 'Zebra']);
    });
  });

  group('FolderRepository — export/import', () {
    test('exportFolders/importFolders round-trip preserva le cartelle',
        () async {
      await repository.createFolder(buildFolder(id: 'f1', name: 'Backup me'));

      final exported = await repository.exportFolders();
      expect(exported['folders'], hasLength(1));

      await repository.clearCustomFolders();
      expect(await repository.getCustomFolders(), isEmpty);

      final imported = await repository.importFolders(exported);
      expect(imported, isTrue);

      final restored = await repository.getCustomFolders();
      expect(restored.single.name, 'Backup me');
    });

    test('importFolders con dati invalidi restituisce false', () async {
      expect(await repository.importFolders({'wrong': true}), isFalse);
    });

    test('clearCustomFolders svuota solo le custom', () async {
      await repository.createFolder(buildFolder(id: 'f1'));

      expect(await repository.clearCustomFolders(), isTrue);
      expect(await repository.getCustomFolders(), isEmpty);
      expect((await repository.getAllFolders()).length, 3);
    });
  });
}
