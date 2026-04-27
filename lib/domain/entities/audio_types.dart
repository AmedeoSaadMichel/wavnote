// File: lib/domain/entities/audio_types.dart

import '../../core/enums/audio_format.dart';

/// Informazioni su un file audio
class AudioFileInfo {
  final String filePath;
  final AudioFormat format;
  final Duration duration;
  final int fileSize;
  final int sampleRate;
  final int bitRate;
  final int channels;
  final DateTime createdAt;

  const AudioFileInfo({
    required this.filePath,
    required this.format,
    required this.duration,
    required this.fileSize,
    required this.sampleRate,
    required this.bitRate,
    required this.channels,
    required this.createdAt,
  });

  /// Dimensione file in formato leggibile
  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Durata in formato leggibile
  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Descrizione qualità audio
  String get qualityDescription {
    if (sampleRate >= 48000) return 'High Quality';
    if (sampleRate >= 44100) return 'CD Quality';
    if (sampleRate >= 22050) return 'Good Quality';
    return 'Basic Quality';
  }
}

/// Informazioni su un dispositivo di input audio
class AudioInputDevice {
  final String id;
  final String name;
  final bool isDefault;
  final bool isAvailable;

  const AudioInputDevice({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.isAvailable,
  });
}

/// Categorie di sessione audio (iOS)
enum AudioSessionCategory {
  ambient,
  soloAmbient,
  playback,
  record,
  playAndRecord,
  multiRoute,
}
