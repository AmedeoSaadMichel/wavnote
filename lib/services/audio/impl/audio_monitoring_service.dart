// File: services/audio/impl/audio_monitoring_service.dart
import 'dart:async';
import 'dart:math' as math;
import '../../../core/constants/app_constants.dart';

/// Service for monitoring audio amplitude and duration during recording
///
/// Provides real-time updates for UI visualization and feedback.
/// Separated from core recording logic for better maintainability.
class AudioMonitoringService {

  // Stream controllers
  StreamController<double>? _amplitudeController;

  // Monitoring timers
  Timer? _amplitudeTimer;
  Timer? _durationTimer;

  // State
  bool _isMonitoring = false;

  // ==== INITIALIZATION ====

  void initialize() {
    _amplitudeController = StreamController<double>.broadcast();
  }

  void dispose() {
    stopMonitoring();
    _amplitudeController?.close();
  }

  // ==== MONITORING CONTROL ====

  void startAmplitudeMonitoring() {
    if (_isMonitoring) return;

    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(
      Duration(milliseconds: AppConstants.amplitudeUpdateInterval.inMilliseconds),
          (timer) {
        if (_isMonitoring) {
          // Generate realistic amplitude simulation
          final amplitude = _generateRealisticAmplitude();
          _amplitudeController?.add(amplitude);
        }
      },
    );

    _isMonitoring = true;
  }

  void stopAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeController?.add(0.0);
    _isMonitoring = false;
  }

  void startDurationMonitoring(Function() onUpdate) {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      onUpdate();
    });
  }

  void stopDurationMonitoring() {
    _durationTimer?.cancel();
  }

  void stopMonitoring() {
    stopAmplitudeMonitoring();
    stopDurationMonitoring();
  }

  // ==== STREAMS ====

  Stream<double> get amplitudeStream =>
      _amplitudeController?.stream ?? const Stream.empty();

  // ==== STATE ====

  bool get isMonitoring => _isMonitoring;

  // ==== PRIVATE HELPERS ====

  /// Generate realistic amplitude values for visualization
  double _generateRealisticAmplitude() {
    final now = DateTime.now();
    final timeMs = now.millisecondsSinceEpoch;

    // Base wave with some randomness
    final baseAmplitude = 0.3 + (math.sin(timeMs / 200.0) * 0.2);

    // Add some noise for realism
    final noise = (math.Random().nextDouble() - 0.5) * 0.3;

    // Occasional spikes for speech-like pattern
    final spike = math.Random().nextDouble() < 0.1 ? 0.3 : 0.0;

    final amplitude = baseAmplitude + noise + spike;

    return amplitude.clamp(0.0, 1.0);
  }

  /// Pause amplitude monitoring (for paused recording)
  void pauseAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeController?.add(0.0);
  }

  /// Resume amplitude monitoring
  void resumeAmplitudeMonitoring() {
    if (_isMonitoring) {
      startAmplitudeMonitoring();
    }
  }
}