// File: test/unit/services/audio_engine_service_recording_status_test.dart
// Test del contratto Dart ↔ nativo per getRecordingStatus e tick cumulativi.
// Contesto: fix 2026-07-15 sul plugin macOS (branch fix/macos-recording-status-frames):
// il plugin macOS ora implementa getRecordingStatus e posizione cumulativa
// attraverso pause/resume, con lo stesso payload di iOS. Questi test fissano
// il contratto che entrambi i plugin nativi devono rispettare, simulando le
// risposte native con un mock del MethodChannel.

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavnote/services/audio/audio_engine_service.dart';

const _methodChannel = MethodChannel('com.wavnote/audio_engine');
const _clockChannelName = 'com.wavnote/audio_engine/clock_events';
const _playbackChannelName = 'com.wavnote/audio_engine/playback_events';

/// Registra un handler fake sul method channel del motore audio.
void _mockMethodChannel(
  Future<Object?> Function(MethodCall call) handler,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_methodChannel, handler);
}

/// Gli EventChannel usano un MethodChannel interno con 'listen'/'cancel'.
void _mockEventChannels() {
  for (final name in [_clockChannelName, _playbackChannelName]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }
}

/// Simula un evento push dal ClockStreamHandler nativo (recordingTick ecc.).
void _simulateClockEvent(Map<String, dynamic> payload) {
  const codec = StandardMethodCodec();
  final data = codec.encodeSuccessEnvelope(payload);
  ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    _clockChannelName,
    data,
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    _mockMethodChannel((call) async => null);
  });

  // ---------------------------------------------------------------------
  group('AudioEngineRecordingStatus.fromMap — payload nativo', () {
    test('parsa il payload completo emesso da iOS e macOS', () {
      final status = AudioEngineRecordingStatus.fromMap(<dynamic, dynamic>{
        'isRecording': true,
        'isPaused': false,
        'path': '/tmp/rec_cnt1.wav',
        'durationMs': 12345,
        'amplitude': 0.42,
      });

      expect(status.isRecording, isTrue);
      expect(status.isPaused, isFalse);
      expect(status.path, '/tmp/rec_cnt1.wav');
      expect(status.duration, const Duration(milliseconds: 12345));
      expect(status.amplitude, closeTo(0.42, 0.0001));
    });

    test('map null produce stato idle', () {
      final status = AudioEngineRecordingStatus.fromMap(null);

      expect(status.isRecording, isFalse);
      expect(status.isPaused, isFalse);
      expect(status.path, isNull);
      expect(status.duration, Duration.zero);
    });

    test('path null (NSNull nativo) e campi mancanti → default sicuri', () {
      final status = AudioEngineRecordingStatus.fromMap(<dynamic, dynamic>{
        'isRecording': true,
        'isPaused': true,
        'path': null,
      });

      expect(status.isRecording, isTrue);
      expect(status.isPaused, isTrue);
      expect(status.path, isNull);
      expect(status.duration, Duration.zero);
      expect(status.amplitude, 0.0);
    });

    test('amplitude fuori range viene clampata a [0,1]', () {
      final over = AudioEngineRecordingStatus.fromMap(
        <dynamic, dynamic>{'amplitude': 3.5},
      );
      final under = AudioEngineRecordingStatus.fromMap(
        <dynamic, dynamic>{'amplitude': -1.0},
      );

      expect(over.amplitude, 1.0);
      expect(under.amplitude, 0.0);
    });
  });

  // ---------------------------------------------------------------------
  group('getRecordingStatus — method channel', () {
    test('con plugin che risponde (nuovo macOS), sincronizza i flag interni',
        () async {
      _mockMethodChannel((call) async {
        if (call.method == 'getRecordingStatus') {
          return <String, dynamic>{
            'isRecording': true,
            'isPaused': true,
            'path': '/tmp/rec_cnt2.wav',
            'durationMs': 8000,
            'amplitude': 0.0,
          };
        }
        return null;
      });

      final service = AudioEngineService();
      final status = await service.getRecordingStatus();

      expect(status.isRecording, isTrue);
      expect(status.isPaused, isTrue);
      expect(status.duration, const Duration(seconds: 8));
      // I flag interni del servizio devono riflettere lo stato nativo reale.
      expect(service.isRecording, isTrue);
      expect(service.isRecordingPaused, isTrue);
      expect(service.currentRecordingPath, '/tmp/rec_cnt2.wav');
    });

    test(
        'con plugin che NON implementa il metodo (vecchio macOS), '
        'degrada a idle senza toccare i flag interni', () async {
      _mockMethodChannel((call) async {
        if (call.method == 'getRecordingStatus') {
          throw MissingPluginException('not implemented');
        }
        return null;
      });

      final service = AudioEngineService();
      final status = await service.getRecordingStatus();

      // Comportamento documentato pre-fix: il catch ritorna idle.
      // È questo idle che, passato a syncRecordingStatusFromNative,
      // causava il desync su macOS al ritorno del focus finestra.
      expect(status.isRecording, isFalse);
      expect(status.path, isNull);
      expect(service.isRecording, isFalse);
    });
  });

  // ---------------------------------------------------------------------
  group('syncRecordingStatusFromNative — reconcile al foreground', () {
    test('registrazione attiva → flag sincronizzati, nessun evento', () {
      final service = AudioEngineService();

      final event = service.syncRecordingStatusFromNative(
        const AudioEngineRecordingStatus(
          isRecording: true,
          isPaused: false,
          path: '/tmp/rec.wav',
          duration: Duration(seconds: 30),
          amplitude: 0.5,
        ),
      );

      expect(event, isNull, reason: 'nessuna transizione di pausa');
      expect(service.isRecording, isTrue);
      expect(service.isRecordingPaused, isFalse);
      expect(service.currentRecordingPath, '/tmp/rec.wav');
    });

    test('transizione a pausa avvenuta in nativo → evento pause completed',
        () {
      final service = AudioEngineService();
      // Stato di partenza: registrazione attiva non in pausa.
      service.syncRecordingStatusFromNative(
        const AudioEngineRecordingStatus(
          isRecording: true,
          isPaused: false,
          path: '/tmp/rec.wav',
          duration: Duration(seconds: 10),
          amplitude: 0.5,
        ),
      );

      final event = service.syncRecordingStatusFromNative(
        const AudioEngineRecordingStatus(
          isRecording: true,
          isPaused: true,
          path: '/tmp/rec.wav',
          duration: Duration(seconds: 15),
          amplitude: 0.0,
        ),
      );

      expect(event, isNotNull);
      expect(event!.action.name, 'pause');
      expect(event.duration, const Duration(seconds: 15));
      expect(service.isRecordingPaused, isTrue);
    });

    test('status idle → azzera flag e path (il desync pre-fix su macOS)', () {
      final service = AudioEngineService();
      service.syncRecordingStatusFromNative(
        const AudioEngineRecordingStatus(
          isRecording: true,
          isPaused: false,
          path: '/tmp/rec.wav',
          duration: Duration(seconds: 10),
          amplitude: 0.5,
        ),
      );

      final event = service.syncRecordingStatusFromNative(
        const AudioEngineRecordingStatus.idle(),
      );

      expect(event, isNull);
      expect(service.isRecording, isFalse);
      expect(service.currentRecordingPath, isNull,
          reason: 'idle azzera il path: per questo il vecchio plugin macOS '
              'senza getRecordingStatus faceva perdere la registrazione');
    });
  });

  // ---------------------------------------------------------------------
  group('recordingTick — posizione cumulativa dal clock nativo', () {
    test('i tick con positionMs cumulativi arrivano ordinati sullo stream',
        () async {
      _mockMethodChannel((call) async {
        if (call.method == 'initialize') return true;
        return null;
      });
      _mockEventChannels();

      final service = AudioEngineService();
      await service.initialize();

      final received = <Duration>[];
      final sub = service.recordingTickStream.listen(
        (tick) => received.add(tick.position),
      );

      // Simula la sequenza del plugin macOS fixato: segmento 1 (0→5s),
      // pausa, resume — il tick riparte CUMULATIVO da 5s, non da 0.
      _simulateClockEvent(
        {'type': 'recordingTick', 'positionMs': 4900, 'amplitude': 0.3},
      );
      _simulateClockEvent(
        {'type': 'recordingTick', 'positionMs': 5000, 'amplitude': 0.3},
      );
      _simulateClockEvent(
        {'type': 'recordingTick', 'positionMs': 5100, 'amplitude': 0.4},
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(received, const [
        Duration(milliseconds: 4900),
        Duration(milliseconds: 5000),
        Duration(milliseconds: 5100),
      ]);
      expect(
        received.last > received.first,
        isTrue,
        reason: 'dopo il resume la posizione deve restare monotona crescente',
      );

      await sub.cancel();
      await service.dispose();
    });
  });
}
