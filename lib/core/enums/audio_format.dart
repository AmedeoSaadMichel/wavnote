import 'package:flutter/material.dart';

enum AudioFormat {
  wav,
  m4a,
  flac,
}

extension AudioFormatExtension on AudioFormat {
  String get name {
    switch (this) {
      case AudioFormat.wav:
        return 'WAV';
      case AudioFormat.m4a:
        return 'M4A';
      case AudioFormat.flac:
        return 'FLAC';
    }
  }

  String get description {
    switch (this) {
      case AudioFormat.wav:
        return 'Uncompressed, highest quality, large files';
      case AudioFormat.m4a:
        return 'Apple format, good quality, smaller files';
      case AudioFormat.flac:
        return 'Lossless compression, good quality';
    }
  }

  IconData get icon {
    switch (this) {
      case AudioFormat.wav:
        return Icons.graphic_eq;
      case AudioFormat.m4a:
        return Icons.apple;
      case AudioFormat.flac:
        return Icons.music_note;
    }
  }

  Color get color {
    switch (this) {
      case AudioFormat.wav:
        return Colors.pink;
      case AudioFormat.m4a:
        return Colors.green;
      case AudioFormat.flac:
        return Colors.teal;
    }
  }

  String get fileExtension {
    switch (this) {
      case AudioFormat.wav:
        return '.wav';
      case AudioFormat.m4a:
        return '.m4a';
      case AudioFormat.flac:
        return '.flac';
    }
  }

  // Sample rates supported by each format
  List<int> get supportedSampleRates {
    switch (this) {
      case AudioFormat.wav:
        return [8000, 16000, 22050, 44100, 48000, 96000];
      case AudioFormat.m4a:
        return [8000, 16000, 22050, 44100, 48000];
      case AudioFormat.flac:
        return [8000, 16000, 22050, 44100, 48000, 96000, 192000];
    }
  }

  // Default sample rate for each format
  int get defaultSampleRate {
    switch (this) {
      case AudioFormat.wav:
        return 44100;
      case AudioFormat.m4a:
        return 44100;
      case AudioFormat.flac:
        return 48000;
    }
  }

  // Quality rating (1-5, 5 being highest)
  int get qualityRating {
    switch (this) {
      case AudioFormat.wav:
        return 5; // Uncompressed, highest quality
      case AudioFormat.m4a:
        return 4; // Good compressed quality
      case AudioFormat.flac:
        return 5; // Lossless, highest quality
    }
  }

  // File size rating (1-5, 1 being smallest)
  int get fileSizeRating {
    switch (this) {
      case AudioFormat.wav:
        return 5; // Largest files
      case AudioFormat.m4a:
        return 2; // Smallest files
      case AudioFormat.flac:
        return 3; // Medium-large files
    }
  }
}

class AudioFormatOption {
  final AudioFormat format;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  AudioFormatOption({
    required this.format,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  // Factory constructor from enum
  factory AudioFormatOption.fromFormat(AudioFormat format) {
    return AudioFormatOption(
      format: format,
      name: format.name,
      description: format.description,
      icon: format.icon,
      color: format.color,
    );
  }

  // Get all available format options
  static List<AudioFormatOption> getAllOptions() {
    return AudioFormat.values
        .map((format) => AudioFormatOption.fromFormat(format))
        .toList();
  }
}