// File: services/audio/audio_service_factory.dart
import '../../domain/repositories/i_audio_service_repository.dart';
import '../../core/constants/app_constants.dart';
import 'audio_service_coordinator.dart';
import 'audio_recorder_service.dart';
import 'audio_player_service.dart';


/// Audio operation types for factory configuration
enum AudioOperation {
  recording,
  playback,
  both,
  testing,
}

/// Factory for creating audio service instances
///
/// Provides the appropriate audio service implementation based on
/// configuration and platform capabilities. Now supports the new
/// unified coordinator approach for optimal resource management.
class AudioServiceFactory {

  /// Create unified audio service instance (RECOMMENDED)
  ///
  /// Uses the new AudioServiceCoordinator which manages both
  /// recording and playback efficiently with proper resource handling.
  static IAudioServiceRepository createUnifiedService({
    bool useRealAudio = true, // Default to real audio
  }) {
    return AudioServiceCoordinator();
  }

  /// Create audio service instance (Legacy method)
  /// 
  /// Note: AudioRecorderService is already the real implementation.
  /// The useRealAudio parameter is kept for backward compatibility.
  static IAudioServiceRepository createAudioService({
    bool useRealAudio = false, // Kept for backward compatibility
  }) {
    return AudioRecorderService(); // Real audio service implementation
  }

  /// Create dedicated player service only
  static AudioPlayerService createPlayerService() {
    return AudioPlayerService();
  }

  /// Create service for recording screen (UPDATED)
  ///
  /// Now returns the unified coordinator for better functionality
  static IAudioServiceRepository createForRecording() {
    return createUnifiedService(useRealAudio: true);
  }

  /// Create service for playback only (UPDATED)
  ///
  /// Now returns the unified coordinator for consistent experience
  static IAudioServiceRepository createForPlayback() {
    return createUnifiedService(useRealAudio: true);
  }

  /// Create mock service for testing
  static IAudioServiceRepository createMockService() {
    return AudioRecorderService();
  }


  /// Create service based on app configuration
  static IAudioServiceRepository createFromConfig() {
    // Use app constants to determine service type
    final useRealAudio = AppConstants.enableRealAudioRecording;
    return createUnifiedService(useRealAudio: useRealAudio);
  }

  /// Create service for specific audio operations
  static IAudioServiceRepository createForOperation(AudioOperation operation) {
    switch (operation) {
      case AudioOperation.recording:
        return createForRecording();
      case AudioOperation.playback:
        return createForPlayback();
      case AudioOperation.both:
        return createUnifiedService(useRealAudio: true);
      case AudioOperation.testing:
        return createMockService();
    }
  }
}