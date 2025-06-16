// File: services/audio/audio_service_factory.dart
import '../../domain/repositories/i_audio_service_repository.dart';
import '../../core/constants/app_constants.dart';
import 'audio_recorder_service.dart';
import 'real_audio_recorder_service.dart';

/// Factory for creating audio service instances
///
/// Provides the appropriate audio service implementation based on
/// configuration and platform capabilities.
class AudioServiceFactory {

  /// Create audio service instance
  static IAudioServiceRepository createAudioService({
    bool useRealAudio = false, // Default to mock for stability
  }) {
    // For development/testing, you can toggle between real and mock
    if (useRealAudio && _canUseRealAudio()) {
      return RealAudioRecorderService();
    } else {
      return AudioRecorderService(); // Mock service
    }
  }

  /// Check if real audio recording is available
  static bool _canUseRealAudio() {
    try {
      // For now, return false to use mock service
      // TODO: Add platform checks here
      return false; // Disabled until fully implemented
    } catch (e) {
      return false;
    }
  }

  /// Create service for recording screen
  static IAudioServiceRepository createForRecording() {
    return createAudioService(useRealAudio: false); // Use mock for now
  }

  /// Create service for playback only
  static IAudioServiceRepository createForPlayback() {
    return createAudioService(useRealAudio: false); // Use mock for now
  }

  /// Create mock service for testing
  static IAudioServiceRepository createMockService() {
    return AudioRecorderService();
  }
}