// File: presentation/blocs/audio_recorder/audio_recorder_event.dart
part of 'audio_recorder_bloc.dart';

/// Base class for all audio recorder events
///
/// Events represent user actions and system triggers that cause
/// state changes in the audio recording system.
abstract class AudioRecorderEvent extends Equatable {
  const AudioRecorderEvent();

  @override
  List<Object?> get props => [];
}

// ==== RECORDING LIFECYCLE EVENTS ====

/// Event to start a new recording session
class StartRecordingRequested extends AudioRecorderEvent {
  final String folderId;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final String? customName;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final List<String> tags;

  const StartRecordingRequested({
    required this.folderId,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    this.customName,
    this.latitude,
    this.longitude,
    this.locationName,
    this.tags = const [],
  });

  @override
  List<Object?> get props => [
    folderId,
    format,
    sampleRate,
    bitRate,
    customName,
    latitude,
    longitude,
    locationName,
    tags,
  ];

  @override
  String toString() => 'StartRecordingRequested { folder: $folderId, format: $format }';
}

/// Event to stop the current recording session
class StopRecordingRequested extends AudioRecorderEvent {
  final String? customName;

  const StopRecordingRequested({this.customName});

  @override
  List<Object?> get props => [customName];

  @override
  String toString() => 'StopRecordingRequested { customName: $customName }';
}

/// Event to pause the current recording
class PauseRecordingRequested extends AudioRecorderEvent {
  const PauseRecordingRequested();

  @override
  String toString() => 'PauseRecordingRequested';
}

/// Event to resume a paused recording
class ResumeRecordingRequested extends AudioRecorderEvent {
  const ResumeRecordingRequested();

  @override
  String toString() => 'ResumeRecordingRequested';
}

/// Event to cancel the current recording session
class CancelRecordingRequested extends AudioRecorderEvent {
  final String reason;

  const CancelRecordingRequested({
    this.reason = 'User cancelled',
  });

  @override
  List<Object?> get props => [reason];

  @override
  String toString() => 'CancelRecordingRequested { reason: $reason }';
}

// ==== RECORDING MANAGEMENT EVENTS ====

/// Event to delete a completed recording
class DeleteRecordingRequested extends AudioRecorderEvent {
  final String recordingId;
  final bool createBackup;

  const DeleteRecordingRequested({
    required this.recordingId,
    this.createBackup = false,
  });

  @override
  List<Object?> get props => [recordingId, createBackup];

  @override
  String toString() => 'DeleteRecordingRequested { id: $recordingId, backup: $createBackup }';
}

// ==== REAL-TIME UPDATE EVENTS ====

/// Event to update the current recording duration
class UpdateRecordingDuration extends AudioRecorderEvent {
  final Duration duration;

  const UpdateRecordingDuration(this.duration);

  @override
  List<Object?> get props => [duration];

  @override
  String toString() => 'UpdateRecordingDuration { duration: ${duration.inSeconds}s }';
}

/// Event to update the current recording amplitude
class UpdateRecordingAmplitude extends AudioRecorderEvent {
  final double amplitude;

  const UpdateRecordingAmplitude(this.amplitude);

  @override
  List<Object?> get props => [amplitude];

  @override
  String toString() => 'UpdateRecordingAmplitude { amplitude: ${amplitude.toStringAsFixed(2)} }';
}

// ==== SESSION MANAGEMENT EVENTS ====

/// Event to restore a recording session (app restart, background return)
class RestoreSessionRequested extends AudioRecorderEvent {
  final RecordingSession session;
  final PausedRecordingSession? pausedSession;
  final DateTime sessionStartTime;
  final Duration totalPausedDuration;
  final Duration currentDuration;

  const RestoreSessionRequested({
    required this.session,
    this.pausedSession,
    required this.sessionStartTime,
    required this.totalPausedDuration,
    required this.currentDuration,
  });

  @override
  List<Object?> get props => [
    session,
    pausedSession,
    sessionStartTime,
    totalPausedDuration,
    currentDuration,
  ];

  @override
  String toString() => 'RestoreSessionRequested { session: ${session.filePath} }';
}

// ==== CONVENIENCE FACTORY EVENTS ====

/// Quick start recording with default settings
class QuickStartRecording extends AudioRecorderEvent {
  final String folderId;
  final String? customName;

  const QuickStartRecording({
    required this.folderId,
    this.customName,
  });

  @override
  List<Object?> get props => [folderId, customName];

  /// Convert to full start recording event with default settings
  StartRecordingRequested toStartRecordingEvent() {
    return StartRecordingRequested(
      folderId: folderId,
      format: AudioFormat.m4a, // Default format
      sampleRate: 44100, // CD quality
      bitRate: 128000, // Good quality, reasonable size
      customName: customName,
    );
  }

  @override
  String toString() => 'QuickStartRecording { folder: $folderId, name: $customName }';
}

/// High quality recording for important content
class StartHighQualityRecording extends AudioRecorderEvent {
  final String folderId;
  final String? customName;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final List<String> tags;

  const StartHighQualityRecording({
    required this.folderId,
    this.customName,
    this.latitude,
    this.longitude,
    this.locationName,
    this.tags = const [],
  });

  @override
  List<Object?> get props => [folderId, customName, latitude, longitude, locationName, tags];

  /// Convert to full start recording event with high quality settings
  StartRecordingRequested toStartRecordingEvent() {
    return StartRecordingRequested(
      folderId: folderId,
      format: AudioFormat.flac, // Lossless quality
      sampleRate: 48000, // High quality
      bitRate: 320000, // Maximum quality
      customName: customName,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      tags: tags,
    );
  }

  @override
  String toString() => 'StartHighQualityRecording { folder: $folderId }';
}

/// Compact recording for voice notes
class StartCompactRecording extends AudioRecorderEvent {
  final String folderId;
  final String? customName;

  const StartCompactRecording({
    required this.folderId,
    this.customName,
  });

  @override
  List<Object?> get props => [folderId, customName];

  /// Convert to full start recording event with compact settings
  StartRecordingRequested toStartRecordingEvent() {
    return StartRecordingRequested(
      folderId: folderId,
      format: AudioFormat.m4a, // Good compression
      sampleRate: 22050, // Voice quality
      bitRate: 64000, // Compact size
      customName: customName,
    );
  }

  @override
  String toString() => 'StartCompactRecording { folder: $folderId }';
}

// ==== ERROR RECOVERY EVENTS ====

/// Event to retry a failed operation
class RetryLastOperation extends AudioRecorderEvent {
  const RetryLastOperation();

  @override
  String toString() => 'RetryLastOperation';
}

/// Event to clear error state and return to initial state
class ClearError extends AudioRecorderEvent {
  const ClearError();

  @override
  String toString() => 'ClearError';
}

/// Event to reset the entire recorder state
class ResetRecorder extends AudioRecorderEvent {
  const ResetRecorder();

  @override
  String toString() => 'ResetRecorder';
}
