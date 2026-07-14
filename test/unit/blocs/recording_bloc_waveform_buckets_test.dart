// File: test/unit/blocs/recording_bloc_waveform_buckets_test.dart
//
// Test dei bucket waveform nativi (RecordingWaveformBucketBatch → BLoC).
// Coprono _onUpdateRecordingWaveformBuckets: accumulo campioni, dedup dei
// batch stale, cap a 3000 campioni, comportamento in pausa (lo stream resta
// vivo fino al flush finale) e il wiring stream → evento dopo StartRecording.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart';
import 'package:wavnote/domain/entities/recording_waveform_bucket_batch.dart';
import 'package:wavnote/domain/repositories/i_audio_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/domain/repositories/i_location_repository.dart';
import 'package:wavnote/domain/repositories/i_audio_trimmer_repository.dart';
import 'package:wavnote/domain/usecases/recording/start_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/stop_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/pause_recording_usecase.dart'
    hide RecordingState;
import 'package:wavnote/core/enums/audio_format.dart';
import 'package:wavnote/config/dependency_injection.dart';

import '../../helpers/test_helpers.dart';

class MockAudioService extends Mock implements IAudioRecordingRepository {}

class MockRecordingRepository extends Mock implements IRecordingRepository {}

class MockLocationRepository extends Mock implements ILocationRepository {}

class MockStartUseCase extends Mock implements StartRecordingUseCase {}

class MockStopUseCase extends Mock implements StopRecordingUseCase {}

class MockPauseUseCase extends Mock implements PauseRecordingUseCase {}

