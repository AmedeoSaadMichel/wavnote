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
    this.bitRate = 128000, // Reverted back to original value
  });

  @override
  List<Object?> get props => [folderId, folderName, format, sampleRate, bitRate];
}

/// Event to stop recording
class StopRecording extends RecordingEvent {
  final List<double>? waveformData;
  
  const StopRecording({this.waveformData});
  
  @override
  List<Object?> get props => [waveformData];
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

// Removed ExpandRecording event - expansion now managed at screen level

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

/// Event to delete a recording
class DeleteRecording extends RecordingEvent {
  final String recordingId;

  const DeleteRecording(this.recordingId);

  @override
  List<Object> get props => [recordingId];
}

/// Event to soft delete a recording (move to Recently Deleted)
class SoftDeleteRecording extends RecordingEvent {
  final String recordingId;

  const SoftDeleteRecording(this.recordingId);

  @override
  List<Object> get props => [recordingId];
}

/// Event to permanently delete a recording
class PermanentDeleteRecording extends RecordingEvent {
  final String recordingId;

  const PermanentDeleteRecording(this.recordingId);

  @override
  List<Object> get props => [recordingId];
}

/// Event to restore a recording from Recently Deleted
class RestoreRecording extends RecordingEvent {
  final String recordingId;

  const RestoreRecording(this.recordingId);

  @override
  List<Object> get props => [recordingId];
}

/// Event to cleanup expired recordings (auto-delete after 15 days)
class CleanupExpiredRecordings extends RecordingEvent {
  const CleanupExpiredRecordings();
}

/// Event to select all recordings
class SelectAllRecordings extends RecordingEvent {
  const SelectAllRecordings();
}

/// Event to deselect all recordings
class DeselectAllRecordings extends RecordingEvent {
  const DeselectAllRecordings();
}

/// Event to delete selected recordings
class DeleteSelectedRecordings extends RecordingEvent {
  final String folderId; // Context to determine delete type
  
  const DeleteSelectedRecordings({required this.folderId});
  
  @override
  List<Object> get props => [folderId];
}

/// Event to toggle favorite status of a recording
class ToggleFavoriteRecording extends RecordingEvent {
  final String recordingId;
  
  const ToggleFavoriteRecording({required this.recordingId});
  
  @override
  List<Object> get props => [recordingId];
}