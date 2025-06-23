// File: core/utils/waveform_generator.dart
import 'dart:math';
import '../../domain/entities/recording_entity.dart';

/// Utility class for generating waveform data for audio recordings
///
/// Provides consistent waveform generation based on recording properties
/// to create visually appealing and realistic waveform patterns.
class WaveformGenerator {

  /// Generate realistic waveform data for a recording
  ///
  /// Uses the recording's ID as a seed to ensure consistent waveform
  /// patterns for the same recording across app sessions.
  ///
  /// Returns a list of amplitude values between 0.0 and 1.0
  static List<double> generateForRecording(
      RecordingEntity recording, {
        int sampleCount = 50,
      }) {
    // Use recording ID as seed for consistent waveform per recording
    final seed = recording.id.hashCode;
    final random = Random(seed);
    final List<double> amplitudes = [];

    // Generate samples for display
    for (int i = 0; i < sampleCount; i++) {
      final double position = i / sampleCount.toDouble();

      // Create fade in/out effect based on recording duration
      double fadeFactor = 1.0;
      if (position < 0.1) {
        fadeFactor = position / 0.1;
      } else if (position > 0.9) {
        fadeFactor = (1.0 - position) / 0.1;
      }

      // Generate varied amplitudes based on recording characteristics
      double amplitude;
      if (i % 7 == 0) {
        // Occasional peaks - higher for longer recordings
        amplitude = (0.6 + random.nextDouble() * 0.4) * fadeFactor;
      } else if (i % 3 == 0) {
        // Medium amplitude
        amplitude = (0.3 + random.nextDouble() * 0.4) * fadeFactor;
      } else {
        // Lower amplitude
        amplitude = (0.1 + random.nextDouble() * 0.3) * fadeFactor;
      }

      amplitudes.add(amplitude.clamp(0.0, 1.0));
    }

    return amplitudes;
  }

  /// Generate waveform with custom pattern based on recording name
  ///
  /// Creates different waveform characteristics based on recording content
  static List<double> generateWithPattern(
      RecordingEntity recording, {
        int sampleCount = 50,
        WaveformPattern pattern = WaveformPattern.auto,
      }) {
    final seed = recording.id.hashCode;
    final random = Random(seed);

    // Auto-detect pattern based on recording properties
    WaveformPattern actualPattern = pattern;
    if (pattern == WaveformPattern.auto) {
      actualPattern = _detectPatternFromRecording(recording);
    }

    return _generateWithSpecificPattern(random, sampleCount, actualPattern);
  }

  /// Detect appropriate waveform pattern from recording properties
  static WaveformPattern _detectPatternFromRecording(RecordingEntity recording) {
    final name = recording.name.toLowerCase();
    final duration = recording.duration;

    // Short recordings tend to be more intense
    if (duration.inSeconds < 30) {
      return WaveformPattern.intense;
    }

    // Long recordings tend to be more conversational
    if (duration.inMinutes > 10) {
      return WaveformPattern.conversational;
    }

    // Check name for clues
    if (name.contains('music') || name.contains('song')) {
      return WaveformPattern.musical;
    }

    if (name.contains('quiet') || name.contains('whisper')) {
      return WaveformPattern.quiet;
    }

    if (name.contains('loud') || name.contains('shout')) {
      return WaveformPattern.intense;
    }

    // Default to balanced
    return WaveformPattern.balanced;
  }

  /// Generate waveform with specific pattern
  static List<double> _generateWithSpecificPattern(
      Random random,
      int sampleCount,
      WaveformPattern pattern,
      ) {
    final List<double> amplitudes = [];

    for (int i = 0; i < sampleCount; i++) {
      final double position = i / sampleCount.toDouble();
      double amplitude;

      switch (pattern) {
        case WaveformPattern.quiet:
          amplitude = _generateQuietPattern(random, position, i);
          break;
        case WaveformPattern.intense:
          amplitude = _generateIntensePattern(random, position, i);
          break;
        case WaveformPattern.musical:
          amplitude = _generateMusicalPattern(random, position, i);
          break;
        case WaveformPattern.conversational:
          amplitude = _generateConversationalPattern(random, position, i);
          break;
        case WaveformPattern.balanced:
        case WaveformPattern.auto:
        default:
          amplitude = _generateBalancedPattern(random, position, i);
          break;
      }

      amplitudes.add(amplitude.clamp(0.0, 1.0));
    }

    return amplitudes;
  }

