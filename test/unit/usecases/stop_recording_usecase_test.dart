// File: test/unit/usecases/stop_recording_usecase_test.dart
// 
// Stop Recording Use Case Unit Tests
// ==================================
//
// Comprehensive test suite for the StopRecordingUseCase class, testing
// all business logic for recording completion, validation, and persistence.
//
// Test Coverage:
// - Active recording validation
// - Audio service stop operation
// - Location-based naming with incremental numbering
// - Waveform data integration
// - Recording validation and persistence
// - Error scenarios and edge cases

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wavnote/domain/usecases/recording/stop_recording_usecase.dart';
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/services/location/geolocation_service.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/core/enums/audio_format.dart';

import '../../helpers/test_helpers.dart';

// Mock classes
class MockAudioServiceRepository extends Mock implements IAudioServiceRepository {}
class MockRecordingRepository extends Mock implements IRecordingRepository {}
class MockGeolocationService extends Mock implements GeolocationService {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('StopRecordingUseCase', () {
    late StopRecordingUseCase useCase;
    late MockAudioServiceRepository mockAudioService;
    late MockRecordingRepository mockRecordingRepository;
    late MockGeolocationService mockGeolocationService;

    late RecordingEntity testRecording;

    setUp(() {
      mockAudioService = MockAudioServiceRepository();
      mockRecordingRepository = MockRecordingRepository();
      mockGeolocationService = MockGeolocationService();

      testRecording = TestHelpers.createTestRecording(
        id: 'test_recording_id',
        name: 'Test Recording',
        filePath: '/test/recording.m4a',
        folderId: 'test_folder',
        duration: const Duration(seconds: 30),
      );

      // Setup default mock behaviors
      when(() => mockAudioService.isRecording()).thenAnswer((_) async => true);
      when(() => mockAudioService.stopRecording()).thenAnswer((_) async => testRecording);
      when(() => mockGeolocationService.getRecordingLocationName())
          .thenAnswer((_) async => 'Via Cerlini 19, Milano');
      when(() => mockRecordingRepository.createRecording(any()))
          .thenAnswer((_) async => testRecording);
      when(() => mockRecordingRepository.getRecordingsByFolder(any()))
          .thenAnswer((_) async => <RecordingEntity>[]);

      useCase = StopRecordingUseCase(
        audioService: mockAudioService,
        recordingRepository: mockRecordingRepository,
        geolocationService: mockGeolocationService,
      );
    });

    group('Successful Recording Stop', () {
      test('executes successfully with basic recording', () async {
        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recording, isNotNull);
        expect(result.recording!.id, equals(testRecording.id));

        verify(() => mockAudioService.isRecording()).called(1);
        verify(() => mockAudioService.stopRecording()).called(1);
        verify(() => mockGeolocationService.getRecordingLocationName()).called(1);
        verify(() => mockRecordingRepository.createRecording(any())).called(1);
      });

      test('includes waveform data when provided', () async {
        // Arrange
        final waveformData = [0.1, 0.5, 0.8, 0.3, 0.6];

        // Act
        final result = await useCase.execute(waveformData: waveformData);

        // Assert
        expect(result.isSuccess, isTrue);
        
        // Verify waveform data was passed to repository
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.waveformData, equals(waveformData));
      });

      test('uses override duration when provided', () async {
        // Arrange
        const overrideDuration = Duration(minutes: 2, seconds: 15);

        // Act
        final result = await useCase.execute(overrideDuration: overrideDuration);

        // Assert
        expect(result.isSuccess, isTrue);
        
        // Verify override duration was used
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.duration, equals(overrideDuration));
      });

      test('generates location-based name with incremental numbering', () async {
        // Arrange - Setup existing recordings with same location
        final existingRecordings = [
          TestHelpers.createTestRecording(name: 'Via Cerlini 19, Milano'),
          TestHelpers.createTestRecording(name: 'Via Cerlini 19, Milano (2)'),
        ];
        when(() => mockRecordingRepository.getRecordingsByFolder('Via Cerlini 19, Milano'))
            .thenAnswer((_) async => existingRecordings);

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        // Should generate incremental name
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.name, equals('Via Cerlini 19, Milano (3)'));
      });

