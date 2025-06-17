// File: presentation/blocs/recording/recording_event.dart
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
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;

  const StartRecording({
    this.folderId,
    required this.format,
    this.sampleRate = 44100,
    this.bitRate = 128000,
  });

  @override
  List<Object?> get props => [folderId, format, sampleRate, bitRate];
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