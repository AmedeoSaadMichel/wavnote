// File: lib/services/logging/swift_log_channel_service.dart
// Servizio Dart che riceve i log da iOS (swift-log) tramite EventChannel.
// Espone uno stream di [SwiftLogEntry] a cui altri servizi possono iscriversi.

import 'dart:async';
import 'package:flutter/services.dart';

// MARK: - Modello

/// Singolo record di log ricevuto da Swift.
class SwiftLogEntry {
  final String level;
  final String message;
  final String label;
  final String source;
  final String file;
  final String function;
  final int line;
  final String timestamp;
  final Map<String, String>? metadata;

  const SwiftLogEntry({
    required this.level,
    required this.message,
    required this.label,
    required this.source,
    required this.file,
    required this.function,
    required this.line,
    required this.timestamp,
    this.metadata,
  });

  factory SwiftLogEntry.fromMap(Map<Object?, Object?> map) {
    Map<String, String>? meta;
    final rawMeta = map['metadata'];
    if (rawMeta is Map) {
      meta = rawMeta.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }
    return SwiftLogEntry(
      level: (map['level'] as String?) ?? 'trace',
      message: (map['message'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      source: (map['source'] as String?) ?? '',
      file: (map['file'] as String?) ?? '',
      function: (map['function'] as String?) ?? '',
      line: (map['line'] as int?) ?? 0,
      timestamp: (map['timestamp'] as String?) ?? '',
      metadata: meta,
    );
  }

  @override
  String toString() =>
      '[$timestamp] [$level] [$label] $message  ($file:$line $function)';
}

// MARK: - Servizio

/// Servizio singleton che incapsula l'ascolto dell'EventChannel iOS.
///
/// Uso:
/// ```dart
/// final service = SwiftLogChannelService.instance;
/// service.logs.listen((entry) => print(entry));
/// await service.initialize();
/// ```
class SwiftLogChannelService {
  SwiftLogChannelService._();

  static final SwiftLogChannelService instance = SwiftLogChannelService._();

  static const channelName = 'com.wavnote/swift_logs';
  static const _eventChannel = EventChannel(channelName);

  StreamController<SwiftLogEntry>? _controller;
  StreamSubscription<dynamic>? _subscription;
  bool _isInitialized = false;

  /// Stream broadcast di log ricevuti da Swift.
  /// Iscriviti prima di chiamare [initialize].
  Stream<SwiftLogEntry> get logs {
    _controller ??= StreamController<SwiftLogEntry>.broadcast();
    return _controller!.stream;
  }

  /// Avvia l'ascolto dell'EventChannel. Idempotente.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _controller ??= StreamController<SwiftLogEntry>.broadcast();

    _subscription = _eventChannel
        .receiveBroadcastStream()
        .listen(
          _onEvent,
          onError: _onError,
          cancelOnError: false,
        );
  }

  /// Ferma l'ascolto e chiude il controller.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller?.close();
    _controller = null;
    _isInitialized = false;
  }

  // MARK: - Privato

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final entry = SwiftLogEntry.fromMap(raw as Map<Object?, Object?>);
    _controller?.add(entry);
  }

  void _onError(dynamic error) {
    // Non propaghiamo l'errore sul controller per non chiudere lo stream.
    // L'errore viene solo stampato — sostituire con il logger app se disponibile.
    // ignore: avoid_print
    print('[SwiftLogChannelService] Errore EventChannel: $error');
  }
}
