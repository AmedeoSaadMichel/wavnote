// File: domain/usecases/recording/start_recording_usecase.dart
//
// Start Recording Use Case - Domain Layer
// ========================================
//
// Returns Either<Failure, StartRecordingSuccess> following the canonical
// Either pattern (CLAUDE.md). The BLoC consumes via result.fold(left, right).
//
// Steps: validate permissions → build file path (titolo temporaneo)
//        → validate config → start audio service
//        La risoluzione del titolo geolocalizzato avviene in background nel BLoC.

import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../core/enums/audio_format.dart';
import '../../../core/errors/failures.dart';
import '../../../core/errors/exceptions.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import '../../../services/location/geolocation_service.dart';

/// Use case for starting a new audio recording.
///
/// Returns [Either<Failure, StartRecordingSuccess>]:
/// - [Left]  — a [Failure] (permission, config, audio service error)
/// - [Right] — [StartRecordingSuccess] con titolo temporaneo (timestamp).
///             Il BLoC risolve il titolo geolocalizzato in background e
///             aggiorna lo stato via [UpdateRecordingTitle].
class StartRecordingUseCase {
  final IAudioServiceRepository _audioService;
  // Mantenuto per retrocompatibilità; non più usato nell'avvio.
  // ignore: unused_field
  final GeolocationService _geolocationService;

  StartRecordingUseCase({
    required IAudioServiceRepository audioService,
    required GeolocationService geolocationService,
  })  : _audioService = audioService,
        _geolocationService = geolocationService;

  Future<Either<Failure, StartRecordingSuccess>> execute({
    required String folderId,
    AudioFormat format = AudioFormat.m4a,
    int sampleRate = 44100,
    int bitRate = 128000,
  }) async {
    try {
      // 1. Validate microphone permissions
      if (!await _ensureMicrophonePermission()) {
        return Left(AudioRecordingFailure.permissionDenied());
      }

      // 2. Titolo temporaneo sincrono — la registrazione parte subito,
      //    il titolo geolocalizzato verrà aggiornato in background dal BLoC.
      final title = _generateTempTitle();

      // 3. Create unique file path
      final filePath = _buildFilePath(folderId, title, format);

      // 4. Validate configuration
      final configError = _validateConfig(format, sampleRate, bitRate);
      if (configError != null) {
        return Left(AudioRecordingFailure(
          message: configError,
          errorType: AudioRecordingErrorType.unsupportedAudioFormat,
          code: 'INVALID_CONFIG',
        ));
      }

      // 5. Start audio service
      final started = await _audioService.startRecording(
        filePath: filePath,
        format: format,
        sampleRate: sampleRate,
        bitRate: bitRate,
      );

      if (!started) {
        return Left(AudioRecordingFailure.startFailed());
      }

      return Right(StartRecordingSuccess(
        filePath: filePath,
        title: title,
        folderId: folderId,
        format: format,
        sampleRate: sampleRate,
        bitRate: bitRate,
        startTime: DateTime.now(),
      ));
    } catch (e, st) {
      debugPrint('❌ StartRecordingUseCase: $e\n$st');
      return Left(UnexpectedFailure(
        message: 'Unexpected error starting recording: $e',
        code: 'START_RECORDING_UNEXPECTED',
      ));
    }
  }

  // ==== PRIVATE HELPERS ====

  Future<bool> _ensureMicrophonePermission() async {
    try {
      if (await _audioService.hasMicrophonePermission()) return true;
      return await _audioService.requestMicrophonePermission();
    } catch (_) {
      return false;
    }
  }

  /// Titolo temporaneo basato sul timestamp — restituito sincronamente
  /// per non bloccare l'avvio della registrazione.
  String _generateTempTitle() {
    final now = DateTime.now();
    return 'Recording '
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _buildFilePath(String folderId, String title, AudioFormat format) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safe = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final name = safe.length > 50 ? safe.substring(0, 50) : safe;
    // fileExtension include già il dot (es. ".m4a") — non aggiungere un dot extra
    return '$folderId/${name}_$ts${format.fileExtension}';
  }

  String? _validateConfig(AudioFormat format, int sampleRate, int bitRate) {
    if (sampleRate < 8000 || sampleRate > 192000) {
      return 'Invalid sample rate: $sampleRate (must be 8000–192000 Hz)';
    }
    if (bitRate < 32000 || bitRate > 512000) {
      return 'Invalid bit rate: $bitRate (must be 32000–512000 bps)';
    }
    if (format == AudioFormat.m4a && sampleRate > 48000) {
      return 'M4A works best with sample rates ≤ 48000 Hz';
    }
    return null;
  }
}

/// Success data returned when recording starts successfully.
class StartRecordingSuccess {
  final String filePath;
  final String title;
  final String folderId;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final DateTime startTime;

  const StartRecordingSuccess({
    required this.filePath,
    required this.title,
    required this.folderId,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    required this.startTime,
  });
}

// Error type enum kept for mapping in recording_bloc.dart
enum StartRecordingErrorType {
  permissionDenied,
  audioServiceError,
  invalidConfiguration,
  fileSystemError,
  unknown,
}
