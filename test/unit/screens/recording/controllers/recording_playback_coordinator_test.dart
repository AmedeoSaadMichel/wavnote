import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/services/audio/i_audio_playback_engine.dart';
import 'package:wavnote/services/audio/i_audio_preparation_service.dart';
import 'package:wavnote/services/audio/audio_preparation_result.dart';
import 'package:wavnote/services/audio/audio_playback_state.dart';
import 'package:wavnote/presentation/screens/recording/controllers/recording_playback_coordinator.dart';
import 'package:wavnote/presentation/screens/recording/controllers/recording_playback_view_state.dart';
import 'package:dartz/dartz.dart';
import 'dart:async';

class MockAudioPlaybackEngine extends Mock implements IAudioPlaybackEngine {}

class MockAudioPreparationService extends Mock
    implements IAudioPreparationService {}

class MockRecordingEntity extends Mock implements RecordingEntity {}

void main() {
  late RecordingPlaybackCoordinator coordinator;
  late MockAudioPlaybackEngine mockEngine;
  late MockAudioPreparationService mockPreparationService;
  late MockRecordingEntity mockRecording;

  late StreamController<Duration> positionController;
  late StreamController<Duration?> durationController;
  late StreamController<AudioPlaybackState> playbackStateController;
  late StreamController<void> completionController;
  late StreamController<double> amplitudeController;

  setUp(() {
    mockEngine = MockAudioPlaybackEngine();
    mockPreparationService = MockAudioPreparationService();
    mockRecording = MockRecordingEntity();

    positionController = StreamController<Duration>.broadcast();
    durationController = StreamController<Duration?>.broadcast();
    playbackStateController = StreamController<AudioPlaybackState>.broadcast();
    completionController = StreamController<void>.broadcast();
    amplitudeController = StreamController<double>.broadcast();

    when(
      () => mockEngine.positionStream,
    ).thenAnswer((_) => positionController.stream);
    when(
      () => mockEngine.durationStream,
    ).thenAnswer((_) => durationController.stream);
    when(
      () => mockEngine.playbackStateStream,
    ).thenAnswer((_) => playbackStateController.stream);
    when(
      () => mockEngine.completionStream,
    ).thenAnswer((_) => completionController.stream);
    when(
      () => mockEngine.amplitudeStream,
    ).thenAnswer((_) => amplitudeController.stream);

    when(() => mockEngine.initialize()).thenAnswer((_) async => true);
    when(() => mockEngine.stop()).thenAnswer((_) async {});
    when(() => mockEngine.play()).thenAnswer((_) async {});
    when(() => mockEngine.pause()).thenAnswer((_) async {});
    when(
      () => mockPreparationService.clearPrepared(any()),
    ).thenAnswer((_) async {});

    when(() => mockRecording.id).thenReturn('test_recording_1');
    when(
      () => mockRecording.resolvedFilePath,
    ).thenAnswer((_) async => '/fake/path.wav');

    coordinator = RecordingPlaybackCoordinator(
      engine: mockEngine,
      preparationService: mockPreparationService,
    );
  });

  tearDown(() {
    positionController.close();
    durationController.close();
    playbackStateController.close();
    completionController.close();
    amplitudeController.close();
    coordinator.dispose();
  });

  group('RecordingPlaybackCoordinator', () {
    test('Initialization connects streams correctly', () async {
      await coordinator.initialize();
      expect(coordinator.isServiceReady, isTrue);
      verify(() => mockEngine.initialize()).called(1);
    });

    test('Expanding a recording prepares the file and updates state', () async {
      await coordinator.initialize();

      when(() => mockPreparationService.prepare(mockRecording)).thenAnswer(
        (_) async => AudioPreparationResult(
          result: Right(const Duration(seconds: 10)),
          preparedFilePath: '/fake/path.wav',
        ),
      );

      await coordinator.expandRecording(mockRecording);

      // Verify the preparation service was called
      verify(() => mockPreparationService.prepare(mockRecording)).called(1);

      // Verify the state updated correctly
      expect(coordinator.expandedRecordingId, equals('test_recording_1'));
      expect(coordinator.activeRecordingId, equals('test_recording_1'));
      expect(
        coordinator.state.value.status,
        equals(RecordingPlaybackStatus.ready),
      );
      expect(
        coordinator.state.value.duration,
        equals(const Duration(seconds: 10)),
      );
    });

    test('Toggling playback starts playback when ready', () async {
      await coordinator.initialize();

      when(() => mockPreparationService.prepare(mockRecording)).thenAnswer(
        (_) async => AudioPreparationResult(
          result: Right(const Duration(seconds: 10)),
          preparedFilePath: '/fake/path.wav',
        ),
      );

      await coordinator.expandRecording(mockRecording);

      // Simulate engine getting loaded
      playbackStateController.add(AudioPlaybackState.loaded);
      // Let stream microtasks process
      await Future.delayed(Duration.zero);

      await coordinator.togglePlayback();

      verify(() => mockEngine.play()).called(1);
    });
  });
}
