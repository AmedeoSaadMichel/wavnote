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

/// Event to move a single recording to a different folder
class MoveRecordingToFolder extends RecordingEvent {
  final String recordingId;
  final String targetFolderId;
  final String currentFolderId; // Context for UI refresh
  
  const MoveRecordingToFolder({
    required this.recordingId,
    required this.targetFolderId,
    required this.currentFolderId,
  });
  
  @override
  List<Object> get props => [recordingId, targetFolderId, currentFolderId];
}

/// Event to move selected recordings to a different folder
class MoveSelectedRecordingsToFolder extends RecordingEvent {
  final String targetFolderId;
  final String currentFolderId; // Context for UI refresh

  const MoveSelectedRecordingsToFolder({
    required this.targetFolderId,
    required this.currentFolderId,
  });

  @override
  List<Object> get props => [targetFolderId, currentFolderId];
}

/// Event per aggiornare la posizione della seek bar nella waveform (drag).
class UpdateSeekBarIndex extends RecordingEvent {
  final int seekBarIndex;
  const UpdateSeekBarIndex({required this.seekBarIndex});
  @override
  List<Object> get props => [seekBarIndex];
}

/// Event per riprodurre in anteprima la registrazione dal punto del playhead.
/// Lo stato rimane RecordingPaused; cambia solo isPlayingPreview → true.
/// Legge seekBarIndex dallo stato RecordingPaused corrente.
class PlayRecordingPreview extends RecordingEvent {
  const PlayRecordingPreview();
}

/// Event per fermare l'anteprima di playback e tornare a RecordingPaused puro.
/// [isNaturalCompletion] è true quando il playback finisce da solo (fine file),
/// false quando l'utente clicca pausa manualmente.
class StopRecordingPreview extends RecordingEvent {
  final bool isNaturalCompletion;
  const StopRecordingPreview({this.isNaturalCompletion = false});
  @override
  List<Object> get props => [isNaturalCompletion];
}

/// Event per cercare una posizione nella waveform e riprendere la registrazione da lì.
/// Triggera il trim audio al punto di seek, poi riavvia il recorder.
class SeekAndResumeRecording extends RecordingEvent {
  final int seekBarIndex;
  final String filePath;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final List<double> waveData;

  const SeekAndResumeRecording({
    required this.seekBarIndex,
    required this.filePath,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    required this.waveData,
  });

  @override
  List<Object?> get props =>
      [seekBarIndex, filePath, format, sampleRate, bitRate, waveData];
}
