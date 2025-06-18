// File: presentation/bloc/recording/recording_event.dart
part of 'recording_bloc.dart';

/// Base class for all recording events
abstract class RecordingEvent extends Equatable {
  const RecordingEvent();

  @override
  List<Object?> get props => [];
}

/// Event to start recording
class StartRecording extends RecordingEvent {
  final String? folderId;
  final String? folderName;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;

  const StartRecording({
    this.folderId,
    this.folderName,
    required this.format,
    this.sampleRate = 44100,
    this.bitRate = 128000,
  });

  @override
  List<Object?> get props => [folderId, folderName, format, sampleRate, bitRate];
}

/// Event to stop recording
class StopRecording extends RecordingEvent {
  const StopRecording();
}

/// Event to pause recording
class PauseRecording extends RecordingEvent {
  const PauseRecording();
}

/// Event to resume recording
class ResumeRecording extends RecordingEvent {
  const ResumeRecording();
}

/// Event to cancel recording
class CancelRecording extends RecordingEvent {
  const CancelRecording();
}

/// Event to update recording amplitude
class UpdateRecordingAmplitude extends RecordingEvent {
  final double amplitude;

  const UpdateRecordingAmplitude(this.amplitude);

  @override
  List<Object> get props => [amplitude];
}

/// Event to update recording duration
class UpdateRecordingDuration extends RecordingEvent {
  final Duration duration;

  const UpdateRecordingDuration(this.duration);

  @override
  List<Object> get props => [duration];
}

/// Event to check recording permissions
class CheckRecordingPermissions extends RecordingEvent {
  const CheckRecordingPermissions();
}

/// Event to request recording permissions
class RequestRecordingPermissions extends RecordingEvent {
  const RequestRecordingPermissions();
}

/// Event to load recordings for a specific folder
class LoadRecordings extends RecordingEvent {
  final String folderId;

  const LoadRecordings({required this.folderId});

  @override
  List<Object> get props => [folderId];
}

/// Event to toggle edit mode
class ToggleEditMode extends RecordingEvent {
  const ToggleEditMode();
}

/// Event to toggle recording selection
class ToggleRecordingSelection extends RecordingEvent {
  final String recordingId;

  const ToggleRecordingSelection({required this.recordingId});

  @override
  List<Object> get props => [recordingId];
}

/// Event to clear recording selection
class ClearRecordingSelection extends RecordingEvent {
  const ClearRecordingSelection();
}

/// Event to expand/collapse recording
class ExpandRecording extends RecordingEvent {
  final String recordingId;

  const ExpandRecording({required this.recordingId});

  @override
  List<Object> get props => [recordingId];
}

/// Event to update recording title
class UpdateRecordingTitle extends RecordingEvent {
  final String title;

  const UpdateRecordingTitle({required this.title});

  @override
  List<Object> get props => [title];
}

/// Event to debug load all recordings
class DebugLoadAllRecordings extends RecordingEvent {
  const DebugLoadAllRecordings();
}

/// Event to create a test recording for debugging
class DebugCreateTestRecording extends RecordingEvent {
  final String folderId;

  const DebugCreateTestRecording({required this.folderId});

  @override
  List<Object> get props => [folderId];
}