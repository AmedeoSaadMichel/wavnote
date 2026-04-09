// File: presentation/mappers/audio_format_ui_mapper.dart
//
// Audio Format UI Mapper - Presentation Layer
// ===========================================
//
// Maps AudioFormat enum (wav, m4a, flac) to Flutter UI types.
// Keeps the core layer free of Flutter dependencies, conversione avviene qui.

import 'package:flutter/material.dart';
import '../../core/enums/audio_format.dart';

/// Mapper for converting AudioFormat to Flutter UI types
class AudioFormatUiMapper {
  static IconData getIcon(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return Icons.graphic_eq;
      case AudioFormat.m4a:
        return Icons.apple;
      case AudioFormat.flac:
        return Icons.music_note;
    }
  }

  static Color getColor(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return Colors.pink;
      case AudioFormat.m4a:
        return Colors.green;
      case AudioFormat.flac:
        return Colors.teal;
    }
  }
}
