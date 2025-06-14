// File: presentation/blocs/recording/recording_event.dart
part of 'recording_bloc.dart';

/// Base class for all recording-related events
abstract class RecordingEvent extends Equatable {
  const RecordingEvent();

  @override
  List<Object?> get props => [];
}

/// Event to start recording
class StartRecording extends RecordingEvent {
  final String folderId;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;

  const StartRecording({
    required this.folderId,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
  });

  @override
  List<Object> get props => [folderId, format, sampleRate, bitRate];

  @override
  String toString() => 'StartRecording { folderId: $folderId, format: $format }';
}

/// Event to stop recording
class StopRecording extends RecordingEvent {
  final String? recordingName;

  const StopRecording({this.recordingName});

  @override
  List<Object?> get props => [recordingName];

  @override
  String toString() => 'StopRecording { name: $recordingName }';
}

/// Event to pause recording
class PauseRecording extends RecordingEvent {
  const PauseRecording();

  @override
  String toString() => 'PauseRecording';
}

/// Event to resume recording
class ResumeRecording extends RecordingEvent {
  const ResumeRecording();

  @override
  String toString() => 'ResumeRecording';
}

/// Event to cancel recording
class CancelRecording extends RecordingEvent {
  const CancelRecording();

  @override
  String toString() => 'CancelRecording';
}

/// Internal event to update amplitude
class UpdateRecordingAmplitude extends RecordingEvent {
  final double amplitude;

  const UpdateRecordingAmplitude(this.amplitude);

  @override
  List<Object> get props => [amplitude];

  @override
  String toString() => 'UpdateRecordingAmplitude { amplitude: $amplitude }';
}

/// Internal event to update duration
class UpdateRecordingDuration extends RecordingEvent {
  final Duration duration;

  const UpdateRecordingDuration(this.duration);

  @override
  List<Object> get props => [duration];

  @override
  String toString() => 'UpdateRecordingDuration { duration: $duration }';
}

/// Event to check recording permissions
class CheckRecordingPermissions extends RecordingEvent {
  const CheckRecordingPermissions();

  @override
  String toString() => 'CheckRecordingPermissions';
}

/// Event to request recording permissions
class RequestRecordingPermissions extends RecordingEvent {
  const RequestRecordingPermissions();

  @override
  String toString() => 'RequestRecordingPermissions';
}