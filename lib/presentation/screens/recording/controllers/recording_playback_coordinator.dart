// File: lib/presentation/screens/recording/controllers/recording_playback_coordinator.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/services/audio/audio_playback_state.dart';
import 'package:wavnote/services/audio/i_audio_playback_engine.dart';
import 'package:wavnote/services/audio/i_audio_preparation_service.dart';

import 'recording_playback_view_state.dart';

class RecordingPlaybackCoordinator {
  final IAudioPlaybackEngine _engine;
  final IAudioPreparationService _preparationService;

  final ValueNotifier<RecordingPlaybackViewState> state;

  RecordingEntity? _expandedRecording;
  RecordingEntity? _activeRecording;
  bool _isInitialized = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<AudioPlaybackState>? _playbackStateSub;
  StreamSubscription<void>? _completionSub;

  RecordingPlaybackCoordinator({
    required IAudioPlaybackEngine engine,
    required IAudioPreparationService preparationService,
  }) : _engine = engine,
       _preparationService = preparationService,
       state = ValueNotifier<RecordingPlaybackViewState>(
         const RecordingPlaybackViewState(
           expandedRecordingId: null,
           activeRecordingId: null,
           status: RecordingPlaybackStatus.idle,
           position: Duration.zero,
           duration: Duration.zero,
           isBuffering: false,
           errorMessage: null,
         ),
       );

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _engine.initialize();
    _listenToEngineStreams();
    _isInitialized = true;
  }

  void _listenToEngineStreams() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playbackStateSub?.cancel();
    _completionSub?.cancel();

    _positionSub = _engine.positionStream.listen((position) {
      state.value = state.value.copyWith(position: position);
    });

    _durationSub = _engine.durationStream.listen((duration) {
      if (duration != null) {
        state.value = state.value.copyWith(duration: duration);
      }
    });

    _playbackStateSub = _engine.playbackStateStream.listen((engineState) {
      RecordingPlaybackStatus newStatus;
      bool isBuffering = false;

      switch (engineState) {
        case AudioPlaybackState.idle:
          newStatus = RecordingPlaybackStatus.idle;
          break;
        case AudioPlaybackState.loaded:
          newStatus = RecordingPlaybackStatus.ready;
          break;
        case AudioPlaybackState.playing:
          newStatus = RecordingPlaybackStatus.playing;
          break;
        case AudioPlaybackState.paused:
          newStatus = RecordingPlaybackStatus.paused;
          break;
        case AudioPlaybackState.completed:
          newStatus = RecordingPlaybackStatus.ready;
          break;
        case AudioPlaybackState.buffering:
          newStatus = RecordingPlaybackStatus.preparing;
          isBuffering = true;
          break;
        case AudioPlaybackState.error:
          newStatus = RecordingPlaybackStatus.error;
          break;
      }
      state.value = state.value.copyWith(
        status: newStatus,
        isBuffering: isBuffering,
        activeRecordingId: _activeRecording?.id,
      );
    });

    _completionSub = _engine.completionStream.listen((_) {
      state.value = state.value.copyWith(
        status: RecordingPlaybackStatus.ready,
        position: Duration.zero,
      );
    });
  }

  Future<void> expandRecording(RecordingEntity recording) async {
    if (state.value.expandedRecordingId == recording.id) {
      await collapseRecording();
      return;
    }

    if (_activeRecording != null) {
      await _engine.stop();
      // Risolvi il path prima di pulire la cache
      await _preparationService.clearPrepared(
        await _activeRecording!.resolvedFilePath,
      );
      _activeRecording = null;
    }

    _expandedRecording = recording;
    state.value = state.value.copyWith(
      expandedRecordingId: recording.id,
      activeRecordingId: null,
      status: RecordingPlaybackStatus.preparing,
      errorMessage: null,
      isBuffering: false,
    );

    final result = await _preparationService.prepare(recording);

    if (result.isSuccess) {
      _activeRecording = recording;
      state.value = state.value.copyWith(
        status: RecordingPlaybackStatus.ready,
        duration: result.duration,
        activeRecordingId: recording.id,
      );
    } else {
      state.value = state.value.copyWith(
        status: RecordingPlaybackStatus.error,
        errorMessage: result.errorMessage,
        activeRecordingId: null,
      );
    }
  }

  Future<void> collapseRecording() async {
    if (_activeRecording != null) {
      await _engine.stop();
      await _preparationService.clearPrepared(
        await _activeRecording!.resolvedFilePath,
      );
      _activeRecording = null;
    }
    _expandedRecording = null;
    state.value = const RecordingPlaybackViewState(
      expandedRecordingId: null,
      activeRecordingId: null,
      status: RecordingPlaybackStatus.idle,
      position: Duration.zero,
      duration: Duration.zero,
      isBuffering: false,
      errorMessage: null,
    );
  }

  Future<void> togglePlayback() async {
    if (_activeRecording == null) return;

    // ... logica toggle invariata ...
    switch (state.value.status) {
      case RecordingPlaybackStatus.ready:
        await _engine.play();
        break;
      case RecordingPlaybackStatus.playing:
        await _engine.pause();
        break;
      case RecordingPlaybackStatus.paused:
        await _engine.play();
        break;
      case RecordingPlaybackStatus.completed:
        await _engine.seek(Duration.zero);
        await _engine.play();
        break;
      default:
        break;
    }
  }

  // ... (seekToPercent, skipForward, skipBackward invariati) ...
  Future<void> seekToPercent(double percent) async {
    if (_activeRecording == null || state.value.duration == Duration.zero)
      return;
    final newPosition = Duration(
      milliseconds: (state.value.duration.inMilliseconds * percent).round(),
    );
    final clampedPosition = newPosition < Duration.zero
        ? Duration.zero
        : (newPosition > state.value.duration
              ? state.value.duration
              : newPosition);
    await _engine.seek(clampedPosition);
  }

  Future<void> skipForward() async {
    if (_activeRecording == null || state.value.duration == Duration.zero)
      return;
    final newPosition = state.value.position + const Duration(seconds: 10);
    final clampedPosition = newPosition > state.value.duration
        ? state.value.duration
        : newPosition;
    await _engine.seek(clampedPosition);
  }

  Future<void> skipBackward() async {
    if (_activeRecording == null) return;
    final newPosition = state.value.position - const Duration(seconds: 10);
    final clampedPosition = newPosition < Duration.zero
        ? Duration.zero
        : newPosition;
    await _engine.seek(clampedPosition);
  }

  Future<void> dispose() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _playbackStateSub?.cancel();
    await _completionSub?.cancel();
    _isInitialized = false;
    state.dispose();
  }
}
