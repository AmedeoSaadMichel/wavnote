// File: domain/usecases/recording/seek_and_resume_usecase.dart
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/enums/audio_format.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import '../../../services/audio/audio_trimmer_service.dart';

class SeekAndResumeUseCase {
  final IAudioServiceRepository _audioService;
  final AudioTrimmerService _trimmerService;

  SeekAndResumeUseCase({
    required IAudioServiceRepository audioService,
    required AudioTrimmerService trimmerService,
  })  : _audioService = audioService,
        _trimmerService = trimmerService;

  Future<Either<Failure, SeekAndResumeResult>> execute({
    required String filePath,
    required int seekBarIndex,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
    required List<double> waveData,
  }) async {
    try {
      final lastBarIndex = waveData.isEmpty ? 0 : waveData.length - 1;

      // Seek senza trim: basta riprendere normalmente
      if (seekBarIndex >= lastBarIndex) {
        final resumed = await _audioService.resumeRecording();
        if (!resumed) {
          return Left(AudioRecordingFailure.startFailed('Impossibile riprendere la registrazione'));
        }
        return Right(SeekAndResumeResult(
          seekBasePath: null,
          truncatedWaveData: List<double>.from(waveData),
        ));
      }

      final trimDurationMs = seekBarIndex * 50;

      // 1. Ferma il recorder in raw mode → restituisce WAV grezzo (Approccio 1)
      final entity = await _audioService.stopRecording(raw: true);
      if (entity == null) {
        return Left(AudioRecordingFailure.stopFailed('Impossibile fare flush della registrazione per il trim'));
      }

      // entity.filePath è il path WAV interno
      final absoluteFilePath = entity.filePath;

      // 2. Taglia e salva il contenuto pre-seek nella basePath (WAV → WAV, lossless)
      final basePath = _buildBasePath(absoluteFilePath);
      try {
        await _trimmerService.trimAudio(
          filePath: absoluteFilePath,
          durationMs: trimDurationMs,
          format: 'wav', // Approccio 1: trim su WAV è sempre lossless (Passthrough)
          outputPath: basePath,
        );
      } on PlatformException catch (e) {
        return Left(AudioRecordingFailure.startFailed('Trim fallito: ${e.message}'));
      }

      // 3. Tronca waveData al punto di seek
      final truncated = waveData.sublist(0, seekBarIndex);

      // 4. Riavvia il recorder sul path originale (nuova registrazione dal seek in poi)
      final started = await _audioService.startRecording(
        filePath: filePath,
        format: format,
        sampleRate: sampleRate,
        bitRate: bitRate,
      );
      if (!started) {
        return Left(AudioRecordingFailure.startFailed(
          'Impossibile riavviare la registrazione dopo il trim',
        ));
      }

      return Right(SeekAndResumeResult(
        seekBasePath: basePath,
        truncatedWaveData: truncated,
      ));
    } catch (e, st) {
      debugPrint('❌ SeekAndResumeUseCase: $e\n$st');
      return Left(UnexpectedFailure(
        message: 'Errore inatteso durante seek-and-resume: $e',
        code: 'SEEK_RESUME_UNEXPECTED',
      ));
    }
  }

  /// Costruisce il path per il file base pre-seek.
  /// Es.: /docs/.../recording_123.m4a → /docs/.../recording_123_base.m4a
  String _buildBasePath(String filePath) {
    final dot = filePath.lastIndexOf('.');
    if (dot < 0) return '${filePath}_base';
    return '${filePath.substring(0, dot)}_base${filePath.substring(dot)}';
  }
}

class SeekAndResumeResult {
  /// Path assoluto del file base tagliato (null se non è stato necessario tagliare).
  final String? seekBasePath;

  /// waveData troncata a seekBarIndex voci.
  final List<double> truncatedWaveData;

  const SeekAndResumeResult({
    required this.seekBasePath,
    required this.truncatedWaveData,
  });
}
