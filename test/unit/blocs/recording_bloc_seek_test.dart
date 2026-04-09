// File: test/unit/blocs/recording_bloc_seek_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart';
import 'package:wavnote/domain/usecases/recording/seek_and_resume_usecase.dart';
import 'package:wavnote/domain/usecases/recording/start_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/stop_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/pause_recording_usecase.dart' hide RecordingState;
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart' hide RecordingState;
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_location_repository.dart';
import 'package:wavnote/services/audio/audio_trimmer_service.dart';
import 'package:wavnote/core/enums/audio_format.dart';
import 'package:wavnote/core/errors/failures.dart';

import '../../helpers/test_helpers.dart';

class MockAudioService extends Mock implements IAudioServiceRepository {}
class MockRecordingRepository extends Mock implements IRecordingRepository {}
class MockLocationRepository extends Mock implements ILocationRepository {}
class MockStartUseCase extends Mock implements StartRecordingUseCase {}
class MockStopUseCase extends Mock implements StopRecordingUseCase {}
class MockPauseUseCase extends Mock implements PauseRecordingUseCase {}
class MockSeekAndResumeUseCase extends Mock implements SeekAndResumeUseCase {}
class MockTrimmerService extends Mock implements AudioTrimmerService {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
    registerFallbackValue(AudioFormat.m4a);
  });

  group('RecordingBloc — SeekAndResumeRecording', () {
    late RecordingBloc bloc;
    late MockAudioService mockAudio;
    late MockRecordingRepository mockRepo;
    late MockSeekAndResumeUseCase mockSeekUseCase;
    late MockTrimmerService mockTrimmer;

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
      mockRepo = MockRecordingRepository();
      mockSeekUseCase = MockSeekAndResumeUseCase();
      mockTrimmer = MockTrimmerService();

      when(() => mockAudio.initialize()).thenAnswer((_) async => true);
      when(() => mockAudio.dispose()).thenAnswer((_) async {});
      when(() => mockAudio.getRecordingAmplitudeStream())
          .thenAnswer((_) => const Stream.empty());
      when(() => mockAudio.getCurrentRecordingDuration())
          .thenAnswer((_) async => Duration.zero);

      bloc = RecordingBloc(
        audioService: mockAudio,
        recordingRepository: mockRepo,
        locationRepository: MockLocationRepository(),
        startRecordingUseCase: MockStartUseCase(),
        stopRecordingUseCase: MockStopUseCase(),
        pauseRecordingUseCase: MockPauseUseCase(),
        seekAndResumeUseCase: mockSeekUseCase,
        trimmerService: mockTrimmer,
      );
    });

    tearDown(() async => bloc.close());

    blocTest<RecordingBloc, RecordingState>(
      'SeekAndResumeRecording successo: emette RecordingStarting poi RecordingInProgress',
      build: () {
        when(() => mockSeekUseCase.execute(
          filePath: any(named: 'filePath'),
          seekBarIndex: any(named: 'seekBarIndex'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
          waveData: any(named: 'waveData'),
        )).thenAnswer((_) async => Right(SeekAndResumeResult(
          seekBasePath: '/docs/all_recordings/test_123_base.m4a',
          truncatedWaveData: List.generate(40, (_) => 0.5),
        )));
        return bloc;
      },
      seed: () => pausedState,
      act: (b) => b.add(SeekAndResumeRecording(
        seekBarIndex: 40,
        filePath: pausedState.filePath,
        format: pausedState.format,
        sampleRate: pausedState.sampleRate,
        bitRate: pausedState.bitRate,
        waveData: List.generate(100, (_) => 0.5),
      )),
      expect: () => [
        const RecordingStarting(),
        isA<RecordingInProgress>()
            .having((s) => s.seekBasePath, 'seekBasePath', isNotNull)
            .having((s) => s.duration.inMilliseconds, 'duration', 2000), // 40 * 50
      ],
    );

    blocTest<RecordingBloc, RecordingState>(
      'SeekAndResumeRecording errore: emette RecordingError',
      build: () {
        when(() => mockSeekUseCase.execute(
          filePath: any(named: 'filePath'),
          seekBarIndex: any(named: 'seekBarIndex'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
          waveData: any(named: 'waveData'),
        )).thenAnswer((_) async =>
            Left(AudioRecordingFailure.startFailed('trim error')));
        return bloc;
      },
      seed: () => pausedState,
      act: (b) => b.add(SeekAndResumeRecording(
        seekBarIndex: 40,
        filePath: pausedState.filePath,
        format: pausedState.format,
        sampleRate: pausedState.sampleRate,
        bitRate: pausedState.bitRate,
        waveData: List.generate(100, (_) => 0.5),
      )),
      expect: () => [
        const RecordingStarting(),
        isA<RecordingError>(),
      ],
    );
  });
}
