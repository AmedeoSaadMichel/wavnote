// File: test/unit/blocs/recording_lifecycle_bloc_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wavnote/presentation/bloc/recording_lifecycle/recording_lifecycle_bloc.dart';
import 'package:wavnote/domain/usecases/recording/recording_lifecycle_usecase.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/core/enums/audio_format.dart';

class MockRecordingLifecycleUseCase extends Mock implements RecordingLifecycleUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(AudioFormat.m4a);
    registerFallbackValue(const Duration(seconds: 30));
    registerFallbackValue(DateTime(2023, 1, 1));
  });

  group('RecordingLifecycleBloc', () {
    late RecordingLifecycleBloc bloc;
    late MockRecordingLifecycleUseCase mockUseCase;

    setUp(() {
      mockUseCase = MockRecordingLifecycleUseCase();
      // Setup default mock behaviors
      when(() => mockUseCase.initializeAudioService()).thenAnswer((_) async => true);
      when(() => mockUseCase.dispose()).thenAnswer((_) async {});
      when(() => mockUseCase.amplitudeStream).thenReturn(null);
      when(() => mockUseCase.durationStream).thenReturn(null);
      
      bloc = RecordingLifecycleBloc(useCase: mockUseCase);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is RecordingLifecycleInitial', () {
      expect(bloc.state, equals(const RecordingLifecycleInitial()));
    });

    group('StartRecording', () {
      const testEvent = StartRecording(
        filePath: '/test/path/recording.m4a',
        folderId: 'test_folder',
        format: AudioFormat.m4a,
      );

      blocTest<RecordingLifecycleBloc, RecordingLifecycleState>(
        'emits [Starting, InProgress] when recording starts successfully',
        build: () {
          when(() => mockUseCase.canStartRecording()).thenAnswer((_) async => true);
          when(() => mockUseCase.generateRecordingTitle()).thenAnswer((_) async => 'Test Recording');
          when(() => mockUseCase.startRecording(
            filePath: any(named: 'filePath'),
            format: any(named: 'format'),
            sampleRate: any(named: 'sampleRate'),
            bitRate: any(named: 'bitRate'),
          )).thenAnswer((_) async => true);
          when(() => mockUseCase.amplitudeStream).thenReturn(null);
          return bloc;
        },
        act: (bloc) => bloc.add(testEvent),
        expect: () => [
          const RecordingLifecycleStarting(),
          isA<RecordingLifecycleInProgress>()
            .having((state) => state.filePath, 'filePath', '/test/path/recording.m4a')
            .having((state) => state.folderId, 'folderId', 'test_folder')
            .having((state) => state.title, 'title', 'Test Recording'),
        ],
        verify: (_) {
          verify(() => mockUseCase.canStartRecording()).called(1);
          verify(() => mockUseCase.generateRecordingTitle()).called(1);
          verify(() => mockUseCase.startRecording(
            filePath: '/test/path/recording.m4a',
            format: AudioFormat.m4a,
            sampleRate: 44100,
            bitRate: 128000,
          )).called(1);
        },
      );

      blocTest<RecordingLifecycleBloc, RecordingLifecycleState>(
        'emits [Starting, Error] when permission denied',
        build: () {
          when(() => mockUseCase.canStartRecording()).thenAnswer((_) async => false);
          return bloc;
        },
        act: (bloc) => bloc.add(testEvent),
        expect: () => [
          const RecordingLifecycleStarting(),
          const RecordingLifecycleError('Microphone permission required'),
        ],
        verify: (_) {
          verify(() => mockUseCase.canStartRecording()).called(1);
          verifyNever(() => mockUseCase.startRecording(
            filePath: any(named: 'filePath'),
            format: any(named: 'format'),
            sampleRate: any(named: 'sampleRate'),
            bitRate: any(named: 'bitRate'),
          ));
        },
      );

      blocTest<RecordingLifecycleBloc, RecordingLifecycleState>(
        'emits [Starting, Error] when recording start fails',
        build: () {
          when(() => mockUseCase.canStartRecording()).thenAnswer((_) async => true);
          when(() => mockUseCase.generateRecordingTitle()).thenAnswer((_) async => 'Test Recording');
          when(() => mockUseCase.startRecording(
            filePath: any(named: 'filePath'),
            format: any(named: 'format'),
            sampleRate: any(named: 'sampleRate'),
            bitRate: any(named: 'bitRate'),
          )).thenAnswer((_) async => false);
          return bloc;
        },
        act: (bloc) => bloc.add(testEvent),
        expect: () => [
          const RecordingLifecycleStarting(),
          const RecordingLifecycleError('Failed to start recording'),
        ],
      );
    });

    group('StopRecording', () {
      blocTest<RecordingLifecycleBloc, RecordingLifecycleState>(
        'emits [Stopping, Completed] when recording stops successfully',
        build: () {
          when(() => mockUseCase.stopRecording()).thenAnswer((_) async => '/test/saved.m4a');
          when(() => mockUseCase.saveRecording(
            filePath: any(named: 'filePath'),
            title: any(named: 'title'),
            duration: any(named: 'duration'),
            folderId: any(named: 'folderId'),
            startTime: any(named: 'startTime'),
            format: any(named: 'format'),
            sampleRate: any(named: 'sampleRate'),
            bitRate: any(named: 'bitRate'),
          )).thenAnswer((_) async => RecordingEntity(
            id: 'test_id',
            name: 'Test Recording',
            filePath: '/test/saved.m4a',
            duration: const Duration(seconds: 30),
            folderId: 'test_folder',
            createdAt: DateTime.now(),
            format: AudioFormat.m4a,
            sampleRate: 44100,
            fileSize: 1024,
            isFavorite: false,
          ));
          return bloc;
        },
        seed: () => RecordingLifecycleInProgress(
          filePath: '/test/recording.m4a',
          folderId: 'test_folder',
          folderName: 'Test Folder',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
          duration: const Duration(seconds: 30),
          amplitude: 0.5,
          startTime: DateTime(2023, 1, 1),
          title: 'Test Recording',
        ),
        act: (bloc) => bloc.add(const StopRecording(title: 'Final Title')),
        expect: () => [
          const RecordingLifecycleStopping(),
          isA<RecordingLifecycleCompleted>()
            .having((state) => state.recording.name, 'recording.name', 'Final Title')
            .having((state) => state.recording.filePath, 'recording.filePath', '/test/saved.m4a'),
        ],
        verify: (_) {
          verify(() => mockUseCase.stopRecording()).called(1);
          verify(() => mockUseCase.saveRecording(
            filePath: '/test/saved.m4a',
            title: 'Final Title',
            duration: const Duration(seconds: 30),
            folderId: 'test_folder',
            startTime: any(named: 'startTime'),
            format: AudioFormat.m4a,
            sampleRate: 44100,
            bitRate: 128000,
          )).called(1);
        },
      );

      blocTest<RecordingLifecycleBloc, RecordingLifecycleState>(
        'emits [Stopping, Error] when stop recording fails',
        build: () {
          when(() => mockUseCase.stopRecording()).thenAnswer((_) async => null);
          return bloc;
        },
        seed: () => RecordingLifecycleInProgress(
          filePath: '/test/recording.m4a',
          folderId: 'test_folder',
          folderName: 'Test Folder',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
          duration: const Duration(seconds: 30),
          amplitude: 0.5,
          startTime: DateTime(2023, 1, 1),
          title: 'Test Recording',
        ),
        act: (bloc) => bloc.add(const StopRecording()),
        expect: () => [
          const RecordingLifecycleStopping(),
          const RecordingLifecycleError('Failed to stop recording'),
        ],
      );
    });

    group('PauseRecording', () {
      blocTest<RecordingLifecycleBloc, RecordingLifecycleState>(
        'emits Paused when pause succeeds',
        build: () {
          when(() => mockUseCase.pauseRecording()).thenAnswer((_) async => true);
          return bloc;
        },
        seed: () => RecordingLifecycleInProgress(
          filePath: '/test/recording.m4a',
          folderId: 'test_folder',
          folderName: 'Test Folder',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
          duration: const Duration(seconds: 30),
          amplitude: 0.5,
          startTime: DateTime(2023, 1, 1),
          title: 'Test Recording',
        ),
        act: (bloc) => bloc.add(const PauseRecording()),
        expect: () => [
          isA<RecordingLifecyclePaused>()
            .having((state) => state.filePath, 'filePath', '/test/recording.m4a')
            .having((state) => state.duration, 'duration', const Duration(seconds: 30)),
        ],
        verify: (_) {
          verify(() => mockUseCase.pauseRecording()).called(1);
        },
      );

      blocTest<RecordingLifecycleBloc, RecordingLifecycleState>(
        'emits Error when pause fails',
        build: () {
          when(() => mockUseCase.pauseRecording()).thenAnswer((_) async => false);
          return bloc;
        },
        seed: () => RecordingLifecycleInProgress(
          filePath: '/test/recording.m4a',
          folderId: 'test_folder',
          folderName: 'Test Folder',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
          duration: const Duration(seconds: 30),
          amplitude: 0.5,
          startTime: DateTime(2023, 1, 1),
          title: 'Test Recording',
        ),
        act: (bloc) => bloc.add(const PauseRecording()),
        expect: () => [
          const RecordingLifecycleError('Failed to pause recording'),
        ],
      );
    });

    group('CancelRecording', () {
      blocTest<RecordingLifecycleBloc, RecordingLifecycleState>(
        'emits Cancelled when cancel succeeds',
        build: () {
          when(() => mockUseCase.cancelRecording()).thenAnswer((_) async {});
          return bloc;
        },
        seed: () => RecordingLifecycleInProgress(
          filePath: '/test/recording.m4a',
          folderId: 'test_folder',
          folderName: 'Test Folder',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
          duration: const Duration(seconds: 30),
          amplitude: 0.5,
          startTime: DateTime(2023, 1, 1),
          title: 'Test Recording',
        ),
        act: (bloc) => bloc.add(const CancelRecording()),
        expect: () => [
          const RecordingLifecycleCancelled(),
        ],
        verify: (_) {
          verify(() => mockUseCase.cancelRecording()).called(1);
        },
      );
    });
  });
}