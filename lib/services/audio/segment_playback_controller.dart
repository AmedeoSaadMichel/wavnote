import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/entities/recording_session_segment.dart';

@immutable
class SegmentPlaybackState {
  final bool isPlaying;
  final Duration position;
  const SegmentPlaybackState({
    this.isPlaying = false,
    this.position = Duration.zero,
  });
}

/// Independent players mixed by the OS; leaves the recorder audio session intact.
class SegmentPlaybackController {
  static const _channel = MethodChannel('com.wavnote/audio_engine');
  final bool useNative;
  final state = ValueNotifier<Map<String, SegmentPlaybackState>>(const {});
  final Map<String, AudioPlayer> _players = {};
  final Map<String, Future<void>> _operations = {};
  Timer? _timer;
  bool _polling = false;
  bool _disposed = false;
  int _generation = 0;

  SegmentPlaybackController({bool? useNative})
    : useNative = useNative ?? (Platform.isIOS || Platform.isMacOS);

  bool get hasPlayers => state.value.isNotEmpty || _operations.isNotEmpty;

  Future<void> toggle(RecordingSessionSegment segment) {
    final id = segment.recording.id;
    final generation = _generation;
    final task = (_operations[id] ?? Future.value()).then((_) async {
      if (_disposed || generation != _generation) return;
      if (state.value[id]?.isPlaying ?? false) {
        await _stop(id);
        return;
      }
      final path = await segment.recording.resolvedFilePath;
      if (_disposed || generation != _generation) return;
      if (useNative) {
        await _channel.invokeMethod<void>('playSegment', {
          'id': id,
          'path': path,
        });
      } else {
        final player = AudioPlayer(handleAudioSessionActivation: false);
        _players[id] = player;
        try {
          await player.setFilePath(path);
          if (_disposed || generation != _generation) {
            await _players.remove(id)?.dispose();
            return;
          }
          unawaited(
            player.play().catchError((Object _) {
              unawaited(_stop(id));
            }),
          );
        } catch (_) {
          await _players.remove(id)?.dispose();
          rethrow;
        }
      }
      if (_disposed || generation != _generation) {
        await _stop(id);
        return;
      }
      state.value = {
        ...state.value,
        id: const SegmentPlaybackState(isPlaying: true),
      };
      _timer ??= Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => unawaited(_poll()),
      );
    });
    _operations[id] = task.catchError((Object _) {});
    return task;
  }

  Future<void> _stop(String id) async {
    if (useNative) {
      await _channel.invokeMethod<void>('stopSegment', {'id': id});
    } else {
      await _players.remove(id)?.dispose();
    }
    if (!_disposed) {
      state.value = {...state.value}..remove(id);
      _stopTimerIfIdle();
    }
  }

  Future<void> _poll() async {
    if (_disposed || _polling) return;
    _polling = true;
    final generation = _generation;
    final ids = state.value.keys.toSet();
    try {
      final updated = <String, SegmentPlaybackState>{};
      if (useNative) {
        final statuses =
            await _channel.invokeMapMethod<String, dynamic>(
              'segmentPlaybackStatus',
            ) ??
            {};
        for (final id in ids) {
          final status = statuses[id] as Map?;
          if (status?['playing'] == true) {
            updated[id] = SegmentPlaybackState(
              isPlaying: true,
              position: Duration(
                milliseconds: (status!['positionMs'] as num).toInt(),
              ),
            );
          }
        }
      } else {
        for (final id in ids) {
          final player = _players[id];
          if (player != null &&
              player.processingState != ProcessingState.completed) {
            updated[id] = SegmentPlaybackState(
              isPlaying: player.playing,
              position: player.position,
            );
          } else {
            await _players.remove(id)?.dispose();
          }
        }
      }
      if (!_disposed && generation == _generation) {
        // Preserve players started during this request; never resurrect stopped ones.
        state.value = {
          for (final id in state.value.keys)
            if (!ids.contains(id))
              id: state.value[id]!
            else if (updated.containsKey(id))
              id: updated[id]!,
        };
        _stopTimerIfIdle();
      }
    } catch (_) {
      // Keep active players on transient status errors; the next tick retries.
    } finally {
      _polling = false;
    }
  }

  void _stopTimerIfIdle() {
    if (state.value.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> stopAll() async {
    _generation++;
    _timer?.cancel();
    _timer = null;
    if (!_disposed) state.value = const {};
    await Future.wait(_operations.values.toList());
    if (useNative) {
      await _channel.invokeMethod<void>('stopAllSegments');
    } else {
      final players = _players.values.toList();
      _players.clear();
      await Future.wait(players.map((p) => p.dispose()));
    }
    _operations.clear();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopAll();
    state.dispose();
  }
}
