/// Transient recorder view state retained across folder navigation.
/// Lists are copied so disposing or resetting a widget cannot mutate the snapshot.
class RecordingSessionViewSnapshot {
  final List<double> waveData;
  final List<int> waveSegments;
  final Map<String, int> segmentColors;
  final int currentSegment;
  final int overwriteCount;
  final int seekBarIndex;
  final int seekVersion;
  final int futureBarsCount;
  final int seekTimeOffsetMs;
  final int consumedSampleCount;
  final double sheetOffset;
  final bool hasPausedInSession;
  final String? titleBeforeStarting;

  RecordingSessionViewSnapshot({
    required List<double> waveData,
    required List<int> waveSegments,
    required Map<String, int> segmentColors,
    required this.currentSegment,
    required this.overwriteCount,
    required this.seekBarIndex,
    required this.seekVersion,
    required this.futureBarsCount,
    required this.seekTimeOffsetMs,
    required this.consumedSampleCount,
    required this.sheetOffset,
    required this.hasPausedInSession,
    this.titleBeforeStarting,
  }) : waveData = List.unmodifiable(waveData),
       waveSegments = List.unmodifiable(waveSegments),
       segmentColors = Map.unmodifiable(segmentColors);
}