      test('handles first recording at location correctly', () async {
        // Arrange - No existing recordings at location
        when(() => mockRecordingRepository.getRecordingsByFolder('Central Park, New York'))
            .thenAnswer((_) async => <RecordingEntity>[]);
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Central Park, New York');

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        // Should use base name without numbering
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.name, equals('Central Park, New York'));
      });
    });

    group('Recording Validation', () {
      test('fails when no active recording exists', () async {
        // Arrange
        when(() => mockAudioService.isRecording()).thenAnswer((_) async => false);

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StopRecordingErrorType.noActiveRecording));
        expect(result.errorMessage, contains('No active recording to stop'));

        verify(() => mockAudioService.isRecording()).called(1);
        verifyNever(() => mockAudioService.stopRecording());
      });

      test('fails when audio service returns null recording', () async {
        // Arrange
        when(() => mockAudioService.stopRecording()).thenAnswer((_) async => null);

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StopRecordingErrorType.audioServiceError));
        expect(result.errorMessage, contains('Failed to complete recording'));

        verify(() => mockAudioService.stopRecording()).called(1);
        verifyNever(() => mockRecordingRepository.createRecording(any()));
      });

      test('validates recording has valid duration', () async {
        // Arrange - Recording with zero duration
        final invalidRecording = testRecording.copyWith(duration: Duration.zero);
        when(() => mockAudioService.stopRecording()).thenAnswer((_) async => invalidRecording);

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StopRecordingErrorType.invalidRecording));
        expect(result.errorMessage, contains('duration'));
      });

      test('validates recording has valid file path', () async {
        // Arrange - Recording with empty file path
        final invalidRecording = testRecording.copyWith(filePath: '');
        when(() => mockAudioService.stopRecording()).thenAnswer((_) async => invalidRecording);

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StopRecordingErrorType.invalidRecording));
        expect(result.errorMessage, contains('file path'));
      });

      test('validates recording has valid file size', () async {
        // Arrange - Recording with negative file size
        final invalidRecording = testRecording.copyWith(fileSize: -1);
        when(() => mockAudioService.stopRecording()).thenAnswer((_) async => invalidRecording);

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StopRecordingErrorType.invalidRecording));
        expect(result.errorMessage, contains('file size'));
      });
    });

    group('Location-Based Naming', () {
      test('uses geolocation service for naming', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Times Square, New York');

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        verify(() => mockGeolocationService.getRecordingLocationName()).called(1);
        
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.name, equals('Times Square, New York'));
      });

      test('falls back to timestamp when location service fails', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenThrow(Exception('Location service unavailable'));

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.name, matches(r'Recording \d{4}-\d{2}-\d{2} \d{2}:\d{2}'));
      });

      test('falls back to timestamp when location returns empty string', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => '');

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.name, matches(r'Recording \d{4}-\d{2}-\d{2} \d{2}:\d{2}'));
      });

      test('handles special characters in location names', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Café de l\'Église, Montréal');

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.name, equals('Café de l\'Église, Montréal'));
      });

      test('handles very long location names', () async {
        // Arrange
        final longLocationName = 'A' * 200; // Very long name
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => longLocationName);

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        // Should handle long names appropriately
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.name.length, lessThanOrEqualTo(255)); // Reasonable limit
      });
    });

    group('Incremental Numbering Logic', () {
      test('correctly calculates next number for sequential recordings', () async {
        // Arrange - Sequential recordings (1), (2), (3)
        final existingRecordings = [
          TestHelpers.createTestRecording(name: 'Test Location'),
          TestHelpers.createTestRecording(name: 'Test Location (2)'),
          TestHelpers.createTestRecording(name: 'Test Location (3)'),
        ];
        when(() => mockRecordingRepository.getRecordingsByFolder('Test Location'))
            .thenAnswer((_) async => existingRecordings);
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Test Location');

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.name, equals('Test Location (4)'));
      });

      test('handles gaps in numbering correctly', () async {
        // Arrange - Non-sequential recordings: base, (2), (5)
        final existingRecordings = [
          TestHelpers.createTestRecording(name: 'Test Location'),
          TestHelpers.createTestRecording(name: 'Test Location (2)'),
          TestHelpers.createTestRecording(name: 'Test Location (5)'),
        ];
        when(() => mockRecordingRepository.getRecordingsByFolder('Test Location'))
            .thenAnswer((_) async => existingRecordings);
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Test Location');

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.name, equals('Test Location (6)')); // Should use max + 1
      });

      test('ignores recordings with invalid numbering format', () async {
        // Arrange - Mix of valid and invalid numbering
        final existingRecordings = [
          TestHelpers.createTestRecording(name: 'Test Location'),
          TestHelpers.createTestRecording(name: 'Test Location (2)'),
          TestHelpers.createTestRecording(name: 'Test Location (abc)'), // Invalid
          TestHelpers.createTestRecording(name: 'Test Location (4) Extra'), // Invalid format
        ];
        when(() => mockRecordingRepository.getRecordingsByFolder('Test Location'))
            .thenAnswer((_) async => existingRecordings);
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Test Location');

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.name, equals('Test Location (3)')); // Should ignore invalid ones
      });
    });

    group('Waveform Data Handling', () {
      test('preserves waveform data integrity', () async {
        // Arrange
        final originalWaveform = List.generate(100, (i) => (i / 100.0));

        // Act
        final result = await useCase.execute(waveformData: originalWaveform);

        // Assert
        expect(result.isSuccess, isTrue);
        
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.waveformData, equals(originalWaveform));
      });

      test('handles empty waveform data', () async {
        // Act
        final result = await useCase.execute(waveformData: []);

        // Assert
        expect(result.isSuccess, isTrue);
        
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.waveformData, equals([]));
      });

      test('handles null waveform data', () async {
        // Act
        final result = await useCase.execute(waveformData: null);

        // Assert
        expect(result.isSuccess, isTrue);
        
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.waveformData, isNull);
      });

      test('handles very large waveform data', () async {
        // Arrange
        final largeWaveform = List.generate(10000, (i) => (i % 100) / 100.0);

        // Act
        final result = await useCase.execute(waveformData: largeWaveform);

        // Assert
        expect(result.isSuccess, isTrue);
        
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        expect(capturedRecording.waveformData!.length, equals(10000));
      });
    });

    group('Repository Integration', () {
      test('fails when repository throws exception', () async {
        // Arrange
        when(() => mockRecordingRepository.createRecording(any()))
            .thenThrow(Exception('Database connection failed'));

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StopRecordingErrorType.repositoryError));
        expect(result.errorMessage, contains('Database connection failed'));
      });

      test('handles repository constraint violations', () async {
        // Arrange
        when(() => mockRecordingRepository.createRecording(any()))
            .thenThrow(Exception('UNIQUE constraint failed'));

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StopRecordingErrorType.repositoryError));
      });

      test('passes complete recording data to repository', () async {
        // Arrange
        final waveformData = [0.1, 0.5, 0.8];
        const overrideDuration = Duration(minutes: 1, seconds: 30);

        // Act
        await useCase.execute(
          waveformData: waveformData,
          overrideDuration: overrideDuration,
        );

        // Assert
        final capturedRecording = verify(() => mockRecordingRepository.createRecording(captureAny()))
            .captured.first as RecordingEntity;
        
        expect(capturedRecording.waveformData, equals(waveformData));
        expect(capturedRecording.duration, equals(overrideDuration));
        expect(capturedRecording.filePath, equals(testRecording.filePath));
        expect(capturedRecording.folderId, equals(testRecording.folderId));
        expect(capturedRecording.format, equals(testRecording.format));
        expect(capturedRecording.fileSize, equals(testRecording.fileSize));
        expect(capturedRecording.sampleRate, equals(testRecording.sampleRate));
        expect(capturedRecording.createdAt, isNotNull);
      });
    });

    group('Error Handling and Edge Cases', () {
      test('handles audio service exceptions during stop', () async {
        // Arrange
        when(() => mockAudioService.stopRecording())
            .thenThrow(Exception('Audio device error'));

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StopRecordingErrorType.unknown));
        expect(result.errorMessage, contains('Unexpected error'));
      });

      test('handles concurrent stop operations gracefully', () async {
        // Simulate concurrent stop operations
        final futures = [
          useCase.execute(),
          useCase.execute(),
          useCase.execute(),
        ];

        // Act
        final results = await Future.wait(futures, eagerError: false);

        // Assert
        // At least one should succeed, others might fail due to no active recording
        expect(results.any((r) => r.isSuccess), isTrue);
      });

      test('provides detailed error information', () async {
        // Arrange
        when(() => mockAudioService.isRecording()).thenAnswer((_) async => false);

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotEmpty);
        expect(result.errorType, isNotNull);
        expect(result.recording, isNull);
        expect(result.toString(), contains('failure'));
      });

      test('maintains data consistency during errors', () async {
        // Arrange - Repository fails after location lookup succeeds
        when(() => mockRecordingRepository.createRecording(any()))
            .thenThrow(Exception('Storage full'));

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isFalse);
        
        // Should still have attempted location lookup
        verify(() => mockGeolocationService.getRecordingLocationName()).called(1);
        verify(() => mockAudioService.stopRecording()).called(1);
      });
    });

    group('Business Logic Integration', () {
      test('enforces business rules for recording completion', () async {
        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        final savedRecording = result.recording!;
        expect(savedRecording.createdAt, isNotNull);
        expect(savedRecording.isFavorite, isFalse); // Default value
        expect(savedRecording.id, isNotEmpty);
      });

      test('handles different audio formats correctly', () async {
        // Test with different audio formats
        final formats = [AudioFormat.m4a, AudioFormat.wav, AudioFormat.flac];
        
        for (final format in formats) {
          // Arrange
          final formatRecording = testRecording.copyWith(format: format);
          when(() => mockAudioService.stopRecording()).thenAnswer((_) async => formatRecording);

          // Act
          final result = await useCase.execute();

          // Assert
          expect(result.isSuccess, isTrue);
          expect(result.recording!.format, equals(format));
        }
      });

      test('preserves all recording metadata', () async {
        // Arrange
        final detailedRecording = TestHelpers.createTestRecording(
          name: 'Detailed Recording',
          filePath: '/detailed/path/recording.wav',
          folderId: 'detailed_folder',
          format: AudioFormat.wav,
          duration: const Duration(minutes: 5, seconds: 23),
          fileSize: 5242880, // 5MB
          // sampleRate: 48000, // Remove sampleRate parameter if not supported
          createdAt: DateTime(2023, 12, 25, 10, 30),
        );
        when(() => mockAudioService.stopRecording()).thenAnswer((_) async => detailedRecording);

        // Act
        final result = await useCase.execute();

        // Assert
        expect(result.isSuccess, isTrue);
        
        final savedRecording = result.recording!;
        expect(savedRecording.filePath, equals('/detailed/path/recording.wav'));
        expect(savedRecording.folderId, equals('detailed_folder'));
        expect(savedRecording.format, equals(AudioFormat.wav));
        expect(savedRecording.fileSize, equals(5242880));
        expect(savedRecording.sampleRate, equals(48000));
      });
    });
  });
}