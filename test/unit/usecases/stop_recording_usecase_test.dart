// File: test/unit/usecases/stop_recording_usecase_test.dart
//
// Stop Recording Use Case Unit Tests
// ====================================
//
// Tests StopRecordingUseCase using the Either pattern.
// Results are Either<Failure, RecordingEntity>.
//
// Note: incremental naming uses "<location> N" (no parentheses).
// Repository is queried by recording.folderId, not the location name.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:wavnote/domain/usecases/recording/stop_recording_usecase.dart';
import 'package:wavnote/domain/repositories/i_audio_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_location_repository.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/core/errors/failures.dart';

import '../../helpers/test_helpers.dart';

class MockAudioServiceRepository extends Mock implements IAudioRecordingRepository {}
class MockRecordingRepository extends Mock implements IRecordingRepository {}
class MockLocationRepository extends Mock implements ILocationRepository {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('StopRecordingUseCase', () {
    late StopRecordingUseCase useCase;
    late MockAudioServiceRepository mockAudioService;
    late MockRecordingRepository mockRecordingRepository;
    late MockLocationRepository mockLocationRepository;
    late RecordingEntity testRecording;

    setUp(() {
      mockAudioService = MockAudioServiceRepository();
      mockRecordingRepository = MockRecordingRepository();
      mockLocationRepository = MockLocationRepository();

      testRecording = TestHelpers.createTestRecording(
        id: 'test_recording_id',
        name: 'Test Recording',
        filePath: '/test/recording.m4a',
        folderId: 'test_folder',
        duration: const Duration(seconds: 30),
      );

      // Default: active recording exists
      when(() => mockAudioService.isRecording()).thenAnswer((_) async => true);
      when(() => mockAudioService.isRecordingPaused()).thenAnswer((_) async => false);
      when(() => mockAudioService.stopRecording()).thenAnswer((_) async => testRecording);
      when(() => mockLocationRepository.getRecordingLocationName())
          .thenAnswer((_) async => 'Via Cerlini 19, Milano');
      when(() => mockRecordingRepository.createRecording(any()))
          .thenAnswer((_) async => testRecording);
      // Repository is queried by folderId of the recording entity
      when(() => mockRecordingRepository.getRecordingsByFolder(any()))
          .thenAnswer((_) async => <RecordingEntity>[]);

      useCase = StopRecordingUseCase(
        audioService: mockAudioService,
        recordingRepository: mockRecordingRepository,
        locationRepository: mockLocationRepository,
      );
    });

    group('Successful Recording Stop', () {
      test('returns Right with saved recording', () async {
        final result = await useCase.execute();

        expect(result.isRight(), isTrue);
        final saved = (result as Right).value as RecordingEntity;
        expect(saved.id, equals(testRecording.id));

        verify(() => mockAudioService.isRecording()).called(1);
        verify(() => mockAudioService.stopRecording()).called(1);
        verify(() => mockLocationRepository.getRecordingLocationName()).called(1);
        verify(() => mockRecordingRepository.createRecording(any())).called(1);
      });

      test('includes waveform data when provided', () async {
        final waveformData = [0.1, 0.5, 0.8, 0.3, 0.6];

        final result = await useCase.execute(waveformData: waveformData);

        expect(result.isRight(), isTrue);
        final captured = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(captured.waveformData, equals(waveformData));
      });

      test('applies override duration when provided', () async {
        const overrideDuration = Duration(minutes: 2, seconds: 15);

        final result = await useCase.execute(overrideDuration: overrideDuration);

        expect(result.isRight(), isTrue);
        final captured = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(captured.duration, equals(overrideDuration));
      });

      test('uses base location name when no existing recordings', () async {
        when(() => mockRecordingRepository.getRecordingsByFolder('test_folder'))
            .thenAnswer((_) async => <RecordingEntity>[]);

        final result = await useCase.execute();

        expect(result.isRight(), isTrue);
        final captured = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(captured.name, equals('Via Cerlini 19, Milano'));
      });

      test('appends incremental number when existing recordings share the location', () async {
        final existingRecordings = [
          TestHelpers.createTestRecording(
              name: 'Via Cerlini 19, Milano', folderId: 'test_folder'),
        ];
        when(() => mockRecordingRepository.getRecordingsByFolder('test_folder'))
            .thenAnswer((_) async => existingRecordings);

        final result = await useCase.execute();

        expect(result.isRight(), isTrue);
        final captured = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        // Naming: "Via Cerlini 19, Milano 2" (space + number, no parens)
        expect(captured.name, equals('Via Cerlini 19, Milano 2'));
      });

      test('falls back to timestamp name when geolocation fails', () async {
        when(() => mockLocationRepository.getRecordingLocationName())
            .thenThrow(Exception('Location unavailable'));

        final result = await useCase.execute();

        expect(result.isRight(), isTrue);
        final captured = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(captured.name, matches(r'Recording \d+/\d+ \d+:\d{2}'));
      });
    });

    group('Validation Failures', () {
      test('returns Left when no active recording', () async {
        when(() => mockAudioService.isRecording()).thenAnswer((_) async => false);
        when(() => mockAudioService.isRecordingPaused()).thenAnswer((_) async => false);

        final result = await useCase.execute();

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value as Failure;
        expect(failure.message, contains('No active recording'));
        verifyNever(() => mockAudioService.stopRecording());
      });

      test('returns Left when audio service returns null', () async {
        when(() => mockAudioService.stopRecording()).thenAnswer((_) async => null);

        final result = await useCase.execute();

        expect(result.isLeft(), isTrue);
        verifyNever(() => mockRecordingRepository.createRecording(any()));
      });

      test('returns Left when recording has zero duration', () async {
        final invalidRecording = testRecording.copyWith(duration: Duration.zero);
        when(() => mockAudioService.stopRecording())
            .thenAnswer((_) async => invalidRecording);

        final result = await useCase.execute();

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value as Failure;
        expect(failure.message, contains('duration'));
      });

      test('returns Left when recording has empty file path', () async {
        final invalidRecording = testRecording.copyWith(filePath: '');
        when(() => mockAudioService.stopRecording())
            .thenAnswer((_) async => invalidRecording);

        final result = await useCase.execute();

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value as Failure;
        expect(failure.message, contains('file path'));
      });

      test('returns Left when recording has invalid file size', () async {
        final invalidRecording = testRecording.copyWith(fileSize: -1);
        when(() => mockAudioService.stopRecording())
            .thenAnswer((_) async => invalidRecording);

        final result = await useCase.execute();

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value as Failure;
        expect(failure.message, contains('file size'));
      });
    });

    group('Repository Integration', () {
      test('returns Left when repository throws', () async {
        when(() => mockRecordingRepository.createRecording(any()))
            .thenThrow(Exception('Database connection failed'));

        final result = await useCase.execute();

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<UnexpectedFailure>());
      });

      test('passes waveform data to repository', () async {
        final waveformData = [0.1, 0.5, 0.8];
        const overrideDuration = Duration(minutes: 1, seconds: 30);

        await useCase.execute(
          waveformData: waveformData,
          overrideDuration: overrideDuration,
        );

        final captured = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(captured.waveformData, equals(waveformData));
        expect(captured.duration, const Duration(milliseconds: 300));
      });
    });

    group('Waveform Data Handling', () {
      test('preserves waveform data integrity', () async {
        final originalWaveform = List.generate(100, (i) => (i / 100.0));

        final result = await useCase.execute(waveformData: originalWaveform);

        expect(result.isRight(), isTrue);
        final captured = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(captured.waveformData, equals(originalWaveform));
      });

      test('handles empty waveform data', () async {
        final result = await useCase.execute(waveformData: []);

        expect(result.isRight(), isTrue);
      });

      test('handles null waveform data', () async {
        final result = await useCase.execute(waveformData: null);

        expect(result.isRight(), isTrue);
        final captured = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(captured.waveformData, isNull);
      });
    });

    group('Error Handling', () {
      test('returns Left when audio service throws during stop', () async {
        when(() => mockAudioService.stopRecording())
            .thenThrow(Exception('Audio device error'));

        final result = await useCase.execute();

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<UnexpectedFailure>());
      });

      test('succeeds when recording is paused (not actively recording)', () async {
        when(() => mockAudioService.isRecording()).thenAnswer((_) async => false);
        when(() => mockAudioService.isRecordingPaused()).thenAnswer((_) async => true);

        final result = await useCase.execute();

        expect(result.isRight(), isTrue);
      });
    });
  });
}
