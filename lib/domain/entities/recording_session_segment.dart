import 'recording_entity.dart';

/// An independent, recoverable take from the current recorder session.
class RecordingSessionSegment {
  final String sourcePath;
  final RecordingEntity recording;
  final int colorIndex;

  const RecordingSessionSegment({
    required this.sourcePath,
    required this.recording,
    required this.colorIndex,
  });

  RecordingSessionSegment withColor(int index) => RecordingSessionSegment(
    sourcePath: sourcePath,
    recording: recording,
    colorIndex: index,
  );
}
