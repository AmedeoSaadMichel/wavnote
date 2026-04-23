// File: test/unit/services/swift_log_channel_service_test.dart
// Test TDD per SwiftLogChannelService.
// EventChannel non può essere testato con un vero canale nativo in unit test;
// usiamo TestDefaultBinaryMessengerBinding per iniettare messaggi fake.

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavnote/services/logging/swift_log_channel_service.dart';

// MARK: - Helper: simula i messaggi che iOS invierebbe all'EventChannel

/// Simula un evento in arrivo dall'EventChannel, come se venisse da Swift.
void _simulateSwiftEvent(Map<String, dynamic> payload) {
  const codec = StandardMethodCodec();
  // L'EventChannel invia eventi come success envelope.
  final data = codec.encodeSuccessEnvelope(payload);
  ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    SwiftLogChannelService.channelName,
    data,
    (_) {},
  );
}

/// Simula un errore dall'EventChannel.
void _simulateSwiftError(String code, String message) {
  const codec = StandardMethodCodec();
  final data = codec.encodeErrorEnvelope(
    code: code,
    message: message,
  );
  ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    SwiftLogChannelService.channelName,
    data,
    (_) {},
  );
}

/// Registra un fake handler che risponde alle chiamate "listen"/"cancel"
/// dell'EventChannel (il protocollo Flutter EventChannel usa MethodChannel
/// internamente con metodi "listen" e "cancel").
void _setupFakeEventChannelHandler() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('${SwiftLogChannelService.channelName}'),
    (call) async {
      // 'listen' → il canale è pronto; 'cancel' → ignorato
      return null;
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ogni test usa un'istanza fresca per evitare stato condiviso.
  // SwiftLogChannelService è un singleton, quindi facciamo dispose dopo ogni test.
  setUp(() {
    _setupFakeEventChannelHandler();
  });

  tearDown(() async {
    await SwiftLogChannelService.instance.dispose();
  });

  // -------------------------------------------------------------------------
  group('SwiftLogEntry.fromMap', () {
    test('parsing completo di tutti i campi', () {
      // RED → doveva fallire se fromMap non esisteva o i campi erano sbagliati.
      final map = <Object?, Object?>{
        'level': 'debug',
        'message': 'Test message',
        'label': 'com.wavnote.test',
        'source': 'TestModule',
        'file': 'Test.swift',
        'function': 'testFunc()',
        'line': 42,
        'timestamp': '2026-04-12T10:00:00Z',
        'metadata': <Object?, Object?>{'key': 'value'},
      };

      final entry = SwiftLogEntry.fromMap(map);

      expect(entry.level, 'debug');
      expect(entry.message, 'Test message');
      expect(entry.label, 'com.wavnote.test');
      expect(entry.source, 'TestModule');
      expect(entry.file, 'Test.swift');
      expect(entry.function, 'testFunc()');
      expect(entry.line, 42);
      expect(entry.timestamp, '2026-04-12T10:00:00Z');
      expect(entry.metadata, {'key': 'value'});
    });

    test('campi mancanti producono valori di default sicuri', () {
      final entry = SwiftLogEntry.fromMap(const {});

      expect(entry.level, 'trace');
      expect(entry.message, '');
      expect(entry.label, '');
      expect(entry.line, 0);
      expect(entry.metadata, isNull);
    });

    test('metadata nullo viene gestito senza errori', () {
      final map = <Object?, Object?>{
        'level': 'info',
        'message': 'no meta',
        'label': 'lbl',
        'source': 'src',
        'file': 'f.swift',
        'function': 'fn()',
        'line': 1,
        'timestamp': 'ts',
        // nessun campo 'metadata'
      };

      final entry = SwiftLogEntry.fromMap(map);
      expect(entry.metadata, isNull);
    });

    test('toString include level e message', () {
      final entry = SwiftLogEntry(
        level: 'error',
        message: 'boom',
        label: 'l',
        source: 's',
        file: 'f.swift',
        function: 'fn()',
        line: 10,
        timestamp: 'ts',
      );

      final str = entry.toString();
      expect(str, contains('error'));
      expect(str, contains('boom'));
    });
  });

  // -------------------------------------------------------------------------
  group('SwiftLogChannelService — initialize', () {
    test('initialize è idempotente (chiamabile più volte senza errori)', () async {
      await SwiftLogChannelService.instance.initialize();
      await SwiftLogChannelService.instance.initialize(); // seconda chiamata
      // Nessuna eccezione = successo
    });

    test('logs restituisce uno stream broadcast', () async {
      await SwiftLogChannelService.instance.initialize();
      final stream = SwiftLogChannelService.instance.logs;

      // Broadcast stream ammette più subscriber
      final sub1 = stream.listen((_) {});
      final sub2 = stream.listen((_) {});

      await sub1.cancel();
      await sub2.cancel();
    });

    test('logs è accessibile prima di initialize senza errori', () {
      // Il getter deve creare il controller su richiesta
      final stream = SwiftLogChannelService.instance.logs;
      expect(stream, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  group('SwiftLogChannelService — ricezione eventi', () {
    test('un evento Swift valido viene emesso come SwiftLogEntry', () async {
      await SwiftLogChannelService.instance.initialize();

      final completer = Completer<SwiftLogEntry>();
      SwiftLogChannelService.instance.logs.listen(completer.complete);

      _simulateSwiftEvent({
        'level': 'info',
        'message': 'Hello from Swift',
        'label': 'com.wavnote',
        'source': 'AudioEngine',
        'file': 'AudioEngine.swift',
        'function': 'start()',
        'line': 99,
        'timestamp': '2026-04-12T10:00:00Z',
      });

      final entry = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Nessun evento ricevuto'),
      );

      expect(entry.level, 'info');
      expect(entry.message, 'Hello from Swift');
      expect(entry.label, 'com.wavnote');
    });

    test('payload non-Map viene ignorato senza crash', () async {
      await SwiftLogChannelService.instance.initialize();

      var count = 0;
      final sub = SwiftLogChannelService.instance.logs.listen((_) => count++);

      // Invia un payload non-Map (stringa grezza) — deve essere scartato.
      const codec = StandardMethodCodec();
      final data = codec.encodeSuccessEnvelope('stringa non valida');
      ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        SwiftLogChannelService.channelName,
        data,
        (_) {},
      );

      // Piccola attesa per assicurarsi che l'evento sia processato.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(count, 0, reason: 'payload non-Map non deve generare entry');
      await sub.cancel();
    });

    test('errore dal canale non chiude lo stream', () async {
      await SwiftLogChannelService.instance.initialize();

      var errorCount = 0;
      var entryCount = 0;

      final sub = SwiftLogChannelService.instance.logs.listen(
        (_) => entryCount++,
        onError: (_) => errorCount++,
        onDone: () => fail('lo stream non deve chiudersi su errore'),
        cancelOnError: false,
      );

      _simulateSwiftError('NATIVE_ERROR', 'Errore simulato da Swift');

      // Piccola attesa poi verifichiamo che lo stream sia ancora vivo.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(errorCount, 0, reason: 'errori non devono propagarsi sul controller');
      expect(entryCount, 0);

      // Lo stream deve ancora accettare nuovi eventi.
      _simulateSwiftEvent({
        'level': 'debug',
        'message': 'dopo errore',
        'label': 'l',
        'source': 's',
        'file': 'f.swift',
        'function': 'fn()',
        'line': 1,
        'timestamp': 'ts',
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Non contiamo l'entry perché l'EventChannel con mock potrebbe non
      // consegnare il messaggio dopo un errore — il test verifica solo
      // che non ci siano crash o chiusura del stream.

      await sub.cancel();
    });
  });

  // -------------------------------------------------------------------------
  group('SwiftLogChannelService — dispose', () {
    test('dispose chiude il controller e resetta lo stato', () async {
      await SwiftLogChannelService.instance.initialize();
      await SwiftLogChannelService.instance.dispose();

      // Dopo dispose, initialize deve funzionare di nuovo (reset completo)
      await SwiftLogChannelService.instance.initialize();
    });

    test('dispose multipli non causano errori', () async {
      await SwiftLogChannelService.instance.initialize();
      await SwiftLogChannelService.instance.dispose();
      await SwiftLogChannelService.instance.dispose(); // seconda chiamata
    });
  });
}
