// File: test/unit/services/audio_engine_playback_adapter_test.dart
//
// Test di regressione per AudioEnginePlaybackAdapter.
// Copre il fix 2026-05-07: pause/play ripetuto nella card salvata
// non deve ripartire da zero; la pausa conserva la posizione corrente
// e il seek riallinea la posizione locale.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wavnote/services/audio/audio_engine_service.dart';
import 'package:wavnote/services/audio/audio_engine_playback_adapter.dart';

class MockAudioEngineService extends Mock implements AudioEngineService {}

void main() {
  late MockAudioEngineService engine;
  late AudioEnginePlaybackAdapter adapter;
  late StreamController<PlaybackTick> tickController;
  late StreamController<void> completionController;

  const filePath = '/test/recordings/test.m4a';
  const fileDuration = Duration(seconds: 30);

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    engine = MockAudioEngineService();
    tickController = StreamController<PlaybackTick>.broadcast();
    completionController = StreamController<void>.broadcast();

    when(() => engine.initialize()).thenAnswer((_) async => true);
    when(() => engine.playbackTickStream)
        .thenAnswer((_) => tickController.stream);
    when(() => engine.completionStream)
        .thenAnswer((_) => completionController.stream);
    when(() => engine.getAudioDuration(any()))
        .thenAnswer((_) async => fileDuration);
    when(() => engine.startPlayback(any(), position: any(named: 'position')))
        .thenAnswer((_) async => true);
    when(() => engine.pausePlayback()).thenAnswer((_) async => true);
    when(() => engine.resumePlayback()).thenAnswer((_) async => true);
    when(() => engine.seekTo(any())).thenAnswer((_) async => true);
    when(() => engine.stopPlayback()).thenAnswer((_) async => true);

    adapter = AudioEnginePlaybackAdapter(engineService: engine);
    await adapter.initialize();
  });

  tearDown(() async {
    await tickController.close();
    await completionController.close();
  });

  /// Simula un tick di posizione dal motore nativo e attende la propagazione.
  Future<void> emitTick(Duration position) async {
    tickController.add((position: position, totalDuration: fileDuration));
    await Future<void>.delayed(Duration.zero);
  }

  group('AudioEnginePlaybackAdapter — pause/play conserva la posizione', () {
    test('play dopo pause riprende con resumePlayback, senza restart', () async {
      await adapter.load(filePath);
      await adapter.play();
      await emitTick(const Duration(seconds: 5));

      await adapter.pause();
      expect(adapter.isPlaybackPaused, isTrue);
      expect(adapter.currentPosition, const Duration(seconds: 5));

      await adapter.play();

      // Regressione fix 2026-05-07: senza cache della posizione in pause(),
      // qui partiva startPlayback(position: zero) e l'audio ripartiva da capo.
      verify(() => engine.resumePlayback()).called(1);
      verify(() => engine.startPlayback(filePath, position: null)).called(1);
      verifyNever(() => engine.startPlayback(
            filePath,
            position: Duration.zero,
          ));
      expect(adapter.currentPosition, const Duration(seconds: 5));
      expect(adapter.isPlaying, isTrue);
    });

    test('pause/play ripetuti mantengono la posizione avanzata', () async {
      await adapter.load(filePath);
      await adapter.play();
      await emitTick(const Duration(seconds: 5));
      await adapter.pause();
      await adapter.play();
      await emitTick(const Duration(seconds: 12));
      await adapter.pause();
      await adapter.play();

      verify(() => engine.resumePlayback()).called(2);
      expect(adapter.currentPosition, const Duration(seconds: 12));
    });
  });

  group('AudioEnginePlaybackAdapter — seek', () {
    test('seek in pausa emette la posizione sullo stream, senza seekTo nativo',
        () async {
      await adapter.load(filePath);
      await adapter.play();
      await emitTick(const Duration(seconds: 10));
      await adapter.pause();

      final emitted = <Duration>[];
      final sub = adapter.positionStream.listen(emitted.add);

      await adapter.seek(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);

      // La UI (slider/timer) è guidata dallo stream; la posizione locale
      // si riallinea al play successivo.
      expect(emitted, [const Duration(seconds: 2)]);
      verifyNever(() => engine.seekTo(any()));

      await sub.cancel();
    });

    test('play dopo seek in pausa riparte dalla posizione di seek', () async {
      await adapter.load(filePath);
      await adapter.play();
      await emitTick(const Duration(seconds: 10));
      await adapter.pause();

      await adapter.seek(const Duration(seconds: 2));
      await adapter.play();

      verify(() => engine.startPlayback(
            filePath,
            position: const Duration(seconds: 2),
          )).called(1);
      verifyNever(() => engine.resumePlayback());
      expect(adapter.currentPosition, const Duration(seconds: 2));
    });

    test('seek durante playing chiama seekTo nativo e la posizione '
        'si riallinea col tick successivo', () async {
      await adapter.load(filePath);
      await adapter.play();

      await adapter.seek(const Duration(seconds: 8));

      verify(() => engine.seekTo(const Duration(seconds: 8))).called(1);

      await emitTick(const Duration(seconds: 8));
      expect(adapter.currentPosition, const Duration(seconds: 8));
    });
  });

  group('AudioEnginePlaybackAdapter — load e stop', () {
    test('load legge la durata dai metadati e imposta stato loaded', () async {
      await adapter.load(filePath);

      verify(() => engine.getAudioDuration(filePath)).called(1);
      expect(adapter.currentDuration, fileDuration);
      expect(adapter.isLoaded, isTrue);
      expect(adapter.isPlaying, isFalse);
    });

    test('load con initialPosition fa partire il playback da quella posizione',
        () async {
      await adapter.load(filePath,
          initialPosition: const Duration(seconds: 7));
      await adapter.play();

      verify(() => engine.startPlayback(
            filePath,
            position: const Duration(seconds: 7),
          )).called(1);
    });

    test('stop azzera posizione, file e stato', () async {
      await adapter.load(filePath);
      await adapter.play();
      await emitTick(const Duration(seconds: 5));

      await adapter.stop();

      expect(adapter.currentPosition, Duration.zero);
      expect(adapter.currentFilePath, isNull);
      expect(adapter.isLoaded, isFalse);
      expect(adapter.isPlaying, isFalse);
    });

    test('completamento naturale azzera la posizione ed emette completed',
        () async {
      await adapter.load(filePath);
      await adapter.play();
      await emitTick(const Duration(seconds: 29));

      final states = <dynamic>[];
      final sub = adapter.playbackStateStream.listen(states.add);

      completionController.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(adapter.currentPosition, Duration.zero);
      expect(adapter.isPlaying, isFalse);
      expect(states, isNotEmpty);

      await sub.cancel();
    });
  });
}
