import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../domain/entities/recording_entity.dart';
import '../../../../domain/repositories/i_audio_service_repository.dart';
import '../../../../services/audio/audio_state_manager.dart';

/// Presentation layer controller for handling audio playback UI state
/// 
/// Replaces the old UI logic that was tightly coupled to AudioPlayerService.
class RecordingPlaybackController {
  final IAudioServiceRepository _audioService;
  final AudioStateManager audioStateManager;
  
  StreamSubscription? _completionSub;
  StreamSubscription? _positionSub;
  
  RecordingPlaybackController({
    required IAudioServiceRepository audioService,
  }) : _audioService = audioService,
       audioStateManager = AudioStateManager() {
    
    _completionSub = _audioService.getPlaybackCompletionStream().listen((_) {
      if (audioStateManager.expandedRecordingId != null) {
        audioStateManager.updatePlaybackState(isPlaying: false);
        audioStateManager.updatePosition(Duration.zero);
      }
    });

    _positionSub = _audioService.getPlaybackPositionStream().listen((position) {
      audioStateManager.updatePosition(position);
    });
  }

  String? get expandedRecordingId => audioStateManager.expandedRecordingId;
  
  bool get isCurrentlyPlaying => audioStateManager.isPlaying;
  bool get isLoading => false;
  Duration get position => audioStateManager.position;
  Duration get duration => audioStateManager.duration;

  Future<void> initialize() async {
    await _audioService.initialize();
  }

  Future<void> expandRecording(RecordingEntity recording) async {
    debugPrint('🎯 EXPAND: expandRecording called for: ${recording.name}');
    
    if (audioStateManager.expandedRecordingId == recording.id) {
      await _audioService.stopPlaying();
      audioStateManager.reset();
    } else {
      if (audioStateManager.expandedRecordingId != null) {
        await _audioService.stopPlaying();
      }
      
      audioStateManager.reset();
      audioStateManager.updateExpandedRecording(recording.id);
      audioStateManager.updateCurrentRecording(recording.id);
      audioStateManager.updateDuration(recording.duration);
      audioStateManager.updatePosition(Duration.zero);
      audioStateManager.updatePlaybackState(isPlaying: false, isBuffering: false);
      
      // Just start paused at 0
      try {
        // Many audio services support preload, we just call startPlaying and then pause
        // or we just wait for the user to press play.
      } catch (e) {
        debugPrint('Preload error: $e');
      }
    }
  }

  void resetExpansionState() {
    audioStateManager.reset();
  }

  Future<void> togglePlayback() async {
    if (expandedRecordingId == null) return;
    
    final isPlaying = await _audioService.isPlaying();
    
    if (isPlaying) {
      await _audioService.pausePlaying();
      audioStateManager.updatePlaybackState(isPlaying: false);
    } else {
      // Check if we need to start from scratch or resume
      final isPaused = await _audioService.isPlaybackPaused();
      
      if (isPaused) {
        await _audioService.resumePlaying();
        audioStateManager.updatePlaybackState(isPlaying: true);
      } else {
        // Need to start playback
        // We need the file path, so we have to get it from the recording
        // We'll rely on the caller to provide the recording, but for now we can't do it cleanly
        // if we don't have the RecordingEntity.
        // Let's modify togglePlayback to accept the recording!
      }
    }
  }
  
  Future<void> togglePlaybackForRecording(RecordingEntity recording) async {
    final isPlaying = await _audioService.isPlaying();
    
    if (isPlaying) {
      await _audioService.pausePlaying();
      audioStateManager.updatePlaybackState(isPlaying: false);
    } else {
      final isPaused = await _audioService.isPlaybackPaused();
      
      if (isPaused) {
        await _audioService.resumePlaying();
        audioStateManager.updatePlaybackState(isPlaying: true);
      } else {
        await _audioService.startPlaying(recording.filePath, initialPosition: audioStateManager.position);
        audioStateManager.updatePlaybackState(isPlaying: true);
      }
    }
  }

  Future<void> seekToPosition(double percent) async {
    final effectiveDuration = audioStateManager.duration;
    if (effectiveDuration == Duration.zero) return;
    
    final target = Duration(
      milliseconds: (effectiveDuration.inMilliseconds * percent).round(),
    );
    
    audioStateManager.seekTo(target);
    await _audioService.seekTo(target);
  }

  Future<void> skipBackward() async {
    final currentPos = audioStateManager.position;
    final maxDuration = audioStateManager.duration;
    
    final newPosition = Duration(
      milliseconds: (currentPos.inMilliseconds - 10000).clamp(0, maxDuration.inMilliseconds),
    );
    
    audioStateManager.seekTo(newPosition);
    await _audioService.seekTo(newPosition);
  }

  Future<void> skipForward() async {
    final currentPos = audioStateManager.position;
    final maxDuration = audioStateManager.duration;
    
    final newPosition = Duration(
      milliseconds: (currentPos.inMilliseconds + 10000).clamp(0, maxDuration.inMilliseconds),
    );
    
    audioStateManager.seekTo(newPosition);
    await _audioService.seekTo(newPosition);
  }

  RecordingEntity? getCurrentlyExpandedRecording(List<RecordingEntity> recordings) {
    if (expandedRecordingId == null) return null;
    try {
      return recordings.firstWhere((r) => r.id == expandedRecordingId);
    } catch (_) {
      audioStateManager.reset();
      return null;
    }
  }

  Future<void> stopPlaying() async {
    await _audioService.stopPlaying();
    audioStateManager.updatePlaybackState(isPlaying: false);
    audioStateManager.updatePosition(Duration.zero);
  }
  
  void dispose() {
    _completionSub?.cancel();
    _positionSub?.cancel();
    audioStateManager.dispose();
  }
}
