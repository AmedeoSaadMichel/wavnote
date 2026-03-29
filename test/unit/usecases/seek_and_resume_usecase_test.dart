// File: test/unit/usecases/seek_and_resume_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';

import 'package:wavnote/domain/usecases/recording/seek_and_resume_usecase.dart';
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart';
import 'package:wavnote/services/audio/audio_trimmer_service.dart';
import 'package:wavnote/core/enums/audio_format.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';

class MockAudioService extends Mock implements IAudioServiceRepository {}
class MockTrimmerService extends Mock implements AudioTrimmerService {}

void main() {
  late SeekAndResumeUseCase useCase;
  late MockAudioService mockAudio;
  late MockTrimmerService mockTrimmer;

  setUp(() {
    mockAudio = MockAudioService();
    mockTrimmer = MockTrimmerService();
    useCase = SeekAndResumeUseCase(
      audioService: mockAudio,
      trimmerService: mockTrimmer,
    );
    registerFallbackValue(AudioFormat.m4a);
  });

  group('SeekAndResumeUseCase', () {
    const filePath = '/docs/all_recordings/test_123.m4a';
    final waveData = List<double>.generate(100, (i) => 0.5);
    final fakeEntity = RecordingEntity.create(
      name: 'test',
      filePath: filePath,
      folderId: 'all_recordings',
      format: AudioFormat.m4a,
      duration: const Duration(seconds: 5),
      fileSize: 1000,
      sampleRate: 44100,
    );

    test('happy path: taglia, riavvia, restituisce waveData troncata', () async {
      when(() => mockAudio.stopRecording()).thenAnswer((_) async => fakeEntity);
      when(() => mockTrimmer.trimAudio(
        filePath: any(named: 'filePath'),
        durationMs: any(named: 'durationMs'),
        format: any(named: 'format'),
        outputPath: any(named: 'outputPath'),
      )).thenAnswer((_) async {});
      when(() => mockAudio.startRecording(
        filePath: any(named: 'filePath'),
        format: any(named: 'format'),
        sampleRate: any(named: 'sampleRate'),
        bitRate: any(named: 'bitRate'),
      )).thenAnswer((_) async => true);

      final result = await useCase.execute(
        filePath: filePath,
        seekBarIndex: 40,
        format: AudioFormat.m4a,
        sampleRate: 44100,
        bitRate: 128000,
        waveData: waveData,
      );

      expect(result.isRight(), true);
      final r = result.getOrElse(() => throw Exception());
      expect(r.truncatedWaveData.length, 40);
      expect(r.seekBasePath, contains('_base'));
      // trim chiamato con 40 * 50 = 2000ms
      verify(() => mockTrimmer.trimAudio(
        filePath: filePath,
        durationMs: 2000,
        format: 'm4a',
        outputPath: any(named: 'outputPath'),
      )).called(1);
    });

    test('seekBarIndex == waveData.length - 1: riprende senza trim', () async {
      when(() => mockAudio.resumeRecording()).thenAnswer((_) async => true);

      final result = await useCase.execute(
        filePath: filePath,
        seekBarIndex: waveData.length - 1,
        format: AudioFormat.m4a,
        sampleRate: 44100,
        bitRate: 128000,
        waveData: waveData,
      );

      expect(result.isRight(), true);
      final r = result.getOrElse(() => throw Exception());
      expect(r.seekBasePath, isNull);
      expect(r.truncatedWaveData.length, waveData.length);
      verifyNever(() => mockTrimmer.trimAudio(
        filePath: any(named: 'filePath'),
        durationMs: any(named: 'durationMs'),
        format: any(named: 'format'),
        outputPath: any(named: 'outputPath'),
      ));
    });

    test('errore trim restituisce Left', () async {
      when(() => mockAudio.stopRecording()).thenAnswer((_) async => fakeEntity);
      when(() => mockTrimmer.trimAudio(
        filePath: any(named: 'filePath'),
        durationMs: any(named: 'durationMs'),
        format: any(named: 'format'),
        outputPath: any(named: 'outputPath'),
      )).thenThrow(PlatformException(code: 'TRIM_FAILED', message: 'native error'));

      final result = await useCase.execute(
        filePath: filePath,
        seekBarIndex: 40,
        format: AudioFormat.m4a,
        sampleRate: 44100,
        bitRate: 128000,
        waveData: waveData,
      );

      expect(result.isLeft(), true);
    });

    test('riavvio recorder fallito restituisce Left', () async {
      when(() => mockAudio.stopRecording()).thenAnswer((_) async => fakeEntity);
      when(() => mockTrimmer.trimAudio(
        filePath: any(named: 'filePath'),
        durationMs: any(named: 'durationMs'),
        format: any(named: 'format'),
        outputPath: any(named: 'outputPath'),
      )).thenAnswer((_) async {});
      when(() => mockAudio.startRecording(
        filePath: any(named: 'filePath'),
        format: any(named: 'format'),
        sampleRate: any(named: 'sampleRate'),
        bitRate: any(named: 'bitRate'),
      )).thenAnswer((_) async => false);

      final result = await useCase.execute(
        filePath: filePath,
        seekBarIndex: 40,
        format: AudioFormat.m4a,
        sampleRate: 44100,
        bitRate: 128000,
        waveData: waveData,
      );

      expect(result.isLeft(), true);
    });
  });
}
