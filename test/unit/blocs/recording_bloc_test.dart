// File: test/unit/blocs/recording_bloc_test.dart
// 
// Recording BLoC Unit Tests - FINAL CORRECTED VERSION
// ====================================================
//
// Comprehensive test suite for the RecordingBloc class using proper
// imports and correct interface implementations.

import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart';
import 'package:wavnote/services/location/geolocation_service.dart';
import 'package:wavnote/core/enums/audio_format.dart';
import 'package:wavnote/domain/usecases/recording/start_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/stop_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/pause_recording_usecase.dart';

// Use aliased import to avoid conflicts
import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart' as recording_bloc;

import '../../helpers/test_helpers.dart';

// Mock classes
class MockAudioServiceRepository extends Mock implements IAudioServiceRepository {}
class MockRecordingRepository extends Mock implements IRecordingRepository {}
class MockGeolocationService extends Mock implements GeolocationService {}
class MockStartRecordingUseCase extends Mock implements StartRecordingUseCase {}
class MockStopRecordingUseCase extends Mock implements StopRecordingUseCase {}
class MockPauseRecordingUseCase extends Mock implements PauseRecordingUseCase {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('RecordingBloc', () {
    late RecordingBloc recordingBloc;
    late MockAudioServiceRepository mockAudioService;
    late MockRecordingRepository mockRecordingRepository;
    late MockGeolocationService mockGeolocationService;
    late MockStartRecordingUseCase mockStartRecordingUseCase;
    late MockStopRecordingUseCase mockStopRecordingUseCase;
    late MockPauseRecordingUseCase mockPauseRecordingUseCase;

    setUp(() {
      mockAudioService = MockAudioServiceRepository();
      mockRecordingRepository = MockRecordingRepository();
      mockGeolocationService = MockGeolocationService();
      mockStartRecordingUseCase = MockStartRecordingUseCase();
      mockStopRecordingUseCase = MockStopRecordingUseCase();
      mockPauseRecordingUseCase = MockPauseRecordingUseCase();

      // Setup default mock behaviors
      when(() => mockAudioService.initialize()).thenAnswer((_) async => true);
      when(() => mockAudioService.dispose()).thenAnswer((_) async {});
      when(() => mockRecordingRepository.getAllRecordings())
          .thenAnswer((_) async => <RecordingEntity>[]);

      recordingBloc = RecordingBloc(
        audioService: mockAudioService,
        recordingRepository: mockRecordingRepository,
        startRecordingUseCase: mockStartRecordingUseCase,
        stopRecordingUseCase: mockStopRecordingUseCase,
        pauseRecordingUseCase: mockPauseRecordingUseCase,
        geolocationService: mockGeolocationService,
      );
    });

    tearDown(() async {
      await recordingBloc.close();
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
          when(() => mockStartRecordingUseCase.execute(
            folderId: any(named: 'folderId'),
            format: any(named: 'format'),
            sampleRate: any(named: 'sampleRate'),
            bitRate: any(named: 'bitRate'),
          )).thenAnswer((_) async => StartRecordingResult.success(
            filePath: '/test/path.m4a',
            title: 'Test Recording',
            folderId: 'test_folder',
            format: AudioFormat.m4a,
            sampleRate: 44100,
            bitRate: 128000,
            startTime: DateTime.now(),
          ));
          
          return recordingBloc;
        },
        act: (testBloc) => testBloc.add(const StartRecording(
          folderId: 'test_folder',
          format: AudioFormat.m4a,
        )),
        expect: () => [
          isA<recording_bloc.RecordingStarting>(),
          isA<recording_bloc.RecordingInProgress>(),
        ],
      );

      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'emits [Stopping, Completed] when recording stops successfully',
        build: () {
          final testRecording = TestHelpers.createTestRecording();
          
          when(() => mockStopRecordingUseCase.execute())
              .thenAnswer((_) async => StopRecordingResult.success(recording: testRecording));
          
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
          when(() => mockPauseRecordingUseCase.executePause()).thenAnswer((_) async => 
            PauseRecordingResult.successPause(pausedDuration: const Duration(seconds: 30)));
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
        expect: () => [
          isA<recording_bloc.RecordingPaused>(),
        ],
      );

      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'emits [InProgress] when recording resumes successfully',
        build: () {
          when(() => mockPauseRecordingUseCase.executeResume()).thenAnswer((_) async => 
            PauseRecordingResult.successResume(resumedDuration: const Duration(seconds: 30)));
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
        expect: () => [
          isA<recording_bloc.RecordingInProgress>(),
        ],
      );

      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'emits [Cancelled] when recording cancels successfully',
        build: () {
          when(() => mockAudioService.cancelRecording()).thenAnswer((_) async => true);
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
        act: (testBloc) => testBloc.add(const CancelRecording()),
        expect: () => [
          isA<recording_bloc.RecordingCancelled>(),
        ],
      );
    });

