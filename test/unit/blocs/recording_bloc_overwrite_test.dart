// File: test/unit/blocs/recording_bloc_overwrite_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart';
import 'package:wavnote/domain/usecases/recording/overwrite_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/start_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/stop_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/pause_recording_usecase.dart'
    hide RecordingState;
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart'
    hide RecordingState;
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_location_repository.dart';
import 'package:wavnote/services/audio/audio_trimmer_service.dart';
import 'package:wavnote/core/enums/audio_format.dart';

import '../../helpers/test_helpers.dart';

class MockAudioService extends Mock implements IAudioServiceRepository {}

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
  });

  group('RecordingBloc — OverwriteRecording', () {
    late RecordingBloc bloc;
    late MockAudioService mockAudio;
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
      mockOverwriteUseCase = MockOverwriteRecordingUseCase();

      when(() => mockAudio.initialize()).thenAnswer((_) async => true);
      when(() => mockAudio.dispose()).thenAnswer((_) async {});
      when(
        () => mockAudio.getRecordingAmplitudeStream(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockAudio.getCurrentRecordingDuration(),
      ).thenAnswer((_) async => Duration.zero);

      bloc = RecordingBloc(
        audioService: mockAudio,
        recordingRepository: MockRecordingRepository(),
        locationRepository: MockLocationRepository(),
        startRecordingUseCase: MockStartUseCase(),
        stopRecordingUseCase: MockStopUseCase(),
        pauseRecordingUseCase: MockPauseUseCase(),
        overwriteRecordingUseCase: mockOverwriteUseCase,
        trimmerService: MockTrimmerService(),
      );
    });

    tearDown(() async => bloc.close());

    blocTest<RecordingBloc, RecordingState>(
      'StartOverwrite success: emits RecordingStarting then RecordingInProgress with overwrite info',
      build: () {
        when(
          () => mockAudio.startRecording(
            filePath: any(named: 'filePath'),
            format: any(named: 'format'),
            sampleRate: any(named: 'sampleRate'),
            bitRate: any(named: 'bitRate'),
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