class MockTrimmerRepository extends Mock implements IAudioTrimmerRepository {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('RecordingBloc — waveform bucket nativi', () {
    late RecordingBloc bloc;
    late MockAudioService mockAudio;
    late MockStartUseCase mockStartUseCase;
    late StreamController<RecordingWaveformBucketBatch> bucketController;

    RecordingInProgress inProgressState({
      List<double> samples = const [],
      int sampleCount = 0,
    }) {
      return RecordingInProgress(
        filePath: '/test/recording.wav',
        folderId: 'all_recordings',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitRate: 128000,
        duration: const Duration(seconds: 5),
        amplitude: 0.5,
        startTime: DateTime(2026, 7, 14),
        waveformAmplitudeSamples: samples,
        waveformAmplitudeSampleCount: sampleCount,
      );
    }

    RecordingPaused pausedState({
      List<double> samples = const [],
      int sampleCount = 0,
    }) {
      return RecordingPaused(
        filePath: '/test/recording.wav',
        folderId: 'all_recordings',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitRate: 128000,
        duration: const Duration(seconds: 5),
        startTime: DateTime(2026, 7, 14),
        waveformAmplitudeSamples: samples,
        waveformAmplitudeSampleCount: sampleCount,
      );
    }

    setUp(() {
      mockAudio = MockAudioService();
      mockStartUseCase = MockStartUseCase();
      bucketController =
          StreamController<RecordingWaveformBucketBatch>.broadcast();

      when(() => mockAudio.initialize()).thenAnswer((_) async => true);
      when(() => mockAudio.dispose()).thenAnswer((_) async {});
      when(() => mockAudio.needsDisposal).thenReturn(false);
      when(
        () => mockAudio.getRecordingAmplitudeStream(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockAudio.externalControlStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockAudio.getRecordingWaveformBucketStream(),
      ).thenAnswer((_) => bucketController.stream);
      when(() => mockAudio.durationStream).thenReturn(null);
      when(
        () => mockAudio.getCurrentRecordingDuration(),
      ).thenAnswer((_) async => Duration.zero);

      if (!sl.isRegistered<IAudioTrimmerRepository>()) {
        sl.registerSingleton<IAudioTrimmerRepository>(MockTrimmerRepository());
      }

      final mockLocation = MockLocationRepository();
      when(
        () => mockLocation.getRecordingLocationName(),
      ).thenAnswer((_) async => '');

      bloc = RecordingBloc(
        audioService: mockAudio,
        recordingRepository: MockRecordingRepository(),
        locationRepository: mockLocation,
        startRecordingUseCase: mockStartUseCase,
        stopRecordingUseCase: MockStopUseCase(),
        pauseRecordingUseCase: MockPauseUseCase(),
      );
    });

    tearDown(() async {
      await bloc.close();
      await bucketController.close();
      if (sl.isRegistered<IAudioTrimmerRepository>()) {
        sl.unregister<IAudioTrimmerRepository>();
      }
    });

    blocTest<RecordingBloc, RecordingState>(
      'InProgress: il primo batch popola waveformAmplitudeSamples e il count',
      build: () => bloc,
      seed: () => inProgressState(),
      act: (b) => b.add(
        const UpdateRecordingWaveformBuckets(
          RecordingWaveformBucketBatch(
            startIndex: 0,
            samples: [0.1, 0.2, 0.3],
            totalCount: 3,
          ),
        ),
      ),
      expect: () => [
        isA<RecordingInProgress>()
            .having(
              (s) => s.waveformAmplitudeSamples,
              'waveformAmplitudeSamples',
              [0.1, 0.2, 0.3],
            )
            .having(
              (s) => s.waveformAmplitudeSampleCount,
              'waveformAmplitudeSampleCount',
              3,
            ),
      ],
    );

    blocTest<RecordingBloc, RecordingState>(
      'InProgress: i batch successivi vengono accodati ai campioni esistenti',
      build: () => bloc,
      seed: () => inProgressState(samples: [0.1, 0.2], sampleCount: 2),
      act: (b) => b.add(
        const UpdateRecordingWaveformBuckets(
          RecordingWaveformBucketBatch(
            startIndex: 2,
            samples: [0.3, 0.4],
            totalCount: 4,
          ),
        ),
      ),
      expect: () => [
        isA<RecordingInProgress>()
            .having(
              (s) => s.waveformAmplitudeSamples,
              'waveformAmplitudeSamples',
              [0.1, 0.2, 0.3, 0.4],
            )
            .having(
              (s) => s.waveformAmplitudeSampleCount,
              'waveformAmplitudeSampleCount',
              4,
            ),
      ],
    );

    blocTest<RecordingBloc, RecordingState>(
      'Paused: i batch vengono applicati anche in pausa '
      '(lo stream resta vivo fino al flush finale)',
      build: () => bloc,
      seed: () => pausedState(samples: [0.1], sampleCount: 1),
      act: (b) => b.add(
        const UpdateRecordingWaveformBuckets(
          RecordingWaveformBucketBatch(
            startIndex: 1,
            samples: [0.2, 0.3],
            totalCount: 3,
          ),
        ),
      ),
      expect: () => [
        isA<RecordingPaused>()
            .having(
              (s) => s.waveformAmplitudeSamples,
              'waveformAmplitudeSamples',
              [0.1, 0.2, 0.3],
            )
            .having(
              (s) => s.waveformAmplitudeSampleCount,
              'waveformAmplitudeSampleCount',
              3,
            ),
      ],
    );

    blocTest<RecordingBloc, RecordingState>(
      'batch stale (totalCount <= count corrente) viene ignorato senza emissioni',
      build: () => bloc,
      seed: () => inProgressState(samples: [0.1, 0.2, 0.3], sampleCount: 3),
      act: (b) => b.add(
        const UpdateRecordingWaveformBuckets(
          RecordingWaveformBucketBatch(
            startIndex: 0,
            samples: [0.9, 0.9, 0.9],
            totalCount: 3, // uguale al count già in stato → duplicato
          ),
        ),
      ),
      expect: () => <RecordingState>[],
    );

    blocTest<RecordingBloc, RecordingState>(
      'cap a 3000 campioni: l\'overflow viene rimosso dalla testa (i più vecchi)',
      build: () => bloc,
      seed: () => inProgressState(
        samples: List<double>.filled(3000, 0.5),
        sampleCount: 3000,
      ),
      act: (b) => b.add(
        const UpdateRecordingWaveformBuckets(
          RecordingWaveformBucketBatch(
            startIndex: 3000,
            samples: [0.7, 0.8],
            totalCount: 3002,
          ),
        ),
      ),
      expect: () => [
        isA<RecordingInProgress>()
            .having(
              (s) => s.waveformAmplitudeSamples.length,
              'lunghezza dopo cap',
              3000,
            )
            // Gli ultimi 2 campioni sono quelli nuovi appena arrivati.
            .having(
              (s) => s.waveformAmplitudeSamples.sublist(2998),
              'coda (campioni nuovi)',
              [0.7, 0.8],
            )
            .having(
              (s) => s.waveformAmplitudeSampleCount,
              'waveformAmplitudeSampleCount',
              3002,
            ),
      ],
    );

    blocTest<RecordingBloc, RecordingState>(
      'stato non-recording (Initial): il batch viene ignorato',
      build: () => bloc,
      act: (b) => b.add(
        const UpdateRecordingWaveformBuckets(
          RecordingWaveformBucketBatch(
            startIndex: 0,
            samples: [0.1],
            totalCount: 1,
          ),
        ),
      ),
      expect: () => <RecordingState>[],
    );

    blocTest<RecordingBloc, RecordingState>(
      'wiring: dopo StartRecording i batch dello stream nativo '
      'arrivano allo stato del bloc',
      build: () {
        when(
          () => mockStartUseCase.execute(
            folderId: any(named: 'folderId'),
            format: any(named: 'format'),
            sampleRate: any(named: 'sampleRate'),
            bitRate: any(named: 'bitRate'),
          ),
        ).thenAnswer(
          (_) async => Right(
            StartRecordingSuccess(
              filePath: '/test/recording.wav',
              title: 'Test Recording',
              folderId: 'all_recordings',
              format: AudioFormat.wav,
              sampleRate: 44100,
              bitRate: 128000,
              startTime: DateTime(2026, 7, 14),
            ),
          ),
        );
        return bloc;
      },
      act: (b) async {
        b.add(
          const StartRecording(
            folderId: 'all_recordings',
            format: AudioFormat.wav,
          ),
        );
        // Attende che il bloc si sottoscriva allo stream in _startAmplitudeUpdates.
        await Future<void>.delayed(Duration.zero);
        bucketController.add(
          const RecordingWaveformBucketBatch(
            startIndex: 0,
            samples: [0.4, 0.5],
            totalCount: 2,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<RecordingStarting>(),
        isA<RecordingInProgress>().having(
          (s) => s.waveformAmplitudeSamples,
          'waveformAmplitudeSamples iniziali',
          isEmpty,
        ),
        isA<RecordingInProgress>()
            .having(
              (s) => s.waveformAmplitudeSamples,
              'waveformAmplitudeSamples dal nativo',
              [0.4, 0.5],
            )
            .having(
              (s) => s.waveformAmplitudeSampleCount,
              'waveformAmplitudeSampleCount',
              2,
            ),
      ],
    );
  });
}
