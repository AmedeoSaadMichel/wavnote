// File: lib/services/audio/audio_preparation_service.dart
import 'package:flutter/foundation.dart';
import 'package:wavnote/core/errors/failure_utils.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/services/audio/audio_cache_manager.dart';
import 'package:dartz/dartz.dart';
import 'package:wavnote/core/errors/failures.dart';

import 'audio_preparation_result.dart';
import 'i_audio_playback_engine.dart';
import 'i_audio_preparation_service.dart';

class AudioPreparationService implements IAudioPreparationService {
  final IAudioPlaybackEngine _engine;
  final AudioCacheManager _cacheManager;

  // Mappa per tenere traccia dei file preparati e della loro durata
  final Map<String, Duration> _preparedFiles = {};

  AudioPreparationService({
    required IAudioPlaybackEngine engine,
    required AudioCacheManager cacheManager,
  }) : _engine = engine,
       _cacheManager = cacheManager;

  @override
  Future<AudioPreparationResult> prepare(RecordingEntity recording) async {
    final absolutePath = await recording.resolvedFilePath;
    if (kDebugMode) debugPrint('🔄 AUDIO_PREP_SVC: Preparing $absolutePath');

    // Se il file è già quello caricato nell'engine e l'engine lo considera pronto
    if (_engine.currentFilePath == absolutePath && _engine.isLoaded) {
      if (kDebugMode) {
        debugPrint(
          '✅ AUDIO_PREP_SVC: File already loaded and prepared: $absolutePath',
        );
      }
      return AudioPreparationResult(
        result: Right(_engine.currentDuration),
        preparedFilePath: absolutePath,
      );
    }

    try {
      // Carica il file nell'engine senza riprodurlo
      await _engine.load(absolutePath);

      final Duration duration = _engine.currentDuration != Duration.zero
          ? _engine.currentDuration
          : recording.duration;

      _preparedFiles[absolutePath] = duration;
      if (kDebugMode) {
        debugPrint(
          '✅ AUDIO_PREP_SVC: File prepared successfully: $absolutePath (Duration: $duration)',
        );
      }

      return AudioPreparationResult(
        result: Right(duration),
        preparedFilePath: absolutePath,
      );
    } catch (e) {
      final failure = FailureUtils.convertExceptionToFailure(
        e,
        contextMessage: 'Failed to prepare audio',
      );
      return AudioPreparationResult(
        result: Left(failure),
        preparedFilePath: absolutePath,
      );
    }
  }

  @override
  bool isPrepared(String filePath) => _preparedFiles.containsKey(filePath);

  @override
  Future<void> clearPrepared(String filePath) async {
    _preparedFiles.remove(filePath);
  }

  @override
  Future<void> clearAll() async {
    _preparedFiles.clear();
  }

  @override
  Future<void> dispose() async {
    _preparedFiles.clear();
  }
}
