// File: services/audio/waveform_processing_service.dart
import '../../domain/entities/recording_entity.dart';
import '../../data/repositories/recording_repository_crud.dart';
import 'audio_analysis_service.dart';

/// Service for processing and storing waveform data for recordings
/// 
/// This service handles the background processing of audio files
/// to extract real waveform data and store it in the database.
class WaveformProcessingService {
  static const String _tag = 'WaveformProcessingService';
  
  final AudioAnalysisService _audioAnalysisService = AudioAnalysisService();
  final RecordingRepositoryCrud _recordingRepository = RecordingRepositoryCrud();

  /// Process a recording to extract and store waveform data
  /// 
  /// This should be called after a recording is completed to
  /// analyze the audio file and store the waveform data.
  Future<RecordingEntity?> processRecordingWaveform(RecordingEntity recording) async {
    try {
      print('🎵 Processing waveform for recording: ${recording.name}');
      
      // Check if recording already has waveform data
      if (recording.waveformData != null && recording.waveformData!.isNotEmpty) {
        print('✅ Recording already has waveform data');
        return recording;
      }

      // Extract waveform from audio file
      final waveformData = await _audioAnalysisService.extractWaveformFromFile(
        recording.filePath,
        sampleCount: 200,
      );

      if (waveformData.isNotEmpty) {
        print('✅ Successfully extracted waveform data (${waveformData.length} samples)');
        
        // Update recording with waveform data
        final updatedRecording = recording.copyWith(
          waveformData: waveformData,
          updatedAt: DateTime.now(),
        );

        // Save to database
        final savedRecording = await _recordingRepository.updateRecording(updatedRecording);
        print('💾 Waveform data saved to database');
        
        return savedRecording;
      } else {
        print('⚠️ Could not extract waveform data from audio file');
        return recording;
      }

    } catch (e) {
      print('❌ Error processing waveform for ${recording.name}: $e');
      return recording;
    }
  }

  /// Process waveforms for multiple recordings in batch
  /// 
  /// Useful for processing existing recordings that don't have waveform data
  Future<List<RecordingEntity>> batchProcessWaveforms(List<RecordingEntity> recordings) async {
    print('🔄 Batch processing ${recordings.length} recordings for waveforms');
    
    final List<RecordingEntity> processedRecordings = [];
    
    for (final recording in recordings) {
      final processedRecording = await processRecordingWaveform(recording);
      if (processedRecording != null) {
        processedRecordings.add(processedRecording);
      }
    }
    
    print('✅ Batch processing complete: ${processedRecordings.length} recordings processed');
    return processedRecordings;
  }

  /// Check if a recording needs waveform processing
  bool needsWaveformProcessing(RecordingEntity recording) {
    return recording.waveformData == null || recording.waveformData!.isEmpty;
  }

  /// Get recordings that need waveform processing
  Future<List<RecordingEntity>> getRecordingsNeedingProcessing() async {
    try {
      final allRecordings = await _recordingRepository.getAllRecordings();
      
      final needsProcessing = allRecordings
          .where((recording) => needsWaveformProcessing(recording))
          .toList();
      
      print('📊 Found ${needsProcessing.length} recordings needing waveform processing');
      return needsProcessing;
      
    } catch (e) {
      print('❌ Error getting recordings needing processing: $e');
      return [];
    }
  }

  /// Process all recordings that need waveform data
  Future<void> processAllPendingWaveforms() async {
    try {
      print('🚀 Starting bulk waveform processing...');
      
      final pendingRecordings = await getRecordingsNeedingProcessing();
      
      if (pendingRecordings.isEmpty) {
        print('✅ No recordings need waveform processing');
        return;
      }
      
      await batchProcessWaveforms(pendingRecordings);
      
      print('🎉 Bulk waveform processing complete!');
      
    } catch (e) {
      print('❌ Error in bulk waveform processing: $e');
    }
  }
}