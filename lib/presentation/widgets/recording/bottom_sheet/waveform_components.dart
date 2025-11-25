// File: presentation/widgets/recording/bottom_sheet/waveform_components.dart
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

/// Compact audio waveform for the collapsed view
class CompactAudioWaveform extends StatelessWidget {
  final RecorderController recorderController;

  const CompactAudioWaveform({
    super.key,
    required this.recorderController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      alignment: Alignment.center,
      child: AudioWaveforms(
        enableGesture: false,
        size: Size(MediaQuery.of(context).size.width - 64, 100), // Full width minus margins
        recorderController: recorderController,
        waveStyle: WaveStyle(
          waveColor: Colors.cyan,
          showDurationLabel: false,
          spacing: 4.0,
          showBottom: true,
          extendWaveform: true,   // Re-enable for smooth visualization
          showMiddleLine: false,  // Remove vertical center line
          scaleFactor: 80,        // Reduced to prevent clipping
          waveThickness: 3.5,
          gradient: LinearGradient(
            colors: [
              Colors.cyan.withValues(alpha: 0.7),
              Colors.cyan.withValues(alpha: 1.0),
              Colors.blue.withValues(alpha: 1.0),
              Colors.cyan.withValues(alpha: 0.7),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width - 64, 100)),
        ),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }
}

/// Fullscreen audio waveform for the expanded view
class FullscreenAudioWaveform extends StatelessWidget {
  final RecorderController recorderController;
  final bool isRecording;

  const FullscreenAudioWaveform({
    super.key,
    required this.recorderController,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    return AudioWaveforms(
      enableGesture: false,
      size: Size(MediaQuery.of(context).size.width - 40, 200),
      recorderController: recorderController,
      waveStyle: WaveStyle(
        waveColor: Colors.cyan,
        showDurationLabel: false,
        spacing: 3.0,
        showBottom: true,
        extendWaveform: true,
        showMiddleLine: false,
        scaleFactor: 100,
        waveThickness: 2.5,
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
    );
  }
}

