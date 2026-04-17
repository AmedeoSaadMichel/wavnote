// File: lib/presentation/screens/recording/controllers/recording_playback_view_state.dart

import 'package:flutter/foundation.dart';

enum RecordingPlaybackStatus {
  idle,
  preparing,
  ready,
  playing,
  paused,
  completed,
  error,
}

@immutable
class RecordingPlaybackViewState {
  final String? expandedRecordingId;
  final String? activeRecordingId;
  final RecordingPlaybackStatus status;
  final Duration position;
  final Duration duration;
  final bool isBuffering;
  final String? errorMessage;

  const RecordingPlaybackViewState({
    this.expandedRecordingId,
    this.activeRecordingId,
    required this.status,
    required this.position,
    required this.duration,
    required this.isBuffering,
    this.errorMessage,
  });

  bool get isExpanded => expandedRecordingId != null;
  bool get isPlaying => status == RecordingPlaybackStatus.playing;
  bool get isLoading =>
      status == RecordingPlaybackStatus.preparing || isBuffering;

  // Sentinella per i campi nullable per permettere il reset a null in copyWith
  static const _Undefined _undefined = _Undefined();

  RecordingPlaybackViewState copyWith({
    Object? expandedRecordingId = _undefined,
    Object? activeRecordingId = _undefined,
    RecordingPlaybackStatus? status,
    Duration? position,
    Duration? duration,
    bool? isBuffering,
    Object? errorMessage = _undefined,
  }) {
    return RecordingPlaybackViewState(
      expandedRecordingId: expandedRecordingId == _undefined
          ? this.expandedRecordingId
          : expandedRecordingId as String?,
      activeRecordingId: activeRecordingId == _undefined
          ? this.activeRecordingId
          : activeRecordingId as String?,
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isBuffering: isBuffering ?? this.isBuffering,
      errorMessage: errorMessage == _undefined
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingPlaybackViewState &&
          runtimeType == other.runtimeType &&
          expandedRecordingId == other.expandedRecordingId &&
          activeRecordingId == other.activeRecordingId &&
          status == other.status &&
          position == other.position &&
          duration == other.duration &&
          isBuffering == other.isBuffering &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      expandedRecordingId.hashCode ^
      activeRecordingId.hashCode ^
      status.hashCode ^
      position.hashCode ^
      duration.hashCode ^
      isBuffering.hashCode ^
      errorMessage.hashCode;

  @override
  String toString() {
    return 'RecordingPlaybackViewState{expandedRecordingId: $expandedRecordingId, activeRecordingId: $activeRecordingId, status: $status, position: $position, duration: $duration, isBuffering: $isBuffering, errorMessage: $errorMessage}';
  }
}

// Classe sentinella per indicare un valore non fornito in copyWith
class _Undefined {
  const _Undefined();
}
