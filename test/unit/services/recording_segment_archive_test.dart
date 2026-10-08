import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/domain/repositories/i_audio_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_audio_trimmer_repository.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/services/audio/recording_segment_archive.dart';

class Audio extends Mock implements IAudioRecordingRepository {}

class Trimmer extends Mock implements IAudioTrimmerRepository {}

class Repository extends Mock implements IRecordingRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Audio audio;
  late Trimmer trimmer;
  late Repository repository;
  late RecordingSegmentArchive archive;
  var paths = <String>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wavnote_archive_test_');
    audio = Audio();
    trimmer = Trimmer();
    repository = Repository();
    paths = [];
    when(() => audio.getPausedRecordingPaths()).thenAnswer((_) async => paths);
    when(
      () => audio.getAudioDuration(any()),
    ).thenAnswer((_) async => const Duration(seconds: 5));
    when(
      () => audio.extractRecordingWaveform(any()),
    ).thenAnswer((_) async => []);
    archive = RecordingSegmentArchive(
      audio: audio,
      trimmer: trimmer,
      repository: repository,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
  });
  tearDown(() async {
    await archive.clear();
    await dir.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  Future<void> capture(String source) => archive.capture(
    sourcePath: source,
    duration: const Duration(seconds: 5),
    waveform: [.1, .8, .3],
    sampleRate: 44100,
    folderId: 'all_recordings',
    title: 'Test',
  );

  test(
    'uses the full decoded waveform instead of the truncated live buffer',
    () async {
      final file = File('${dir.path}/full.wav');
      await file.writeAsBytes([1, 2, 3]);
      paths = [file.path];
      final fullWaveform = List<double>.generate(
        4000,
        (i) => i == 0 ? .95 : .2,
      );
      when(
        () => audio.extractRecordingWaveform(any()),
      ).thenAnswer((_) async => fullWaveform);
      await capture(file.path);
      expect(archive.segments.single.recording.waveformData, fullWaveform);
      expect(archive.segments.single.recording.waveformData!.first, .95);
    },
  );

  test(
    'keeps overwritten originals independent from native source deletion',
    () async {
      final first = File('${dir.path}/first.wav');
      await first.writeAsBytes([1, 2, 3]);
      paths = [first.path];
      await capture(first.path);
      final firstSnapshot = archive.segments.single.recording.filePath;
      await first.delete();
      final second = File('${dir.path}/second.wav');
      await second.writeAsBytes([4, 5, 6]);
      paths = [second.path];
      await capture(second.path);
      await second.delete();
      expect(archive.segments.length, 2);
      expect(await File(firstSnapshot).readAsBytes(), [1, 2, 3]);
      expect(
        await File(archive.segments.last.recording.filePath).readAsBytes(),
        [4, 5, 6],
      );
      await archive.clear();
      expect(await File(firstSnapshot).exists(), false);
    },
  );

  test(
    'simple resume updates the same take and includes all native fragments',
    () async {
      final first = File('${dir.path}/first.wav');
      await first.writeAsBytes([1, 2]);
      paths = [first.path];
      await capture(first.path);
      final id = archive.segments.single.recording.id;
      final oldSnapshot = archive.segments.single.recording.filePath;
      final next = File('${dir.path}/next.wav');
      await next.writeAsBytes([3, 4]);
      when(
        () => trimmer.concatenateAudio(
          basePath: any(named: 'basePath'),
          appendPath: any(named: 'appendPath'),
          outputPath: any(named: 'outputPath'),
          format: any(named: 'format'),
        ),
      ).thenAnswer((call) async {
        final base = call.namedArguments[#basePath] as String;
        final append = call.namedArguments[#appendPath] as String;
        final output = call.namedArguments[#outputPath] as String;
        await File(output).writeAsBytes([
          ...await File(base).readAsBytes(),
          ...await File(append).readAsBytes(),
        ]);
      });
      paths = [first.path, next.path];
      await capture(first.path);
      expect(archive.segments.length, 1);
      expect(archive.segments.single.recording.id, id);
      expect(await File(oldSnapshot).exists(), false);
      expect(
        await File(archive.segments.single.recording.filePath).readAsBytes(),
        [1, 2, 3, 4],
      );
    },
  );

  test('saved library file survives session cleanup', () async {
    final source = File('${dir.path}/first.wav');
    await source.writeAsBytes([1, 2, 3]);
    paths = [source.path];
    await capture(source.path);
    registerFallbackValue(archive.segments.single.recording);
    RecordingEntity? inserted;
    when(() => repository.createRecording(any())).thenAnswer((call) async {
      inserted = call.positionalArguments.single as RecordingEntity;
      return inserted!;
    });
    final saved = await archive.save(archive.segments.single);
    await archive.clear();
    expect(saved, inserted);
    expect(saved.waveformData, [.1, .8, .3]);
    expect(saved.filePath.startsWith('recordings/'), true);
    expect(await File('${dir.path}/${saved.filePath}').readAsBytes(), [
      1,
      2,
      3,
    ]);
  });
}
