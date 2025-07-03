// File: services/audio/audio_state_manager.dart
import 'package:flutter/foundation.dart';

/// Isolated audio state management using ValueNotifier for high-frequency updates
/// This prevents cascade rebuilds when audio position changes
class AudioStateManager extends ChangeNotifier {
  // High-frequency updates (position, amplitude) - Use ValueNotifier
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<double> _amplitudeNotifier = ValueNotifier(0.0);
  
  // Medium-frequency updates (playback state) - Use ValueNotifier
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isBufferingNotifier = ValueNotifier(false);
  
  // Low-frequency updates (current file, errors) - Use ChangeNotifier
  String? _currentRecordingId;
  String? _errorMessage;
  
  // Getters for high-frequency state (UI components listen directly)
  ValueListenable<Duration> get positionNotifier => _positionNotifier;
  ValueListenable<Duration> get durationNotifier => _durationNotifier;
  ValueListenable<double> get amplitudeNotifier => _amplitudeNotifier;
  ValueListenable<bool> get isPlayingNotifier => _isPlayingNotifier;
  ValueListenable<bool> get isBufferingNotifier => _isBufferingNotifier;
  
  // Getters for low-frequency state (accessed via ChangeNotifier)
  String? get currentRecordingId => _currentRecordingId;
  String? get errorMessage => _errorMessage;
  Duration get position => _positionNotifier.value;
  Duration get duration => _durationNotifier.value;
  bool get isPlaying => _isPlayingNotifier.value;
  bool get isBuffering => _isBufferingNotifier.value;
  double get amplitude => _amplitudeNotifier.value;
  
  // Computed properties
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / duration.inMilliseconds;
  }
  
  bool get hasCurrentRecording => _currentRecordingId != null;
  
  /// Update audio position (high-frequency - ~10fps)
  void updatePosition(Duration newPosition) {
    if (_positionNotifier.value != newPosition) {
      _positionNotifier.value = newPosition;
    }
  }
  
  /// Update audio duration (low-frequency)
  void updateDuration(Duration newDuration) {
    if (_durationNotifier.value != newDuration) {
      _durationNotifier.value = newDuration;
    }
  }
  
  /// Update amplitude for waveform visualization (high-frequency)
  void updateAmplitude(double newAmplitude) {
    if (_amplitudeNotifier.value != newAmplitude) {
      _amplitudeNotifier.value = newAmplitude;
    }
  }
  
  /// Update playback state (medium-frequency)
  void updatePlaybackState({
    bool? isPlaying,
    bool? isBuffering,
  }) {
    if (isPlaying != null && _isPlayingNotifier.value != isPlaying) {
      _isPlayingNotifier.value = isPlaying;
    }
    if (isBuffering != null && _isBufferingNotifier.value != isBuffering) {
      _isBufferingNotifier.value = isBuffering;
    }
  }
  
  /// Update current recording (low-frequency - triggers ChangeNotifier)
  void updateCurrentRecording(String? recordingId) {
    if (_currentRecordingId != recordingId) {
      _currentRecordingId = recordingId;
      notifyListeners(); // Only notify for significant state changes
    }
  }
  
  /// Update error state (low-frequency - triggers ChangeNotifier)
  void updateError(String? error) {
    if (_errorMessage != error) {
      _errorMessage = error;
      notifyListeners();
    }
  }
  
  /// Reset all audio state
  void reset() {
    _positionNotifier.value = Duration.zero;
    _durationNotifier.value = Duration.zero;
    _amplitudeNotifier.value = 0.0;
    _isPlayingNotifier.value = false;
    _isBufferingNotifier.value = false;
    _currentRecordingId = null;
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Seek to specific position
  void seekTo(Duration position) {
    if (position >= Duration.zero && position <= duration) {
      updatePosition(position);
    }
  }
  
  @override
  void dispose() {
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _amplitudeNotifier.dispose();
    _isPlayingNotifier.dispose();
    _isBufferingNotifier.dispose();
    super.dispose();
  }
  
  @override
  String toString() {
    return 'AudioStateManager{currentRecording: $_currentRecordingId, '
           'position: ${position.inSeconds}s, duration: ${duration.inSeconds}s, '
           'isPlaying: $isPlaying, isBuffering: $isBuffering}';
  }
}