  /// Generate quiet waveform pattern
  static double _generateQuietPattern(Random random, double position, int i) {
    final fadeFactor = _calculateFadeFactor(position);
    return (0.05 + random.nextDouble() * 0.25) * fadeFactor;
  }

  /// Generate intense waveform pattern
  static double _generateIntensePattern(Random random, double position, int i) {
    final fadeFactor = _calculateFadeFactor(position);
    if (i % 3 == 0) {
      return (0.7 + random.nextDouble() * 0.3) * fadeFactor;
    } else {
      return (0.4 + random.nextDouble() * 0.4) * fadeFactor;
    }
  }

  /// Generate musical waveform pattern
  static double _generateMusicalPattern(Random random, double position, int i) {
    final fadeFactor = _calculateFadeFactor(position);
    // Create wave-like pattern
    final wave = sin(position * 4 * pi) * 0.3 + 0.5;
    final noise = random.nextDouble() * 0.3;
    return (wave + noise) * fadeFactor;
  }

  /// Generate conversational waveform pattern
  static double _generateConversationalPattern(Random random, double position, int i) {
    final fadeFactor = _calculateFadeFactor(position);
    // Create pauses and bursts like speech
    if (i % 12 < 3) {
      // Pause
      return (0.05 + random.nextDouble() * 0.1) * fadeFactor;
    } else {
      // Speech burst
      return (0.3 + random.nextDouble() * 0.4) * fadeFactor;
    }
  }

  /// Generate balanced waveform pattern
  static double _generateBalancedPattern(Random random, double position, int i) {
    final fadeFactor = _calculateFadeFactor(position);

    if (i % 7 == 0) {
      // Occasional peaks
      return (0.6 + random.nextDouble() * 0.4) * fadeFactor;
    } else if (i % 3 == 0) {
      // Medium amplitude
      return (0.3 + random.nextDouble() * 0.4) * fadeFactor;
    } else {
      // Lower amplitude
      return (0.1 + random.nextDouble() * 0.3) * fadeFactor;
    }
  }

  /// Calculate fade factor for smooth edges
  static double _calculateFadeFactor(double position) {
    if (position < 0.1) {
      return position / 0.1;
    } else if (position > 0.9) {
      return (1.0 - position) / 0.1;
    }
    return 1.0;
  }

  /// Generate waveform for current playback position
  ///
  /// Useful for real-time waveform visualization during recording
  static List<double> generateRealtime({
    required Duration elapsed,
    required Duration totalDuration,
    int sampleCount = 50,
    double intensity = 0.5,
  }) {
    final random = Random(elapsed.inMilliseconds);
    final List<double> amplitudes = [];

    final progress = totalDuration.inMilliseconds > 0
        ? elapsed.inMilliseconds / totalDuration.inMilliseconds
        : 0.0;

    for (int i = 0; i < sampleCount; i++) {
      final position = i / sampleCount.toDouble();

      if (position <= progress) {
        // Past content - show actual amplitude
        final amplitude = (random.nextDouble() * intensity).clamp(0.0, 1.0);
        amplitudes.add(amplitude);
      } else {
        // Future content - show placeholder
        amplitudes.add(0.1);
      }
    }

    return amplitudes;
  }
}

/// Enum for different waveform patterns
enum WaveformPattern {
  auto,           // Auto-detect based on recording
  quiet,          // Low amplitude throughout
  intense,        // High amplitude with frequent peaks
  musical,        // Wave-like pattern for music
  conversational, // Speech-like with pauses and bursts
  balanced,       // Mixed amplitudes (default)
}