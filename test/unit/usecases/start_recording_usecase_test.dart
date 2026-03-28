// File: test/unit/usecases/start_recording_usecase_test.dart
//
// Start Recording Use Case Unit Tests
// ===================================
//
// Tests all business logic for StartRecordingUseCase using the Either pattern.
// Results are Either<Failure, StartRecordingSuccess>.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:wavnote/domain/usecases/recording/start_recording_usecase.dart';
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart';
import 'package:wavnote/services/location/geolocation_service.dart';
import 'package:wavnote/core/enums/audio_format.dart';
import 'package:wavnote/core/errors/failures.dart';

import '../../helpers/test_helpers.dart';

class MockAudioServiceRepository extends Mock implements IAudioServiceRepository {}
class MockGeolocationService extends Mock implements GeolocationService {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('StartRecordingUseCase', () {
    late StartRecordingUseCase useCase;
    late MockAudioServiceRepository mockAudioService;
    late MockGeolocationService mockGeolocationService;

    setUp(() {
      mockAudioService = MockAudioServiceRepository();
      mockGeolocationService = MockGeolocationService();

      when(() => mockAudioService.hasMicrophonePermission()).thenAnswer((_) async => true);
      when(() => mockAudioService.requestMicrophonePermission()).thenAnswer((_) async => true);
      when(() => mockAudioService.startRecording(
        filePath: any(named: 'filePath'),
        format: any(named: 'format'),
        sampleRate: any(named: 'sampleRate'),
        bitRate: any(named: 'bitRate'),
      )).thenAnswer((_) async => true);
      when(() => mockGeolocationService.getRecordingLocationName())
          .thenAnswer((_) async => 'Via Cerlini 19, Milano');

      useCase = StartRecordingUseCase(
        audioService: mockAudioService,
        geolocationService: mockGeolocationService,
      );
    });

    group('Successful Recording Start', () {
      test('returns Right with default parameters', () async {
        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isRight(), isTrue);
        final success = (result as Right).value as StartRecordingSuccess;
        expect(success.filePath, isNotNull);
        expect(success.title, equals('Via Cerlini 19, Milano'));
        expect(success.folderId, equals('test_folder'));
        expect(success.format, equals(AudioFormat.m4a));
        expect(success.sampleRate, equals(44100));
        expect(success.bitRate, equals(128000));
        expect(success.startTime, isNotNull);

        verify(() => mockAudioService.hasMicrophonePermission()).called(1);
        verify(() => mockGeolocationService.getRecordingLocationName()).called(1);
        verify(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
        )).called(1);
      });

      test('returns Right with custom parameters', () async {
        final result = await useCase.execute(
          folderId: 'custom_folder',
          format: AudioFormat.wav,
          sampleRate: 48000,
          bitRate: 256000,
        );

        expect(result.isRight(), isTrue);
        final success = (result as Right).value as StartRecordingSuccess;
        expect(success.folderId, equals('custom_folder'));
        expect(success.format, equals(AudioFormat.wav));
        expect(success.sampleRate, equals(48000));
        expect(success.bitRate, equals(256000));
      });

      test('generates unique file paths for concurrent calls', () async {
        final results = await Future.wait([
          useCase.execute(folderId: 'folder1'),
          useCase.execute(folderId: 'folder2'),
          useCase.execute(folderId: 'folder3'),
        ]);

        expect(results.length, equals(3));
        expect(results.every((r) => r.isRight()), isTrue);

        final filePaths = results
            .map((r) => ((r as Right).value as StartRecordingSuccess).filePath)
            .toList();
        expect(filePaths.toSet().length, equals(3));
      });

      test('includes timestamp in file path for uniqueness', () async {
        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isRight(), isTrue);
        final path = ((result as Right).value as StartRecordingSuccess).filePath;
        expect(path, contains('test_folder/'));
        expect(path, contains('.m4a'));
        expect(path, matches(r'.*_\d+\.m4a$'));
      });
    });

    group('Permission Handling', () {
      test('returns Left when permission denied and cannot be requested', () async {
        when(() => mockAudioService.hasMicrophonePermission()).thenAnswer((_) async => false);
        when(() => mockAudioService.requestMicrophonePermission()).thenAnswer((_) async => false);

        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value as Failure;
        expect(failure.message, contains('permission'));

        verify(() => mockAudioService.hasMicrophonePermission()).called(1);
        verify(() => mockAudioService.requestMicrophonePermission()).called(1);
        verifyNever(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
        ));
      });

      test('returns Right when permission granted after request', () async {
        when(() => mockAudioService.hasMicrophonePermission()).thenAnswer((_) async => false);
        when(() => mockAudioService.requestMicrophonePermission()).thenAnswer((_) async => true);

        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isRight(), isTrue);
        verify(() => mockAudioService.hasMicrophonePermission()).called(1);
        verify(() => mockAudioService.requestMicrophonePermission()).called(1);
      });

      test('returns Left when permission check throws', () async {
        when(() => mockAudioService.hasMicrophonePermission())
            .thenThrow(Exception('Permission service unavailable'));

        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isLeft(), isTrue);
      });
    });

    group('Location-Based Title Generation', () {
      test('uses location service for title', () async {
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Central Park, New York');

        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isRight(), isTrue);
        final success = ((result as Right).value as StartRecordingSuccess);
        expect(success.title, equals('Central Park, New York'));
      });

      test('falls back to timestamp when location service throws', () async {
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenThrow(Exception('Location service unavailable'));

        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isRight(), isTrue);
        final success = ((result as Right).value as StartRecordingSuccess);
        expect(success.title, matches(r'Recording \d{4}-\d{2}-\d{2} \d{2}:\d{2}'));
      });

      test('falls back to timestamp when location service returns empty string', () async {
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => '');

        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isRight(), isTrue);
        final success = ((result as Right).value as StartRecordingSuccess);
        expect(success.title, matches(r'Recording \d{4}-\d{2}-\d{2} \d{2}:\d{2}'));
      });
    });

    group('File Path Generation', () {
      test('sanitizes invalid characters from filename', () async {
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Invalid<>:"/|?*Characters');

        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isRight(), isTrue);
        final path = ((result as Right).value as StartRecordingSuccess).filePath;
        expect(path, isNot(contains('<')));
        expect(path, isNot(contains('>')));
        expect(path, isNot(contains('"')));
        expect(path, isNot(contains('|')));
        expect(path, isNot(contains('?')));
        expect(path, isNot(contains('*')));
      });

      test('replaces spaces with underscores', () async {
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Recording with spaces');

        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isRight(), isTrue);
        final path = ((result as Right).value as StartRecordingSuccess).filePath;
        expect(path, contains('Recording_with_spaces'));
      });

      test('truncates very long filenames', () async {
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'A' * 100);

        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isRight(), isTrue);
        final path = ((result as Right).value as StartRecordingSuccess).filePath;
        final filename = path.split('/').last;
        // Name portion is capped at 50 chars, plus _timestamp.ext
        expect(filename.length, lessThan(80));
      });

      test('includes folder ID in file path', () async {
        final result = await useCase.execute(folderId: 'my_custom_folder');

        expect(result.isRight(), isTrue);
        final path = ((result as Right).value as StartRecordingSuccess).filePath;
        expect(path, startsWith('my_custom_folder/'));
      });

      test('includes correct file extension per format', () async {
        final testCases = [
          (AudioFormat.m4a, '.m4a'),
          (AudioFormat.wav, '.wav'),
          (AudioFormat.flac, '.flac'),
        ];

        for (final (format, extension) in testCases) {
          final result = await useCase.execute(
            folderId: 'test_folder',
            format: format,
          );
          expect(result.isRight(), isTrue);
          final path = ((result as Right).value as StartRecordingSuccess).filePath;
          expect(path, endsWith(extension));
        }
      });
    });

    group('Audio Configuration Validation', () {
      test('returns Left for sample rate below minimum', () async {
        final result = await useCase.execute(
          folderId: 'test_folder',
          sampleRate: 7000,
        );
        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value as Failure;
        expect(failure.message, contains('sample rate'));
      });

      test('returns Left for sample rate above maximum', () async {
        final result = await useCase.execute(
          folderId: 'test_folder',
          sampleRate: 200000,
        );
        expect(result.isLeft(), isTrue);
      });

      test('returns Left for bit rate below minimum', () async {
        final result = await useCase.execute(
          folderId: 'test_folder',
          bitRate: 30000,
        );
        expect(result.isLeft(), isTrue);
      });

      test('returns Left for bit rate above maximum', () async {
        final result = await useCase.execute(
          folderId: 'test_folder',
          bitRate: 600000,
        );
        expect(result.isLeft(), isTrue);
      });

      test('returns Left for M4A with sample rate above 48000', () async {
        final result = await useCase.execute(
          folderId: 'test_folder',
          format: AudioFormat.m4a,
          sampleRate: 96000,
        );
        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value as Failure;
        expect(failure.message, contains('M4A'));
      });

      test('accepts valid configuration ranges', () async {
        final validConfigs = [
          (8000, 32000),
          (44100, 128000),
          (48000, 320000),
        ];

        for (final (sampleRate, bitRate) in validConfigs) {
          final result = await useCase.execute(
            folderId: 'test_folder',
            sampleRate: sampleRate,
            bitRate: bitRate,
          );
          expect(result.isRight(), isTrue,
              reason: 'Failed for sampleRate: $sampleRate, bitRate: $bitRate');
        }
      });
    });

    group('Audio Service Integration', () {
      test('returns Left when audio service fails to start', () async {
        when(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
        )).thenAnswer((_) async => false);

        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value as Failure;
        expect(failure, isA<AudioRecordingFailure>());
      });

      test('returns Left when audio service throws', () async {
        when(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
        )).thenThrow(Exception('Audio device busy'));

        final result = await useCase.execute(folderId: 'test_folder');

        expect(result.isLeft(), isTrue);
      });

      test('passes correct parameters to audio service', () async {
        await useCase.execute(
          folderId: 'test_folder',
          format: AudioFormat.wav,
          sampleRate: 48000,
          bitRate: 256000,
        );

        verify(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath', that: contains('test_folder/')),
          format: AudioFormat.wav,
          sampleRate: 48000,
          bitRate: 256000,
        )).called(1);
      });
    });
  });
}
