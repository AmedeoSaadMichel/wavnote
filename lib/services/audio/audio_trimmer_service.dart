// File: services/audio/audio_trimmer_service.dart
import 'package:flutter/services.dart';

/// Flutter-side wrapper per il native audio trimmer platform channel.
///
/// Channel: wavnote/audio_trimmer
/// Methods: trimAudio, concatenateAudio
class AudioTrimmerService {
  static const MethodChannel _channel =
      MethodChannel('wavnote/audio_trimmer');

  bool _isInitialized = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = true;
    return true;
  }

  /// Taglia [filePath] a [durationMs] millisecondi dall'inizio.
  ///
  /// Il risultato viene scritto in [outputPath]. Se [outputPath] == [filePath],
  /// il file originale viene sostituito atomicamente.
  ///
  /// Lancia [PlatformException] in caso di errore nativo.
  Future<void> trimAudio({
    required String filePath,
    required int durationMs,
    required String format,
    required String outputPath,
  }) async {
    await _channel.invokeMethod<void>('trimAudio', {
      'filePath': filePath,
      'durationMs': durationMs,
      'format': format,
      'outputPath': outputPath,
    });
  }

  /// Concatena [basePath] + [appendPath] → [outputPath].
  ///
  /// Entrambi gli input devono essere nello stesso formato.
  /// Il risultato sostituisce [outputPath].
  /// Lancia [PlatformException] in caso di errore nativo.
  Future<void> concatenateAudio({
    required String basePath,
    required String appendPath,
    required String outputPath,
    required String format,
  }) async {
    await _channel.invokeMethod<void>('concatenateAudio', {
      'basePath': basePath,
      'appendPath': appendPath,
      'outputPath': outputPath,
      'format': format,
    });
  }
}
