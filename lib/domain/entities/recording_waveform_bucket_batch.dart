// File: lib/domain/entities/recording_waveform_bucket_batch.dart
import 'package:equatable/equatable.dart';

/// Batch di barre waveform generate dal motore nativo.
///
/// Ogni campione rappresenta circa 100ms di frame audio reali.
class RecordingWaveformBucketBatch extends Equatable {
  const RecordingWaveformBucketBatch({
    required this.startIndex,
    required this.samples,
    required this.totalCount,
  });

  final int startIndex;
  final List<double> samples;
  final int totalCount;

  @override
  List<Object?> get props => [startIndex, samples, totalCount];
}
