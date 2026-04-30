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
