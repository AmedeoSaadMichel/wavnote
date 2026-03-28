// File: presentation/widgets/recording/custom_waveform/label.dart
import 'package:flutter/material.dart';

/// Duration labels for AudioWaveform widget.
///
/// Copied from audio_waveforms package for custom implementation.
class WaveformLabel {
  /// Fixed label content for a single instance.
  final String content;

  /// An offset for labels which get new position everytime waveforms are
  /// scrolled.
  Offset offset;

  WaveformLabel({
    required this.content,
    required this.offset,
  });
}