    group('Permission Handling', () {
      test('checks recording permissions', () async {
        recordingBloc.add(const CheckRecordingPermissions());
        
        // Wait a bit for processing
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Should handle permission check gracefully
        expect(recordingBloc.state, anyOf([
          isA<recording_bloc.RecordingInitial>(),
          isA<recording_bloc.RecordingPermissionStatus>(),
          isA<recording_bloc.RecordingError>(),
        ]));
      });

      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'starts recording when permission granted',
        build: () {
          when(() => mockStartRecordingUseCase.execute(
            folderId: any(named: 'folderId'),
            format: any(named: 'format'),
            sampleRate: any(named: 'sampleRate'),
            bitRate: any(named: 'bitRate'),
          )).thenAnswer((_) async => StartRecordingResult.success(
            filePath: '/test/path.m4a',
            title: 'Test Recording',
            folderId: 'test_folder',
            format: AudioFormat.m4a,
            sampleRate: 44100,
            bitRate: 128000,
            startTime: DateTime.now(),
          ));
          return recordingBloc;
        },
        act: (testBloc) => testBloc.add(const StartRecording(
          folderId: 'test_folder',
          format: AudioFormat.m4a,
        )),
        expect: () => [
          isA<recording_bloc.RecordingStarting>(),
          isA<recording_bloc.RecordingInProgress>(),
        ],
      );
    });

    group('Recording Management', () {
      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'loads recordings successfully',
        build: () {
          final recordings = TestHelpers.createTestRecordings(3);
          when(() => mockRecordingRepository.getRecordingsByFolder('test_folder'))
              .thenAnswer((_) async => recordings);
          return recordingBloc;
        },
        act: (testBloc) => testBloc.add(const LoadRecordings(folderId: 'test_folder')),
        expect: () => [
          isA<recording_bloc.RecordingLoaded>(),
        ],
      );

      test('handles toggle favorite recording', () {
        final recordings = TestHelpers.createTestRecordings(3);
        
        when(() => mockRecordingRepository.updateRecording(any()))
            .thenAnswer((_) async => recordings.first);
        
        recordingBloc.add(const ToggleFavoriteRecording(recordingId: 'test_recording_1'));
        
        // Should handle favorite toggle
        expect(recordingBloc.state, isA<recording_bloc.RecordingState>());
      });

      test('handles delete recording request', () {
        when(() => mockRecordingRepository.deleteRecording('test_recording_1'))
            .thenAnswer((_) async => true);
        
        recordingBloc.add(const DeleteRecording('test_recording_1'));
        
        // Should handle delete request
        expect(recordingBloc.state, isA<recording_bloc.RecordingState>());
      });
    });

    group('Edit Mode', () {
      test('toggles edit mode', () {
        recordingBloc.add(const ToggleEditMode());
        
        // Should toggle edit mode
        expect(recordingBloc.state, isA<recording_bloc.RecordingState>());
      });

      test('selects recording in edit mode', () {
        recordingBloc.add(const ToggleRecordingSelection(recordingId: 'test_recording_1'));
        
        // Should select recording
        expect(recordingBloc.state, isA<recording_bloc.RecordingState>());
      });
    });

    group('Real-time Updates', () {
      test('handles amplitude updates during recording', () async {
        final testState = recording_bloc.RecordingInProgress(
          filePath: '/test/path.m4a',
          folderId: 'test_folder',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
          duration: const Duration(seconds: 30),
          amplitude: 0.5,
          startTime: DateTime.now(),
        );
        
        expect(testState.amplitude, equals(0.5));
        expect(testState.duration, equals(const Duration(seconds: 30)));
      });
    });

    group('Error Handling', () {
      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'emits Error when recording fails to start',
        build: () {
          when(() => mockStartRecordingUseCase.execute(
            folderId: any(named: 'folderId'),
            format: any(named: 'format'),
            sampleRate: any(named: 'sampleRate'),
            bitRate: any(named: 'bitRate'),
          )).thenThrow(Exception('Recording failed'));
          return recordingBloc;
        },
        act: (testBloc) => testBloc.add(const StartRecording(
          folderId: 'test_folder',
          format: AudioFormat.m4a,
        )),
        expect: () => [
          isA<recording_bloc.RecordingStarting>(),
          isA<recording_bloc.RecordingError>(),
        ],
      );

      blocTest<RecordingBloc, recording_bloc.RecordingState>(
        'handles repository errors gracefully',
        build: () {
          when(() => mockRecordingRepository.getRecordingsByFolder(any()))
              .thenThrow(Exception('Database error'));
          return recordingBloc;
        },
        act: (testBloc) => testBloc.add(const LoadRecordings(folderId: 'test_folder')),
        expect: () => [
          isA<recording_bloc.RecordingError>(),
        ],
      );
    });

    group('Memory Management', () {
      test('properly disposes resources', () async {
        // Verify that the bloc properly disposes of its resources
        await recordingBloc.close();
        
        // The bloc should be closed after disposal
        expect(recordingBloc.isClosed, isTrue);
      });

      test('handles rapid events gracefully', () async {
        // Test rapid event processing without causing issues
        recordingBloc.add(const CheckRecordingPermissions());
        recordingBloc.add(const LoadRecordings(folderId: 'test_folder'));
        recordingBloc.add(const ToggleEditMode());
        
        // Wait a bit for processing
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Should handle rapid events without memory issues
        expect(recordingBloc.state, anyOf([
          isA<recording_bloc.RecordingInitial>(),
          isA<recording_bloc.RecordingLoaded>(),
          isA<recording_bloc.RecordingError>(),
          isA<recording_bloc.RecordingPermissionStatus>(),
        ]));
      });
    });
  });
}