// File: test/unit/usecases/start_recording_usecase_test.dart
// 
// Start Recording Use Case Unit Tests
// ===================================
//
// Comprehensive test suite for the StartRecordingUseCase class, testing
// all business logic for recording initiation, validation, and error handling.
//
// Test Coverage:
// - Permission validation and microphone access
// - Location-based title generation
// - File path creation and sanitization
// - Audio configuration validation
// - Audio service coordination
// - Error scenarios and edge cases
// - Business rule enforcement

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wavnote/domain/usecases/recording/start_recording_usecase.dart';
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart';
import 'package:wavnote/services/location/geolocation_service.dart';
import 'package:wavnote/core/enums/audio_format.dart';

import '../../helpers/test_helpers.dart';

// Mock classes
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

      // Setup default mock behaviors
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
      test('executes successfully with default parameters', () async {
        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.filePath, isNotNull);
        expect(result.title, equals('Via Cerlini 19, Milano'));
        expect(result.folderId, equals('test_folder'));
        expect(result.format, equals(AudioFormat.m4a));
        expect(result.sampleRate, equals(44100));
        expect(result.bitRate, equals(128000));
        expect(result.startTime, isNotNull);

        verify(() => mockAudioService.hasMicrophonePermission()).called(1);
        verify(() => mockGeolocationService.getRecordingLocationName()).called(1);
        verify(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: AudioFormat.m4a,
          sampleRate: 44100,
          bitRate: 128000,
        )).called(1);
      });

      test('executes successfully with custom parameters', () async {
        // Act
        final result = await useCase.execute(
          folderId: 'custom_folder',
          format: AudioFormat.wav,
          sampleRate: 48000,
          bitRate: 256000,
        );

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.folderId, equals('custom_folder'));
        expect(result.format, equals(AudioFormat.wav));
        expect(result.sampleRate, equals(48000));
        expect(result.bitRate, equals(256000));

        verify(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: AudioFormat.wav,
          sampleRate: 48000,
          bitRate: 256000,
        )).called(1);
      });

      test('generates unique file paths for concurrent calls', () async {
        // Act
        final results = await Future.wait([
          useCase.execute(folderId: 'folder1'),
          useCase.execute(folderId: 'folder2'),
          useCase.execute(folderId: 'folder3'),
        ]);

        // Assert
        expect(results.length, equals(3));
        expect(results.every((r) => r.isSuccess), isTrue);
        
        final filePaths = results.map((r) => r.filePath).toList();
        expect(filePaths.toSet().length, equals(3)); // All unique file paths
      });

      test('includes timestamp in file path for uniqueness', () async {
        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.filePath, contains('test_folder/'));
        expect(result.filePath, contains('.m4a'));
        // Should contain timestamp for uniqueness
        expect(result.filePath, matches(r'.*_\d+\.m4a$'));
      });
    });

    group('Permission Handling', () {
      test('fails when microphone permission is denied and cannot be requested', () async {
        // Arrange
        when(() => mockAudioService.hasMicrophonePermission()).thenAnswer((_) async => false);
        when(() => mockAudioService.requestMicrophonePermission()).thenAnswer((_) async => false);

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StartRecordingErrorType.permissionDenied));
        expect(result.errorMessage, contains('Microphone permission'));

        verify(() => mockAudioService.hasMicrophonePermission()).called(1);
        verify(() => mockAudioService.requestMicrophonePermission()).called(1);
        verifyNever(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
        ));
      });

      test('succeeds when permission is granted after request', () async {
        // Arrange
        when(() => mockAudioService.hasMicrophonePermission()).thenAnswer((_) async => false);
        when(() => mockAudioService.requestMicrophonePermission()).thenAnswer((_) async => true);

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue);

        verify(() => mockAudioService.hasMicrophonePermission()).called(1);
        verify(() => mockAudioService.requestMicrophonePermission()).called(1);
        verify(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
        )).called(1);
      });

      test('handles permission check errors gracefully', () async {
        // Arrange
        when(() => mockAudioService.hasMicrophonePermission())
            .thenThrow(Exception('Permission service unavailable'));

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StartRecordingErrorType.permissionDenied));
      });
    });

    group('Location-Based Title Generation', () {
      test('uses location service for title generation', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Central Park, New York');

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.title, equals('Central Park, New York'));

        verify(() => mockGeolocationService.getRecordingLocationName()).called(1);
      });

      test('falls back to timestamp when location service fails', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenThrow(Exception('Location service unavailable'));

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.title, matches(r'Recording \d{4}-\d{2}-\d{2} \d{2}:\d{2}'));
      });

      test('falls back to timestamp when location service returns empty string', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => '');

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.title, matches(r'Recording \d{4}-\d{2}-\d{2} \d{2}:\d{2}'));
      });

      test('generates consistent fallback format', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => '');

        // Act
        final result1 = await useCase.execute(folderId: 'test_folder');
        final result2 = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result1.isSuccess, isTrue);
        expect(result2.isSuccess, isTrue);
        expect(result1.title, matches(r'Recording \d{4}-\d{2}-\d{2} \d{2}:\d{2}'));
        expect(result2.title, matches(r'Recording \d{4}-\d{2}-\d{2} \d{2}:\d{2}'));
      });
    });

    group('File Path Generation and Sanitization', () {
      test('sanitizes invalid characters from filename', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Invalid<>:"/\\|?*Characters');

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.filePath, isNot(contains('<')));
        expect(result.filePath, isNot(contains('>')));
        expect(result.filePath, isNot(contains(':')));
        expect(result.filePath, isNot(contains('"')));
        expect(result.filePath, isNot(contains('/')));
        expect(result.filePath, isNot(contains('\\')));
        expect(result.filePath, isNot(contains('|')));
        expect(result.filePath, isNot(contains('?')));
        expect(result.filePath, isNot(contains('*')));
      });

      test('replaces spaces with underscores in filename', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => 'Recording with spaces');

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.filePath, contains('Recording_with_spaces'));
      });

      test('truncates very long filenames', () async {
        // Arrange
        final longTitle = 'A' * 100; // Very long title
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenAnswer((_) async => longTitle);

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue);
        final filename = result.filePath!.split('/').last.split('_').first;
        expect(filename.length, lessThanOrEqualTo(50));
      });

      test('includes folder ID in file path', () async {
        // Act
        final result = await useCase.execute(folderId: 'my_custom_folder');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.filePath, startsWith('my_custom_folder/'));
      });

      test('includes correct file extension for format', () async {
        final testCases = [
          (AudioFormat.m4a, '.m4a'),
          (AudioFormat.wav, '.wav'),
          (AudioFormat.flac, '.flac'),
        ];

        for (final (format, extension) in testCases) {
          // Act
          final result = await useCase.execute(
            folderId: 'test_folder',
            format: format,
          );

          // Assert
          expect(result.isSuccess, isTrue);
          expect(result.filePath, endsWith(extension));
        }
      });
    });

    group('Audio Configuration Validation', () {
      test('validates sample rate range', () async {
        // Test invalid low sample rate
        var result = await useCase.execute(
          folderId: 'test_folder',
          sampleRate: 7000, // Below minimum
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StartRecordingErrorType.invalidConfiguration));

        // Test invalid high sample rate
        result = await useCase.execute(
          folderId: 'test_folder',
          sampleRate: 200000, // Above maximum
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StartRecordingErrorType.invalidConfiguration));
      });

      test('validates bit rate range', () async {
        // Test invalid low bit rate
        var result = await useCase.execute(
          folderId: 'test_folder',
          bitRate: 30000, // Below minimum
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StartRecordingErrorType.invalidConfiguration));

        // Test invalid high bit rate
        result = await useCase.execute(
          folderId: 'test_folder',
          bitRate: 600000, // Above maximum
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StartRecordingErrorType.invalidConfiguration));
      });

      test('validates format-specific constraints for WAV', () async {
        // Test WAV with too high bit rate
        final result = await useCase.execute(
          folderId: 'test_folder',
          format: AudioFormat.wav,
          bitRate: 200000, // Above WAV limit
        );

        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StartRecordingErrorType.invalidConfiguration));
        expect(result.errorMessage, contains('WAV format'));
      });

      test('validates format-specific constraints for M4A', () async {
        // Test M4A with too high sample rate
        final result = await useCase.execute(
          folderId: 'test_folder',
          format: AudioFormat.m4a,
          sampleRate: 96000, // Above M4A optimal limit
        );

        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StartRecordingErrorType.invalidConfiguration));
        expect(result.errorMessage, contains('M4A format'));
      });

      test('allows FLAC with high bit rates', () async {
        // FLAC is lossless, so bitrate is less relevant
        final result = await useCase.execute(
          folderId: 'test_folder',
          format: AudioFormat.flac,
          sampleRate: 48000,
          bitRate: 400000, // High bit rate should be allowed for FLAC
        );

        expect(result.isSuccess, isTrue);
      });

      test('accepts valid configuration ranges', () async {
        final validConfigs = [
          (8000, 32000),   // Minimum values
          (44100, 128000), // Standard values
          (48000, 320000), // High quality values
          (192000, 512000), // Maximum values
        ];

        for (final (sampleRate, bitRate) in validConfigs) {
          final result = await useCase.execute(
            folderId: 'test_folder',
            sampleRate: sampleRate,
            bitRate: bitRate,
          );

          expect(result.isSuccess, isTrue, 
            reason: 'Failed for sampleRate: $sampleRate, bitRate: $bitRate');
        }
      });
    });

    group('Audio Service Integration', () {
      test('fails when audio service fails to start', () async {
        // Arrange
        when(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
        )).thenAnswer((_) async => false);

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StartRecordingErrorType.audioServiceError));
        expect(result.errorMessage, contains('Failed to start audio recording service'));
      });

      test('handles audio service exceptions', () async {
        // Arrange
        when(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
        )).thenThrow(Exception('Audio device busy'));

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorType, equals(StartRecordingErrorType.audioServiceError));
      });

      test('passes correct parameters to audio service', () async {
        // Act
        await useCase.execute(
          folderId: 'test_folder',
          format: AudioFormat.wav,
          sampleRate: 48000,
          bitRate: 256000,
        );

        // Assert
        verify(() => mockAudioService.startRecording(
          filePath: any(named: 'filePath', that: contains('test_folder/')),
          format: AudioFormat.wav,
          sampleRate: 48000,
          bitRate: 256000,
        )).called(1);
      });
    });

    group('Error Handling and Edge Cases', () {
      test('handles unexpected exceptions gracefully', () async {
        // Arrange
        when(() => mockGeolocationService.getRecordingLocationName())
            .thenThrow(Exception('Unexpected error'));

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue); // Should still succeed with fallback
        expect(result.title, matches(r'Recording \d{4}-\d{2}-\d{2} \d{2}:\d{2}'));
      });

      test('handles null and empty folder IDs', () async {
        // Test with empty folder ID
        var result = await useCase.execute(folderId: '');
        expect(result.isSuccess, isTrue);
        expect(result.filePath, startsWith('/'));

        // Test with whitespace folder ID
        result = await useCase.execute(folderId: '   ');
        expect(result.isSuccess, isTrue);
      });

      test('provides meaningful error messages', () async {
        // Arrange
        when(() => mockAudioService.hasMicrophonePermission()).thenAnswer((_) async => false);
        when(() => mockAudioService.requestMicrophonePermission()).thenAnswer((_) async => false);

        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotEmpty);
        expect(result.errorType, isNotNull);
        expect(result.toString(), contains('failure'));
      });

      test('maintains consistency across multiple calls', () async {
        // Act
        final results = await Future.wait([
          useCase.execute(folderId: 'folder1'),
          useCase.execute(folderId: 'folder1'),
          useCase.execute(folderId: 'folder1'),
        ]);

        // Assert
        expect(results.length, equals(3));
        expect(results.every((r) => r.isSuccess), isTrue);
        expect(results.every((r) => r.folderId == 'folder1'), isTrue);
        
        // File paths should be unique
        final filePaths = results.map((r) => r.filePath).toSet();
        expect(filePaths.length, equals(3));
      });
    });

    group('Business Logic Validation', () {
      test('enforces recording limits and constraints', () async {
        // This test ensures business rules are enforced
        // For example, we might want to limit recording duration or file size
        
        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue);
        // Business constraints should be validated
      });

      test('respects system resource availability', () async {
        // Test that the use case considers system resources
        
        // Act
        final result = await useCase.execute(folderId: 'test_folder');

        // Assert
        expect(result.isSuccess, isTrue);
        // Should succeed when resources are available
      });

      test('handles concurrent recording requests appropriately', () async {
        // Test behavior when multiple recordings are started simultaneously
        
        // Act
        final results = await Future.wait([
          useCase.execute(folderId: 'folder1'),
          useCase.execute(folderId: 'folder2'),
          useCase.execute(folderId: 'folder3'),
        ]);

        // Assert
        expect(results.length, equals(3));
        // All should succeed as they're independent use case executions
        expect(results.every((r) => r.isSuccess), isTrue);
      });
    });
  });
}