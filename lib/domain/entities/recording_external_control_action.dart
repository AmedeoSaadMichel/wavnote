// File: domain/entities/recording_external_control_action.dart

enum RecordingExternalControlAction {
  pause,
  resume,
  stop,
  cancel;

  static RecordingExternalControlAction? fromNative(String? value) {
    return switch (value) {
      'pause' => RecordingExternalControlAction.pause,
      'resume' => RecordingExternalControlAction.resume,
      'stop' => RecordingExternalControlAction.stop,
      'cancel' => RecordingExternalControlAction.cancel,
      _ => null,
    };
  }
}

class RecordingExternalControlEvent {
  final RecordingExternalControlAction action;
  final bool isCompleted;
  final bool success;
  final Duration? duration;
  final String? path;

  const RecordingExternalControlEvent.requested(this.action)
    : isCompleted = false,
      success = false,
      duration = null,
      path = null;

  const RecordingExternalControlEvent.completed({
    required this.action,
    required this.success,
    this.duration,
    this.path,
  }) : isCompleted = true;
}
