// File: test/unit/blocs/recording_bloc_overwrite_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:wavnote/domain/entities/recording_session_segment.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';

import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart';
import 'package:wavnote/domain/usecases/recording/overwrite_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/start_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/stop_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/pause_recording_usecase.dart'
    hide RecordingState;
import 'package:wavnote/domain/repositories/i_audio_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_location_repository.dart';
import 'package:wavnote/services/audio/audio_trimmer_service.dart';
import 'package:wavnote/core/enums/audio_format.dart';

import '../../helpers/test_helpers.dart';

class MockAudioService extends Mock implements IAudioRecordingRepository {}

class MockRecordingRepository extends Mock implements IRecordingRepository {}

class MockLocationRepository extends Mock implements ILocationRepository {}

class MockStartUseCase extends Mock implements StartRecordingUseCase {}

class MockStopUseCase extends Mock implements StopRecordingUseCase {}

class MockPauseUseCase extends Mock implements PauseRecordingUseCase {}

class MockOverwriteRecordingUseCase extends Mock
    implements OverwriteRecordingUseCase {}

class MockTrimmerService extends Mock implements AudioTrimmerService {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
    registerFallbackValue(AudioFormat.m4a);
    registerFallbackValue(Duration.zero);
  });

  group('RecordingBloc — OverwriteRecording', () {
    late RecordingBloc bloc;
    late MockAudioService mockAudio;
    late MockRecordingRepository mockLibrary;
    late MockOverwriteRecordingUseCase mockOverwriteUseCase;

    final pausedState = RecordingPaused(
      filePath: '/docs/all_recordings/test_123.m4a',
      folderId: 'all_recordings',
      format: AudioFormat.m4a,
      sampleRate: 44100,
      bitRate: 128000,
      duration: const Duration(seconds: 5),
      startTime: DateTime(2026, 3, 28),
    );

    setUp(() {
      mockAudio = MockAudioService();
      mockLibrary = MockRecordingRepository();
      mockOverwriteUseCase = MockOverwriteRecordingUseCase();

      when(() => mockAudio.initialize()).thenAnswer((_) async => true);
      when(() => mockAudio.dispose()).thenAnswer((_) async {});
      when(() => mockAudio.needsDisposal).thenReturn(false);
      when(
        () => mockAudio.stopRecording(raw: any(named: 'raw')),
      ).thenAnswer((_) async => null);
      when(
        () => mockAudio.getRecordingAmplitudeStream(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockAudio.externalControlStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockAudio.getRecordingWaveformBucketStream(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockAudio.getCurrentRecordingDuration(),
      ).thenAnswer((_) async => Duration.zero);

      bloc = RecordingBloc(
        audioService: mockAudio,
        recordingRepository: mockLibrary,
        locationRepository: MockLocationRepository(),
        startRecordingUseCase: MockStartUseCase(),
        stopRecordingUseCase: MockStopUseCase(),
        pauseRecordingUseCase: MockPauseUseCase(),
        overwriteRecordingUseCase: mockOverwriteUseCase,
        trimmerService: MockTrimmerService(),
      );
    });

    tearDown(() async => bloc.close());

    final savedSegment = RecordingEntity.create(
      name: 'Segmento salvato',
      filePath: '/docs/segment.wav',
      folderId: 'all_recordings',
      format: AudioFormat.wav,
      duration: const Duration(seconds: 5),
      fileSize: 1024,
      sampleRate: 44100,
    );

    blocTest<RecordingBloc, RecordingState>(
      'returning to a folder reloads its list without discarding paused takes or trim state',
      build: () {
        when(
          () => mockLibrary.getRecordingsByFolder('all_recordings'),
        ).thenAnswer((_) async => [savedSegment]);
        return bloc;
      },
      seed: () => pausedState.copyWith(
        seekBarIndex: 23,
        previewFilePath: '/tmp/preview.wav',
        seekBasePath: '/tmp/base.wav',
        overwriteStartTime: const Duration(seconds: 2),
        sessionSegments: [
          RecordingSessionSegment(
            sourcePath: 'take.wav',
            recording: savedSegment,
            colorIndex: 3,
          ),
        ],
      ),
      act: (b) => b.add(const LoadRecordings(folderId: 'all_recordings')),
      expect: () => [
        isA<RecordingPaused>()
            .having((s) => s.recordings, 'library', [savedSegment])
            .having((s) => s.filePath, 'current take', pausedState.filePath)
            .having(
              (s) => s.sessionSegments.single.colorIndex,
              'segment color',
              3,
            )
            .having((s) => s.seekBarIndex, 'seek', 23)
            .having(
              (s) => s.previewFilePath,
              'preview file',
              '/tmp/preview.wav',
            )
            .having((s) => s.seekBasePath, 'trim base', '/tmp/base.wav'),
      ],
    );

    blocTest<RecordingBloc, RecordingState>(
      'a delayed folder reload preserves newer recorder seek changes',
      build: () => bloc,
      seed: () => pausedState,
      act: (b) async {
        final pending = Completer<List<RecordingEntity>>();
        when(
          () => mockLibrary.getRecordingsByFolder('all_recordings'),
        ).thenAnswer((_) => pending.future);
        b.add(const LoadRecordings(folderId: 'all_recordings'));
        await Future<void>.delayed(Duration.zero);
        b.add(const UpdateSeekBarIndex(seekBarIndex: 9));
        await Future<void>.delayed(Duration.zero);
        pending.complete([savedSegment]);
      },
      expect: () => [
        isA<RecordingPaused>().having((s) => s.seekBarIndex, 'seek', 9),
        isA<RecordingPaused>()
            .having((s) => s.seekBarIndex, 'new seek retained', 9)
            .having((s) => s.recordings, 'refreshed library', [savedSegment]),
      ],
    );

    blocTest<RecordingBloc, RecordingState>(
      'a failed folder refresh keeps the paused session intact',
      build: () {
        when(
          () => mockLibrary.getRecordingsByFolder('all_recordings'),
        ).thenThrow(StateError('Database unavailable'));
        return bloc;
      },
      seed: () => pausedState,
      act: (b) => b.add(const LoadRecordings(folderId: 'all_recordings')),
      expect: () => <RecordingState>[],
      verify: (b) => expect(b.state, pausedState),
    );

    blocTest<RecordingBloc, RecordingState>(
      'saving a segment refreshes the library while preserving paused recorder and playhead',
      build: () => bloc,
      seed: () =>
          pausedState.copyWith(seekBarIndex: 23, isPlayingPreview: true),
      act: (b) => b.add(SessionSegmentSaved(savedSegment)),
      expect: () => [
        isA<RecordingPaused>()
            .having((s) => s.recordings, 'background library', [savedSegment])
            .having((s) => s.filePath, 'active recording', pausedState.filePath)
            .having((s) => s.seekBarIndex, 'playhead', 23)
            .having((s) => s.isPlayingPreview, 'preview unchanged', true),
      ],
    );

    blocTest<RecordingBloc, RecordingState>(
      'StartOverwrite success: emits RecordingStarting then RecordingInProgress with overwrite info',
      build: () {
        when(
          () => mockAudio.startRecording(
            filePath: any(named: 'filePath'),
            format: any(named: 'format'),
            sampleRate: any(named: 'sampleRate'),
            bitRate: any(named: 'bitRate'),
            initialElapsedOffset: any(named: 'initialElapsedOffset'),
          ),
        ).thenAnswer((_) async => true);
        return bloc;
      },
      seed: () => pausedState,
      act: (b) => b.add(
        StartOverwrite(
          seekBarIndex: 25, // 2.5 seconds
          waveData: List.generate(50, (_) => 0.5),
        ),
      ),
      expect: () => [
        const RecordingStarting(),
        isA<RecordingInProgress>()
            .having(
              (s) => s.originalFilePathForOverwrite,
              'originalFilePathForOverwrite',
              pausedState.filePath,
            )
            .having(
              (s) => s.overwriteStartTime,
              'overwriteStartTime',
              const Duration(milliseconds: 2500),
            ),
      ],
    );

    blocTest<RecordingBloc, RecordingState>(
      'reproduces bug: waveformDataForPlayer is not truncated after overwrite',
      build: () {
        when(
          () => mockAudio.stopRecording(raw: true),
        ).thenAnswer((_) async => null);
        when(
          () => mockAudio.startRecording(
            filePath: any(named: 'filePath'),
            format: any(named: 'format'),
            sampleRate: any(named: 'sampleRate'),
            bitRate: any(named: 'bitRate'),
            initialElapsedOffset: any(named: 'initialElapsedOffset'),
          ),
        ).thenAnswer((_) async => true);
        return bloc;
      },
      // 1. Start with a 10-second recording (100 waveform points)
      seed: () => RecordingPaused(
        filePath: '/test/file.wav',
        folderId: 'all',
        duration: const Duration(seconds: 10),
        startTime: DateTime.now(),
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitRate: 128000,
      ),
      // 2. Seek back to 2s and start overwriting
      act: (b) => b.add(
        StartOverwrite(
          seekBarIndex: 20, // 2 seconds
          waveData: List.generate(100, (i) => i / 100.0), // 10s of data
        ),
      ),
      expect: () => [
        const RecordingStarting(),
        isA<RecordingInProgress>()
            // 3. Assert that the internal data is correctly truncated
            .having(
              (s) => s.truncatedWaveData?.length,
              'truncatedWaveData length',
              21, // take(20 + 1)
            )
            // 4. Assert that the UI data is NOT truncated (THIS IS THE BUG)
            .having(
              (s) => s.waveformDataForPlayer?.length,
              'waveformDataForPlayer length',
              100,
            ),
      ],
    );
  });
}
