import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/services/file/voice_memo_import_service.dart';
import '../../helpers/test_helpers.dart';

class _Repository extends Mock implements IRecordingRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late _Repository repository;
  late List<Map<String, dynamic>> entries;
  late List<RecordingEntity> saved;

  setUpAll(() => registerFallbackValue(TestHelpers.createTestRecording()));
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('voice-memo-test');
    repository = _Repository();
    entries = [];
    saved = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temporary.path,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          VoiceMemoImportService.channel,
          (_) async => entries,
        );
    when(() => repository.createRecording(any())).thenAnswer((call) async {
      final recording = call.positionalArguments.first as RecordingEntity;
      saved.add(recording);
      return recording;
    });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(VoiceMemoImportService.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await temporary.delete(recursive: true);
  });

  Future<File> stage(String id) async {
    final folder = await Directory(
      '${temporary.path}/wavnote-import-$id',
    ).create();
    final file = await File('${folder.path}/Memo.m4a').writeAsBytes([
      0,
      0,
      0,
      24,
      102,
      116,
      121,
      112,
      77,
      52,
      65,
      32,
      0,
      0,
      0,
      0,
    ]);
    entries.add({
      'path': file.path,
      'name': 'Memo',
      'durationMs': 1234,
      'sampleRate': 48000,
      'createdAtMs': 1700000000000,
    });
    return file;
  }

  test(
    'imports same-name memos with unique files and original metadata',
    () async {
      final first = await stage('first');
      await stage('second');
      final progress = <int>[];
      final result = await VoiceMemoImportService(repository).import(
        folder: TestHelpers.createTestFolder(),
        onProgress: (done, total) => progress.add(done),
      );
      expect(result.failures, isEmpty);
      expect(result.imported, 2);
      expect(saved.map((r) => r.filePath).toSet().length, 2);
      expect(saved.first.name, 'Memo');
      expect(saved.first.duration, const Duration(milliseconds: 1234));
      expect(saved.first.sampleRate, 48000);
      expect(saved.first.createdAt.millisecondsSinceEpoch, 1700000000000);
      expect(await first.parent.exists(), isFalse);
      expect(progress, [0, 1, 2]);
    },
  );

  test('database failure cleans copied file and continues the batch', () async {
    await stage('failed');
    await stage('success');
    entries.add({'name': 'Corrupted', 'error': 'Unreadable audio'});
    var attempts = 0;
    when(() => repository.createRecording(any())).thenAnswer((call) async {
      if (attempts++ == 0) throw StateError('Database unavailable');
      return call.positionalArguments.first as RecordingEntity;
    });
    final result = await VoiceMemoImportService(
      repository,
    ).import(folder: TestHelpers.createTestFolder());
    expect(result.imported, 1);
    expect(result.failures.length, 2);
    final files = await temporary
        .list(recursive: true)
        .where((entity) => entity is File)
        .toList();
    expect(files.length, 1);
  });

  test('cancelling selection leaves the library unchanged', () async {
    final result = await VoiceMemoImportService(
      repository,
    ).import(folder: TestHelpers.createTestFolder());
    expect(result.imported, 0);
    expect(result.failures, isEmpty);
    verifyNever(() => repository.createRecording(any()));
  });
  test(
    'shared files are acknowledged only after persistence; failures remain for retry',
    () async {
      final first = await stage('shared-first');
      await stage('shared-failed');
      entries[0]['entryId'] = 'first';
      entries[1]['entryId'] = 'failed';
      // Durable shared sources do not live in the document-picker staging area.
      final shared = await Directory('${temporary.path}/inbox').create();
      for (final entry in entries) {
        final source = File(entry['path'] as String);
        final copied = await source.copy(
          '${shared.path}/${entry['entryId']}.m4a',
        );
        entry['path'] = copied.path;
      }
      final acknowledgements = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VoiceMemoImportService.channel, (
            call,
          ) async {
            if (call.method == 'pendingSharedAudio') return entries;
            if (call.method == 'acknowledgeSharedAudio') {
              acknowledgements.addAll(
                List<String>.from(call.arguments['ids'] as List),
              );
              expect(saved.length, 1); // The database commit precedes cleanup.
            }
            return null;
          });
      when(
        () => repository.getRecordingById(any()),
      ).thenAnswer((_) async => null);
      when(() => repository.createRecording(any())).thenAnswer((call) async {
        final recording = call.positionalArguments.first as RecordingEntity;
        if (recording.id == 'shared_failed') {
          throw StateError('Database failed');
        }
        saved.add(recording);
        return recording;
      });
      final result = await VoiceMemoImportService(
        repository,
      ).importPendingSharedAudio(folder: TestHelpers.createTestFolder());
      expect(result.imported, 1);
      expect(result.failures.length, 1);
      expect(acknowledgements, ['first']);
      expect(saved.single.id, 'shared_first');
      expect(await File(entries[1]['path'] as String).exists(), isTrue);
      expect(await first.exists(), isTrue);
    },
  );

  test(
    'retry after a commit does not duplicate a shared recording, even if metadata is unreadable',
    () async {
      entries.add({
        'entryId': 'committed',
        'name': 'Memo',
        'error': 'Unreadable audio',
      });
      when(() => repository.getRecordingById('shared_committed')).thenAnswer(
        (_) async => TestHelpers.createTestRecording(id: 'shared_committed'),
      );
      final acknowledged = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VoiceMemoImportService.channel, (
            call,
          ) async {
            if (call.method == 'pendingSharedAudio') return entries;
            acknowledged.addAll(
              List<String>.from(call.arguments['ids'] as List),
            );
            return null;
          });
      final result = await VoiceMemoImportService(
        repository,
      ).importPendingSharedAudio(folder: TestHelpers.createTestFolder());
      expect(result.imported, 0);
      expect(result.failures, isEmpty);
      expect(acknowledged, ['committed']);
      verifyNever(() => repository.createRecording(any()));
    },
  );

}
