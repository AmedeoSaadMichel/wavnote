// File: presentation/widgets/recording/custom_waveform/waveform_utils.dart

/// Extensions copied from audio_waveforms package for custom implementation.

extension WaveformDurationExtension on Duration {
  /// Converts duration to HH:MM:SS format
  String toHHMMSS() => toString().split('.').first.padLeft(8, "0");
}

extension WaveformIntExtension on int {
  /// Converts total seconds to MM:SS format
  String toMMSS() =>
      '${(this ~/ 60).toString().padLeft(2, '0')}:${(this % 60).toString().padLeft(2, '0')}';
}
