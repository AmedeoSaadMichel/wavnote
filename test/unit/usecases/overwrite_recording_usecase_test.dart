// File: test/unit/usecases/overwrite_recording_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wavnote/domain/usecases/recording/overwrite_recording_usecase.dart';
import 'package:wavnote/domain/repositories/i_audio_trimmer_repository.dart';

class MockTrimmerService extends Mock implements IAudioTrimmerRepository {}

void main() {
  late OverwriteRecordingUseCase useCase;
  late MockTrimmerService mockTrimmer;

  setUp(() {
    mockTrimmer = MockTrimmerService();
    useCase = OverwriteRecordingUseCase(trimmerService: mockTrimmer);
    registerFallbackValue(Duration.zero);
  });

  group('OverwriteRecordingUseCase', () {
    test('should call overwriteAudioSegment on the repository', () async {
      // Arrange
      when(
        () => mockTrimmer.overwriteAudioSegment(
          originalPath: any(named: 'originalPath'),
          insertionPath: any(named: 'insertionPath'),
          startTime: any(named: 'startTime'),
          overwriteDuration: any(named: 'overwriteDuration'),
          outputPath: any(named: 'outputPath'),
          format: any(named: 'format'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await useCase.execute(
        originalPath: 'original.wav',
        insertionPath: 'insertion.wav',
        startTime: const Duration(seconds: 2),
        overwriteDuration: const Duration(seconds: 1),
        outputPath: 'final.wav',
        format: 'wav',
      );

      // Assert
      verify(
        () => mockTrimmer.overwriteAudioSegment(
          originalPath: 'original.wav',
          insertionPath: 'insertion.wav',
          startTime: const Duration(seconds: 2),
          overwriteDuration: const Duration(seconds: 1),
          outputPath: 'final.wav',
          format: 'wav',
        ),
      ).called(1);
    });
  });
}
