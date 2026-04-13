// File: services/audio/audio_trimmer_service.dart
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/repositories/i_audio_trimmer_repository.dart';

/// Flutter-side wrapper per il native audio trimmer platform channel.
///
/// Channel: wavnote/audio_trimmer
/// Methods: trimAudio, concatenateAudio
class AudioTrimmerService implements IAudioTrimmerRepository {
  static const MethodChannel _channel = MethodChannel('wavnote/audio_trimmer');

  bool _isInitialized = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = true;
    return true;
  }

  /// Taglia un file audio da [startTime] a [endTime].
  ///
  /// Il risultato viene scritto in [outputPath].
  /// Lancia [PlatformException] in caso di errore nativo.
  @override
  Future<void> trimAudio({
    required String filePath,
    required Duration startTime,
    required Duration endTime,
    required String format,
    required String outputPath,
  }) async {
    final durationMs = (endTime - startTime).inMilliseconds;
    if (durationMs <= 0) {
      throw ArgumentError('La durata del trim deve essere positiva.');
    }
    await _channel.invokeMethod<void>('trimAudio', {
      'filePath': await _resolvePath(filePath),
      'startTimeMs': startTime.inMilliseconds,
      'durationMs': durationMs,
      'format': format,
      'outputPath': await _resolvePath(outputPath),
    });
  }

  /// Concatena [basePath] + [appendPath] → [outputPath].
  ///
  /// Entrambi gli input devono essere nello stesso formato.
  /// Il risultato sostituisce [outputPath].
  /// Lancia [PlatformException] in caso di errore nativo.
  @override
  Future<void> concatenateAudio({
    required String basePath,
    required String appendPath,
    required String outputPath,
    required String format,
  }) async {
    await _channel.invokeMethod<void>('concatenateAudio', {
      'basePath': await _resolvePath(basePath),
      'appendPath': await _resolvePath(appendPath),
      'outputPath': await _resolvePath(outputPath),
      'format': format,
    });
  }

  @override
  Future<void> overwriteAudioSegment({
    required String originalPath,
    required String insertionPath,
    required Duration startTime,
    required Duration overwriteDuration,
    required String outputPath,
    required String format,
  }) async {
    await _channel.invokeMethod<void>('overwriteAudio', {
      'originalPath': await _resolvePath(originalPath),
      'insertionPath': await _resolvePath(insertionPath),
      'startTimeMs': startTime.inMilliseconds,
      'overwriteDurationMs': overwriteDuration.inMilliseconds,
      'outputPath': await _resolvePath(outputPath),
      'format': format,
    });
  }

  /// Risolve un path relativo al documents directory.
  /// I path già assoluti (che iniziano con '/') vengono restituiti invariati.
  Future<String> _resolvePath(String path) async {
    if (path.startsWith('/')) return path;
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$path';
  }
}
