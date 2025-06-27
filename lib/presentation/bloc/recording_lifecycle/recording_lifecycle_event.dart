// File: presentation/bloc/recording_lifecycle/recording_lifecycle_event.dart
part of 'recording_lifecycle_bloc.dart';

/// Events for recording lifecycle management
abstract class RecordingLifecycleEvent extends Equatable {
  const RecordingLifecycleEvent();

  @override
  List<Object?> get props => [];
}

/// Start recording event
class StartRecording extends RecordingLifecycleEvent {
  final String filePath;
  final String? folderId;
  final String? folderName;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;

  const StartRecording({
    required this.filePath,
    this.folderId,
    this.folderName,
    this.format = AudioFormat.m4a,
    this.sampleRate = 44100,
    this.bitRate = 128000,
  });

  @override
  List<Object?> get props => [filePath, folderId, folderName, format, sampleRate, bitRate];
}

/// Stop recording event
class StopRecording extends RecordingLifecycleEvent {
  final String? title;

  const StopRecording({this.title});

  @override
  List<Object?> get props => [title];
}

/// Pause recording event
class PauseRecording extends RecordingLifecycleEvent {
  const PauseRecording();
}

/// Resume recording event
class ResumeRecording extends RecordingLifecycleEvent {
  const ResumeRecording();
}

/// Cancel recording event
class CancelRecording extends RecordingLifecycleEvent {
  const CancelRecording();
}

/// Update recording amplitude event
class UpdateRecordingAmplitude extends RecordingLifecycleEvent {
  final double amplitude;

  const UpdateRecordingAmplitude({required this.amplitude});

  @override
  List<Object> get props => [amplitude];
}

/// Update recording duration event
class UpdateRecordingDuration extends RecordingLifecycleEvent {
  final Duration duration;

  const UpdateRecordingDuration({required this.duration});

  @override
  List<Object> get props => [duration];
}

/// Update recording title event
class UpdateRecordingTitle extends RecordingLifecycleEvent {
  final String title;

  const UpdateRecordingTitle({required this.title});

  @override
  List<Object> get props => [title];
}