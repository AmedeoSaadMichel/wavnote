// File: test/unit/usecases/recording_lifecycle_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wavnote/domain/usecases/recording/recording_lifecycle_usecase.dart';
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/services/location/geolocation_service.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/core/enums/audio_format.dart';

class MockAudioServiceRepository extends Mock implements IAudioServiceRepository {}
class MockRecordingRepository extends Mock implements IRecordingRepository {}
class MockGeolocationService extends Mock implements GeolocationService {}

void main() {
  setUpAll(() {
    registerFallbackValue(AudioFormat.m4a);
    registerFallbackValue(const Duration(seconds: 30));
    registerFallbackValue(DateTime(2023, 1, 1));
    registerFallbackValue(RecordingEntity(
      id: 'test_id',
      name: 'Test Recording',
      filePath: '/test/recording.m4a',
      duration: const Duration(minutes: 1),
      folderId: 'test_folder',
      createdAt: DateTime(2023, 1, 1),
      format: AudioFormat.m4a,
      sampleRate: 44100,
      fileSize: 1024,
      isFavorite: false,
    ));
  });

  group('RecordingLifecycleUseCase', () {
    late RecordingLifecycleUseCase useCase;
    late MockAudioServiceRepository mockAudioService;
    late MockRecordingRepository mockRecordingRepository;
    late MockGeolocationService mockGeolocationService;

    setUp(() {
      mockAudioService = MockAudioServiceRepository();
      mockRecordingRepository = MockRecordingRepository();
      mockGeolocationService = MockGeolocationService();
      
      useCase = RecordingLifecycleUseCase(
        audioService: mockAudioService,
        recordingRepository: mockRecordingRepository,
        geolocationService: mockGeolocationService,
      );
    });

    group('initializeAudioService', () {
      test('returns true when audio service initializes successfully', () async {
        // Arrange
        when(() => mockAudioService.initialize()).thenAnswer((_) async => true);

        // Act
        final result = await useCase.initializeAudioService();

        // Assert
        expect(result, isTrue);
        verify(() => mockAudioService.initialize()).called(1);
      });

      test('returns false when audio service initialization fails', () async {
        // Arrange
        when(() => mockAudioService.initialize()).thenAnswer((_) async => false);

        // Act
        final result = await useCase.initializeAudioService();

        // Assert
        expect(result, isFalse);
        verify(() => mockAudioService.initialize()).called(1);
      });

      test('returns false when audio service throws exception', () async {
        // Arrange
        when(() => mockAudioService.initialize()).thenThrow(Exception('Test error'));

        // Act
        final result = await useCase.initializeAudioService();

        // Assert
        expect(result, isFalse);
        verify(() => mockAudioService.initialize()).called(1);
      });
    });

    group('canStartRecording', () {
      test('returns true when microphone permission is granted', () async {
        // Arrange
        when(() => mockAudioService.hasMicrophonePermission()).thenAnswer((_) async => true);

        // Act
        final result = await useCase.canStartRecording();

        // Assert
        expect(result, isTrue);
        verify(() => mockAudioService.hasMicrophonePermission()).called(1);
      });

      test('returns false when microphone permission is denied', () async {
        // Arrange
        when(() => mockAudioService.hasMicrophonePermission()).thenAnswer((_) async => false);

        // Act
        final result = await useCase.canStartRecording();

        // Assert
        expect(result, isFalse);
        verify(() => mockAudioService.hasMicrophonePermission()).called(1);
      });

      test('returns false when permission check throws exception', () async {
        // Arrange
        when(() => mockAudioService.hasMicrophonePermission()).thenThrow(Exception('Permission error'));

        // Act
        final result = await useCase.canStartRecording();

        // Assert
        expect(result, isFalse);
        verify(() => mockAudioService.hasMicrophonePermission()).called(1);
      });
    });

    group('generateRecordingTitle', () {
      test('returns location name when available', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Times Square, New York');

        // Act
        final result = await useCase.generateRecordingTitle();

        // Assert
        expect(result, equals('Times Square, New York'));
        verify(() => mockGeolocationService.getRecordingLocationName()).called(1);
      });

      test('returns "New Recording" when location name is empty', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => '');

        // Act
        final result = await useCase.generateRecordingTitle();

        // Assert
        expect(result, equals('New Recording'));
        verify(() => mockGeolocationService.getRecordingLocationName()).called(1);
      });

      test('returns "New Recording" when location service throws exception', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenThrow(Exception('Location error'));

        // Act
        final result = await useCase.generateRecordingTitle();

        // Assert
        expect(result, equals('New Recording'));
        verify(() => mockGeolocationService.getRecordingLocationName()).called(1);
      });
    });

    group('startRecording', () {
      test('returns true when recording starts successfully', () async {
        // Arrange
        when(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
        )).thenAnswer((_) async => true);

        // Act
        final result = await useCase.startRecording(
          filePath: '/test/recording.m4a',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockAudioService.startRecording(
          filePath: '/test/recording.m4a',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
        )).called(1);
      });

      test('returns false when recording start fails', () async {
        // Arrange
        when(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
        )).thenAnswer((_) async => false);

        // Act
        final result = await useCase.startRecording(
          filePath: '/test/recording.m4a',
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
        );

        // Assert
        expect(result, isFalse);
      });
    });

    group('saveRecording', () {
      test('creates and saves recording successfully', () async {
        // Arrange
        final testRecording = RecordingEntity(
          id: 'test_id',
          name: 'Test Recording',
          filePath: '/test/recording.m4a',
          duration: const Duration(minutes: 1),
          folderId: 'test_folder',
          createdAt: DateTime(2023, 1, 1),
          format: AudioFormat.m4a,
          sampleRate: 44100,
          fileSize: 1024,
          isFavorite: false,
        );

        when(() => mockRecordingRepository.createRecording(any()))
            .thenAnswer((invocation) async => invocation.positionalArguments[0] as RecordingEntity);

        // Act
        final result = await useCase.saveRecording(
          filePath: '/test/recording.m4a',
          title: 'Test Recording',
          duration: const Duration(minutes: 1),
          folderId: 'test_folder',
          startTime: DateTime(2023, 1, 1),
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
        );

        // Assert
        expect(result.name, equals('Test Recording'));
        expect(result.filePath, equals('/test/recording.m4a'));
        expect(result.duration, equals(const Duration(minutes: 1)));
        expect(result.folderId, equals('test_folder'));
        expect(result.format, equals(AudioFormat.m4a));
        
        verify(() => mockRecordingRepository.createRecording(any())).called(1);
      });

      test('throws exception when save fails', () async {
        // Arrange
        when(() => mockRecordingRepository.createRecording(any()))
            .thenThrow(Exception('Save failed'));

        // Act & Assert
        expect(
          () => useCase.saveRecording(
            filePath: '/test/recording.m4a',
            title: 'Test Recording',
            duration: const Duration(minutes: 1),
            folderId: 'test_folder',
            startTime: DateTime(2023, 1, 1),
            format: AudioFormat.m4a,
            sampleRate: 44100,
            bitRate: 128000,
          ),
          throwsException,
        );
      });
    });

    group('stream access', () {
      test('provides amplitude stream from audio service', () {
        // Arrange
        final testStream = Stream<double>.value(0.5);
        when(() => mockAudioService.amplitudeStream).thenReturn(testStream);

        // Act
        final result = useCase.amplitudeStream;

        // Assert
        expect(result, equals(testStream));
        verify(() => mockAudioService.amplitudeStream).called(1);
      });

      test('provides duration stream from audio service', () {
        // Arrange
        final testStream = Stream<Duration>.value(const Duration(seconds: 30));
        when(() => mockAudioService.durationStream).thenReturn(testStream);

        // Act
        final result = useCase.durationStream;

        // Assert
        expect(result, equals(testStream));
        verify(() => mockAudioService.durationStream).called(1);
      });
    });

    group('dispose', () {
      test('calls dispose on audio service', () async {
        // Arrange
        when(() => mockAudioService.dispose()).thenAnswer((_) async {});

        // Act
        await useCase.dispose();

        // Assert
        verify(() => mockAudioService.dispose()).called(1);
      });

      test('handles disposal errors gracefully', () async {
        // Arrange
        when(() => mockAudioService.dispose()).thenThrow(Exception('Disposal error'));

        // Act & Assert (should not throw)
        await useCase.dispose();
        
        verify(() => mockAudioService.dispose()).called(1);
      });
    });
  });
}