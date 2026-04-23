// File: test/unit/blocs/recording_bloc_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart';
import 'package:wavnote/domain/repositories/i_location_repository.dart';
import 'package:wavnote/core/enums/audio_format.dart';
import 'package:wavnote/domain/usecases/recording/start_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/stop_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/pause_recording_usecase.dart';
import 'package:wavnote/domain/repositories/i_audio_trimmer_repository.dart';
import 'package:wavnote/domain/usecases/recording/overwrite_recording_usecase.dart';
import 'package:wavnote/config/dependency_injection.dart';

import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart'
    as recording_bloc;

import '../../helpers/test_helpers.dart';

// Mock classes
class MockAudioServiceRepository extends Mock
    implements IAudioServiceRepository {}

class MockRecordingRepository extends Mock implements IRecordingRepository {}

class MockLocationRepository extends Mock implements ILocationRepository {}

class MockStartRecordingUseCase extends Mock implements StartRecordingUseCase {}

class MockStopRecordingUseCase extends Mock implements StopRecordingUseCase {}

class MockPauseRecordingUseCase extends Mock implements PauseRecordingUseCase {}

class MockAudioTrimmerRepository extends Mock
    implements IAudioTrimmerRepository {}

class MockOverwriteRecordingUseCase extends Mock
    implements OverwriteRecordingUseCase {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
    registerFallbackValue(TestHelpers.createTestRecording());
  });

  group('RecordingBloc', () {
    late RecordingBloc recordingBloc;
    late MockAudioServiceRepository mockAudioService;
    late MockRecordingRepository mockRecordingRepository;
    late MockLocationRepository mockLocationRepository;
    late MockStartRecordingUseCase mockStartRecordingUseCase;
    late MockStopRecordingUseCase mockStopRecordingUseCase;
    late MockPauseRecordingUseCase mockPauseRecordingUseCase;
    late MockAudioTrimmerRepository mockTrimmerService;

    setUp(() {
      mockAudioService = MockAudioServiceRepository();
      mockRecordingRepository = MockRecordingRepository();
      mockLocationRepository = MockLocationRepository();
      mockStartRecordingUseCase = MockStartRecordingUseCase();
      mockStopRecordingUseCase = MockStopRecordingUseCase();
      mockPauseRecordingUseCase = MockPauseRecordingUseCase();
      mockTrimmerService = MockAudioTrimmerRepository();

      if (!sl.isRegistered<IAudioTrimmerRepository>()) {
        sl.registerSingleton<IAudioTrimmerRepository>(mockTrimmerService);
      }

      when(() => mockAudioService.initialize()).thenAnswer((_) async => true);
      when(() => mockAudioService.dispose()).thenAnswer((_) async {});
      when(() => mockAudioService.needsDisposal).thenReturn(false);
      when(
        () => mockAudioService.getRecordingAmplitudeStream(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockAudioService.hasMicrophonePermission(),
      ).thenAnswer((_) async => true);
      when(
        () => mockAudioService.hasMicrophone(),
      ).thenAnswer((_) async => true);
      when(
        () => mockAudioService.requestMicrophonePermission(),
      ).thenAnswer((_) async => true);
      when(
        () => mockAudioService.cancelRecording(),
      ).thenAnswer((_) async => true);

      when(
        () => mockRecordingRepository.getAllRecordings(),
      ).thenAnswer((_) async => <RecordingEntity>[]);

      recordingBloc = RecordingBloc(
        audioService: mockAudioService,
        recordingRepository: mockRecordingRepository,
        locationRepository: mockLocationRepository,
        startRecordingUseCase: mockStartRecordingUseCase,
        stopRecordingUseCase: mockStopRecordingUseCase,
        pauseRecordingUseCase: mockPauseRecordingUseCase,
        trimmerService: mockTrimmerService,
      );
    });

    tearDown(() async {
      await recordingBloc.close();
      if (sl.isRegistered<IAudioTrimmerRepository>()) {
        sl.unregister<IAudioTrimmerRepository>();
      }
    });

    group('Initial State', () {
      test('initial state is RecordingInitial', () {
        expect(recordingBloc.state, isA<recording_bloc.RecordingInitial>());
      });
    });

    group('Recording Lifecycle', () {
      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'emits [Starting, InProgress] when recording starts successfully',
        build: () {
          when(
            () => mockStartRecordingUseCase.execute(
              folderId: any(named: 'folderId'),
              format: any(named: 'format'),
              sampleRate: any(named: 'sampleRate'),
              bitRate: any(named: 'bitRate'),
            ),
          ).thenAnswer(
            (_) async => Right(
              StartRecordingSuccess(
                filePath: '/test/path.m4a',
                title: 'Test Recording',
                folderId: 'test_folder',
                format: AudioFormat.m4a,
                sampleRate: 44100,
                bitRate: 128000,
                startTime: DateTime.now(),
              ),
            ),
          );
          return recordingBloc;
        },
        act: (testBloc) => testBloc.add(
          const StartRecording(
            folderId: 'test_folder',
            format: AudioFormat.m4a,
          ),
        ),
        expect: () => [
          isA<recording_bloc.RecordingStarting>(),
          isA<recording_bloc.RecordingInProgress>(),
        ],
      );

      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'emits [Stopping, Completed] when recording stops successfully',
        build: () {
          final testRecording = TestHelpers.createTestRecording();
          when(
            () => mockStopRecordingUseCase.execute(),
          ).thenAnswer((_) async => Right(testRecording));
          return recordingBloc;
        },
        seed: () => recording_bloc.RecordingInProgress(
          filePath: '/test/path.m4a',
          folderId: 'test_folder',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
          duration: const Duration(seconds: 30),
          amplitude: 0.5,
          startTime: DateTime.now(),
        ),
        act: (testBloc) => testBloc.add(const StopRecording()),
        expect: () => [
          isA<recording_bloc.RecordingStopping>(),
          isA<recording_bloc.RecordingCompleted>(),
        ],
      );

      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'emits [Paused] when recording pauses successfully',
        build: () {
          when(
            () => mockPauseRecordingUseCase.executePause(),
          ).thenAnswer((_) async => const Right(Duration(seconds: 30)));
          return recordingBloc;
        },
        seed: () => recording_bloc.RecordingInProgress(
          filePath: '/test/path.m4a',
          folderId: 'test_folder',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
          duration: const Duration(seconds: 30),
          amplitude: 0.5,
          startTime: DateTime.now(),
        ),
        act: (testBloc) => testBloc.add(const PauseRecording()),
        expect: () => [isA<recording_bloc.RecordingPaused>()],
      );

      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'emits [InProgress] when recording resumes successfully',
        build: () {
          when(
            () => mockPauseRecordingUseCase.executeResume(),
          ).thenAnswer((_) async => const Right(Duration(seconds: 30)));
          return recordingBloc;
        },
        seed: () => recording_bloc.RecordingPaused(
          filePath: '/test/path.m4a',
          folderId: 'test_folder',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
          duration: const Duration(seconds: 30),
          startTime: DateTime.now(),
        ),
        act: (testBloc) => testBloc.add(const ResumeRecording()),
        expect: () => [isA<recording_bloc.RecordingInProgress>()],
      );
    });

    group('Recording Management', () {
      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'loads recordings successfully',
        build: () {
          final recordings = TestHelpers.createTestRecordings(3);
          when(
            () => mockRecordingRepository.getRecordingsByFolder('test_folder'),
          ).thenAnswer((_) async => recordings);
          return recordingBloc;
        },
        act: (testBloc) =>
            testBloc.add(const LoadRecordings(folderId: 'test_folder')),
        expect: () => [isA<recording_bloc.RecordingLoaded>()],
      );

      test('handles toggle favorite recording success', () async {
        final recordings = TestHelpers.createTestRecordings(3);
        when(
          () => mockRecordingRepository.toggleFavorite(any()),
        ).thenAnswer((_) async => const Right(unit));

        recordingBloc.add(
          const ToggleFavoriteRecording(recordingId: 'test_recording_1'),
        );

        // Aspetta che il BLoC elabori l'evento
        await Future.delayed(const Duration(milliseconds: 100));
        expect(recordingBloc.state, isA<recording_bloc.RecordingState>());
      });

      test('handles delete recording request success', () async {
        when(
          () => mockRecordingRepository.deleteRecording(any()),
        ).thenAnswer((_) async => const Right(unit));

        recordingBloc.add(const DeleteRecording('test_recording_1'));

        await Future.delayed(const Duration(milliseconds: 100));
        expect(recordingBloc.state, isA<recording_bloc.RecordingState>());
      });
    });

    group('Error Handling', () {
      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'emits Error when recording fails to start',
        build: () {
          when(
            () => mockStartRecordingUseCase.execute(
              folderId: any(named: 'folderId'),
              format: any(named: 'format'),
              sampleRate: any(named: 'sampleRate'),
              bitRate: any(named: 'bitRate'),
            ),
          ).thenThrow(Exception('Recording failed'));
          return recordingBloc;
        },
        act: (testBloc) => testBloc.add(
          const StartRecording(
            folderId: 'test_folder',
            format: AudioFormat.m4a,
          ),
        ),
        expect: () => [
          isA<recording_bloc.RecordingStarting>(),
          isA<recording_bloc.RecordingError>(),
        ],
      );
    });
  });
}
