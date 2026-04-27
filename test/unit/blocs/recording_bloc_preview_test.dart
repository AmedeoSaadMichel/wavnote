// File: test/unit/blocs/recording_bloc_preview_test.dart
//
// Testa il comportamento di PlayRecordingPreview / StopRecordingPreview.
// Bug fixato: _onStopRecordingPreview non deve eliminare il file preview
// (fix: rimossa f.deleteSync()). Senza il fix, la seconda pressione di Play
// causava ExtAudioFileOpenURL error 2003334207.

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wavnote/core/enums/audio_format.dart';
import 'package:wavnote/domain/repositories/i_audio_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_audio_trimmer_repository.dart';
import 'package:wavnote/domain/repositories/i_location_repository.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart';

// ── Mock ────────────────────────────────────────────────────────────────────

class MockAudioRecordingRepository extends Mock
    implements IAudioRecordingRepository {}

class MockRecordingRepository extends Mock implements IRecordingRepository {}

class MockLocationRepository extends Mock implements ILocationRepository {}

class MockTrimmerRepository extends Mock implements IAudioTrimmerRepository {}

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Crea un file vuoto al [path] indicato.
File _touch(String path) => File(path)..createSync(recursive: true);

// ────────────────────────────────────────────────────────────────────────────

void main() {
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(AudioFormat.m4a);
    tempDir = Directory.systemTemp.createTempSync('wavnote_preview_test_');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('RecordingBloc — StopRecordingPreview / PlayRecordingPreview', () {
    late RecordingBloc bloc;
    late MockAudioRecordingRepository mockAudio;
    late MockTrimmerRepository mockTrimmer;

    // Percorsi assoluti → AppFileUtils.resolve() li restituisce as-is
    late String recordingFilePath;
    late String previewFilePath;
    late RecordingPaused seedState;

    setUp(() {
      mockAudio = MockAudioRecordingRepository();
      mockTrimmer = MockTrimmerRepository();

      // Stub minimi richiesti dal BLoC
      when(() => mockAudio.initialize()).thenAnswer((_) async => true);
      when(() => mockAudio.dispose()).thenAnswer((_) async {});
      when(() => mockAudio.needsDisposal).thenReturn(false);
      when(
        () => mockAudio.getRecordingAmplitudeStream(),
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockAudio.durationStream).thenReturn(null);
      when(
        () => mockAudio.getCurrentRecordingDuration(),
      ).thenAnswer((_) async => Duration.zero);
      when(
        () => mockAudio.getAudioDuration(any()),
      ).thenAnswer((_) async => const Duration(seconds: 10));

      // Crea file reali nel temp dir
      recordingFilePath =
          '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      previewFilePath =
          '${tempDir.path}/recording_preview_${DateTime.now().millisecondsSinceEpoch}.wav';

      _touch(recordingFilePath);
      _touch(previewFilePath);

      seedState = RecordingPaused(
        filePath: recordingFilePath, // path assoluto → resolve() lo passa as-is
        folderId: 'all_recordings',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitRate: 128000,
        duration: const Duration(seconds: 10),
        startTime: DateTime(2026, 4, 27),
        seekBarIndex: 50,
        // seekBasePath null → è una registrazione semplice (senza overdub),
        // ma il previewFilePath può comunque essere impostato.
        previewFilePath: previewFilePath,
        isPlayingPreview: true,
      );

      bloc = RecordingBloc(
        audioService: mockAudio,
        recordingRepository: MockRecordingRepository(),
        locationRepository: MockLocationRepository(),
        trimmerService: mockTrimmer,
      );
    });

    tearDown(() async => bloc.close());

    // ── Test 1: stato corretto dopo StopRecordingPreview ──────────────────

    blocTest<RecordingBloc, RecordingState>(
      'StopRecordingPreview: emette isPlayingPreview=false '
      'e mantiene previewFilePath nello stato',
      build: () => bloc,
      seed: () => seedState,
      act: (b) => b.add(const StopRecordingPreview()),
      expect: () => [
        isA<RecordingPaused>()
            .having(
              (s) => s.isPlayingPreview,
              'isPlayingPreview',
              false,
            )
            .having(
              (s) => s.previewFilePath,
              'previewFilePath',
              previewFilePath, // non deve essere azzerato
            ),
      ],
    );

    // ── Test 2: il file preview NON viene eliminato ───────────────────────

    blocTest<RecordingBloc, RecordingState>(
      'StopRecordingPreview: il file _preview_*.wav non viene eliminato '
      '(fix: rimossa f.deleteSync())',
      build: () => bloc,
      seed: () => seedState,
      act: (b) => b.add(const StopRecordingPreview()),
      verify: (_) {
        expect(
          File(previewFilePath).existsSync(),
          isTrue,
          reason: 'Il file preview non deve essere eliminato dallo stop '
              '— viene eliminato solo al successivo resume/overwrite',
        );
      },
    );

    // ── Test 3: seconda riproduzione — stato corretto ─────────────────────

    blocTest<RecordingBloc, RecordingState>(
      'Stop poi Play: isPlayingPreview torna true e previewFilePath resta valido',
      build: () => bloc,
      seed: () => seedState,
      act: (b) async {
        b.add(const StopRecordingPreview());
        // Breve attesa per garantire la processazione asincrona del primo evento
        await Future<void>.delayed(const Duration(milliseconds: 10));
        b.add(const PlayRecordingPreview());
      },
      expect: () => [
        // Primo evento: stop
        isA<RecordingPaused>().having(
          (s) => s.isPlayingPreview,
          'isPlayingPreview dopo stop',
          false,
        ),
        // Secondo evento: play
        isA<RecordingPaused>()
            .having(
              (s) => s.isPlayingPreview,
              'isPlayingPreview dopo play',
              true,
            )
            .having(
              (s) => s.previewFilePath,
              'previewFilePath dopo play',
              previewFilePath, // file ancora disponibile
            ),
      ],
    );

    // ── Test 4: seekBarIndex aggiornato dopo stop non-naturale ────────────

    blocTest<RecordingBloc, RecordingState>(
      'StopRecordingPreview(stoppedSeekBarIndex): aggiorna seekBarIndex',
      build: () => bloc,
      seed: () => seedState,
      act: (b) => b.add(
        const StopRecordingPreview(
          isNaturalCompletion: false,
          stoppedSeekBarIndex: 33,
        ),
      ),
      expect: () => [
        isA<RecordingPaused>().having(
          (s) => s.seekBarIndex,
          'seekBarIndex',
          33,
        ),
      ],
    );

    // ── Test 5: completamento naturale — seekBarIndex invariato ──────────

    blocTest<RecordingBloc, RecordingState>(
      'StopRecordingPreview(isNaturalCompletion=true): '
      'seekBarIndex rimane al valore seed',
      build: () => bloc,
      seed: () => seedState,
      act: (b) => b.add(
        const StopRecordingPreview(
          isNaturalCompletion: true,
          stoppedSeekBarIndex: 99, // ignorato in natural completion
        ),
      ),
      expect: () => [
        isA<RecordingPaused>().having(
          (s) => s.seekBarIndex,
          'seekBarIndex',
          50, // invariato rispetto al seed
        ),
      ],
    );
  });
}
