// File: services/audio/waveform_processing_service.dart
import 'package:flutter/foundation.dart';
import '../../domain/entities/recording_entity.dart';
import '../../data/repositories/recording_repository_crud.dart';
import 'audio_analysis_service.dart';

/// Service for processing and storing waveform data for recordings
class WaveformProcessingService {
  final AudioAnalysisService _audioAnalysisService = AudioAnalysisService();
  final RecordingRepositoryCrud _recordingRepository =
      RecordingRepositoryCrud();

  /// Process a recording to extract and store waveform data
  Future<RecordingEntity?> processRecordingWaveform(
    RecordingEntity recording,
  ) async {
    try {
      debugPrint('🎵 Processing waveform for recording: ${recording.name}');

      if (recording.waveformData != null &&
          recording.waveformData!.isNotEmpty) {
        debugPrint('✅ Recording already has waveform data');
        return recording;
      }

      // RISOLUZIONE PATH ASINCRONA
      final absolutePath = await recording.resolvedFilePath;

      // Extract waveform from audio file
      final waveformData = await _audioAnalysisService.extractWaveformFromFile(
        absolutePath,
        sampleCount: 200,
      );

      if (waveformData.isNotEmpty) {
        debugPrint(
          '✅ Successfully extracted waveform data (${waveformData.length} samples)',
        );

        final updatedRecording = recording.copyWith(
          waveformData: waveformData,
          updatedAt: DateTime.now(),
        );

        final savedRecording = await _recordingRepository.updateRecording(
          updatedRecording,
        );
        debugPrint('💾 Waveform data saved to database');

        return savedRecording;
      } else {
        debugPrint('⚠️ Could not extract waveform data from audio file');
        return recording;
      }
    } catch (e) {
      debugPrint('❌ Error processing waveform for ${recording.name}: $e');
      return recording;
    }
  }

  /// Process waveforms for multiple recordings in batch
  Future<List<RecordingEntity>> batchProcessWaveforms(
    List<RecordingEntity> recordings,
  ) async {
    debugPrint('🔄 Batch processing ${recordings.length} recordings');
    final List<RecordingEntity> processedRecordings = [];
    for (final recording in recordings) {
      final processedRecording = await processRecordingWaveform(recording);
      if (processedRecording != null) {
        processedRecordings.add(processedRecording);
      }
    }
    return processedRecordings;
  }

  bool needsWaveformProcessing(RecordingEntity recording) {
    return recording.waveformData == null || recording.waveformData!.isEmpty;
  }

  Future<List<RecordingEntity>> getRecordingsNeedingProcessing() async {
    try {
      final allRecordings = await _recordingRepository.getAllRecordings();
      return allRecordings
          .where((recording) => needsWaveformProcessing(recording))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting recordings needing processing: $e');
      return [];
    }
  }

  Future<void> processAllPendingWaveforms() async {
    try {
      final pendingRecordings = await getRecordingsNeedingProcessing();
      if (pendingRecordings.isEmpty) return;
      await batchProcessWaveforms(pendingRecordings);
    } catch (e) {
      debugPrint('❌ Error in bulk waveform processing: $e');
    }
  }
}
