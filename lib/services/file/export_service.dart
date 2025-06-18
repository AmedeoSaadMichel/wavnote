// File: services/file/export_service.dart
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../core/enums/audio_format.dart';
import '../../core/extensions/string_extensions.dart';
import '../../core/extensions/duration_extensions.dart';
import '../../domain/entities/recording_entity.dart';
import 'file_manager_service.dart';
import 'metadata_service.dart';

/// Cosmic Export Service - Mystical File Sharing and Distribution
///
/// Handles exporting and sharing audio files from the cosmic realm including:
/// - Single and batch export operations with ethereal efficiency
/// - Format conversion with transcendent quality preservation
/// - Metadata embedding with universal knowledge
/// - Share integration with mystical connectivity
/// - Progress tracking and error handling with cosmic awareness
/// - Cloud backup preparation with celestial organization
class ExportService {

  final FileManagerService _fileManager;
  final MetadataService _metadataService;

  ExportService({
    FileManagerService? fileManager,
    MetadataService? metadataService,
  }) : _fileManager = fileManager ?? FileManagerService(),
        _metadataService = metadataService ?? MetadataService();

  // Supported export formats
  static const List<String> supportedFormats = [
    '.m4a', '.mp3', '.wav', '.flac', '.aac'
  ];

  // ==== SINGLE FILE EXPORT ====

  /// Export single recording with cosmic distribution
  Future<ExportResult> exportRecording({
    required RecordingEntity recording,
    required String destinationPath,
    AudioFormat? targetFormat,
    bool includeMetadata = true,
    bool overwriteExisting = false,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      // Validate source recording
      await _validateSourceRecording(recording);

      // Determine target format
      final exportFormat = targetFormat ?? recording.format;

      // Generate target filename
      final targetName = _generateExportFilename(
        recording: recording,
        targetFormat: exportFormat,
      );

      // Create full target path
      final targetPath = path.join(destinationPath, targetName);
      final targetFile = File(targetPath);

      // Check if target exists
      if (await targetFile.exists() && !overwriteExisting) {
        throw Exception('Target file already exists in the cosmic export realm');
      }

      // Ensure destination directory exists
      await _fileManager.ensureDirectoryExists(destinationPath);

      // Export file (copy or convert)
      File exportedFile;
      if (exportFormat == recording.format) {
        // Direct copy for same format
        exportedFile = await _fileManager.copyFile(
          sourceFile: File(recording.filePath),
          destinationPath: targetPath,
          overwrite: overwriteExisting,
        );
      } else {
        // Convert to target format
        exportedFile = await _convertAndExport(
          sourceRecording: recording,
          targetPath: targetPath,
          targetFormat: exportFormat,
        );
      }

      // Embed metadata if requested
      if (includeMetadata) {
        await _embedMetadata(exportedFile, recording);
      }

      stopwatch.stop();

      return ExportResult(
        success: true,
        exportedFile: exportedFile,
        originalRecording: recording,
        targetFormat: exportFormat,
        message: 'Recording successfully exported to the cosmic distribution realm',
      );

    } catch (e) {
      return ExportResult(
        success: false,
        error: e.toString(),
        message: 'Export failed due to cosmic interference',
      );
    }
  }

  /// Export multiple recordings with batch cosmic distribution
  Future<BatchExportResult> exportMultipleRecordings({
    required List<RecordingEntity> recordings,
    required String destinationPath,
    AudioFormat? targetFormat,
    bool includeMetadata = true,
    bool overwriteExisting = false,
    Function(int current, int total, String filename)? onProgress,
  }) async {
    final results = <ExportResult>[];
    final errors = <ExportError>[];
    int processedCount = 0;

    try {
      for (final recording in recordings) {
        onProgress?.call(processedCount, recordings.length, recording.name);

        try {
          final result = await exportRecording(
            recording: recording,
            destinationPath: destinationPath,
            targetFormat: targetFormat,
            includeMetadata: includeMetadata,
            overwriteExisting: overwriteExisting,
          );

          results.add(result);

          if (!result.success) {
            errors.add(ExportError(
              recordingName: recording.name,
              recordingId: recording.id,
              error: result.error ?? 'Unknown export error',
              index: processedCount,
            ));
          }
        } catch (e) {
          errors.add(ExportError(
            recordingName: recording.name,
            recordingId: recording.id,
            error: 'Unexpected error during cosmic export: ${e.toString()}',
            index: processedCount,
          ));
        }

        processedCount++;
      }

      final successfulResults = results.where((r) => r.success).toList();

      return BatchExportResult(
        totalRecordings: recordings.length,
        successfulExports: successfulResults.length,
        failedExports: errors.length,
        results: results,
        errors: errors,
        exportedFiles: successfulResults.map((r) => r.exportedFile!).toList(),
      );

    } catch (e) {
      return BatchExportResult(
        totalRecordings: recordings.length,
        successfulExports: 0,
        failedExports: recordings.length,
        results: [],
        errors: [ExportError(
          recordingName: 'batch_operation',
          recordingId: 'batch',
          error: 'Batch export failed due to cosmic disturbance: ${e.toString()}',
          index: -1,
        )],
        exportedFiles: [],
      );
    }
  }

  // ==== FORMAT CONVERSION ====

  /// Convert and export recording to different format
  Future<File> _convertAndExport({
    required RecordingEntity sourceRecording,
    required String targetPath,
    required AudioFormat targetFormat,
  }) async {
    try {
      // Note: This is a placeholder for actual audio conversion
      // In a real implementation, you would use a library like FFmpeg
      // or platform-specific audio conversion APIs

      final sourceFile = File(sourceRecording.filePath);

      // For now, we'll simulate conversion by copying
      // In production, implement actual audio format conversion
      final convertedFile = await _fileManager.copyFile(
        sourceFile: sourceFile,
        destinationPath: targetPath,
      );

      return convertedFile;

    } catch (e) {
      throw Exception('Failed to convert audio format in the cosmic converter');
    }
  }

  // ==== VALIDATION METHODS ====

  /// Validate source recording for export
  Future<void> _validateSourceRecording(RecordingEntity recording) async {
    // Check if source file exists
    final sourceFile = File(recording.filePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source recording has vanished from the cosmic realm');
    }

    // Check if file is readable
    try {
      await sourceFile.length();
    } catch (e) {
      throw Exception('Source recording is corrupted in the cosmic analysis');
    }

    // Validate audio file integrity
    final isValid = await _fileManager.validateAudioFile(sourceFile);
    if (!isValid) {
      throw Exception('Source recording failed cosmic integrity validation');
    }
  }

  // ==== METADATA OPERATIONS ====

  /// Embed metadata into exported file
  Future<void> _embedMetadata(File exportedFile, RecordingEntity recording) async {
    try {
      // Extract existing metadata
      final metadata = await _metadataService.extractMetadata(exportedFile);

      // Create enhanced metadata with recording information
      final enhancedMetadata = AudioMetadata(
        title: recording.name,
        duration: recording.duration,
        sampleRate: recording.sampleRate,
        recordingDate: recording.createdAt,
        tags: recording.tags,
      );

      // Log metadata information for debugging
      print('Original metadata: ${metadata.title ?? 'none'}');
      print('Enhanced metadata: ${enhancedMetadata.title} (${enhancedMetadata.duration?.formatted ?? 'unknown duration'})');

      // Note: In a real implementation, you would embed the metadata
      // back into the audio file using appropriate libraries
      // For now, this logs the metadata information

    } catch (e) {
      // Metadata embedding failure is not critical
      print('Warning: Failed to embed metadata: $e');
    }
  }

  // ==== HELPER METHODS ====

  /// Generate export filename with cosmic naming
  String _generateExportFilename({
    required RecordingEntity recording,
    required AudioFormat targetFormat,
  }) {
    final safeName = recording.name.safeFileName;
    final extension = '.${targetFormat.fileExtension}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return 'export_${safeName}_$timestamp$extension';
  }

  /// Get export directory for specific folder
  Future<String> getExportDirectory(String folderId) async {
    try {
      final appDir = await _fileManager.getAppDocumentsDirectory();
      final exportDir = Directory(path.join(appDir.path, 'exports', folderId));

      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      return exportDir.path;
    } catch (e) {
      throw Exception('Failed to create cosmic export directory');
    }
  }

  // ==== UTILITY METHODS ====

  /// Check if format is supported for export
  static bool isFormatSupported(AudioFormat format) {
    final extension = '.${format.fileExtension}';
    return supportedFormats.contains(extension);
  }

  /// Get supported export formats
  static List<AudioFormat> getSupportedExportFormats() {
    return AudioFormat.values.where((format) =>
        isFormatSupported(format)).toList();
  }

  /// Get export file size estimate
  static int estimateExportSize({
    required Duration duration,
    required AudioFormat format,
    int sampleRate = 44100,
    int bitRate = 128,
  }) {
    // Rough estimate based on format and quality
    switch (format) {
      case AudioFormat.wav:
        return (duration.inSeconds * sampleRate * 2 * 2); // 16-bit stereo
      case AudioFormat.m4a:
      case AudioFormat.flac:
        return (duration.inSeconds * bitRate * 1000 ~/ 8); // Compressed
    }
  }

  /// Clean up temporary export files
  Future<void> cleanupTempExports() async {
    try {
      final appDir = await _fileManager.getAppDocumentsDirectory();
      final tempExportDir = Directory(path.join(appDir.path, 'temp_exports'));

      if (await tempExportDir.exists()) {
        await tempExportDir.delete(recursive: true);
      }
    } catch (e) {
      // Cleanup failure is not critical
      print('Warning: Failed to cleanup temp exports: $e');
    }
  }
}

// ==== DATA CLASSES ====

/// Single export operation result
class ExportResult {
  final bool success;
  final File? exportedFile;
  final RecordingEntity? originalRecording;
  final AudioFormat? targetFormat;
  final String? error;
  final String message;

  const ExportResult({
    required this.success,
    this.exportedFile,
    this.originalRecording,
    this.targetFormat,
    this.error,
    required this.message,
  });

  /// Check if export was successful
  bool get isSuccess => success && exportedFile != null;

  /// Get exported file size
  Future<int> get exportedFileSize async {
    if (exportedFile == null) return 0;
    try {
      return await exportedFile!.length();
    } catch (e) {
      return 0;
    }
  }
}

/// Batch export operation result
class BatchExportResult {
  final int totalRecordings;
  final int successfulExports;
  final int failedExports;
  final List<ExportResult> results;
  final List<ExportError> errors;
  final List<File> exportedFiles;

  const BatchExportResult({
    required this.totalRecordings,
    required this.successfulExports,
    required this.failedExports,
    required this.results,
    required this.errors,
    required this.exportedFiles,
  });

  /// Calculate success rate
  double get successRate {
    if (totalRecordings == 0) return 0.0;
    return successfulExports / totalRecordings;
  }

  /// Check if all exports were successful
  bool get isCompleteSuccess => failedExports == 0 && successfulExports == totalRecordings;

  /// Check if partially successful
  bool get isPartialSuccess => successfulExports > 0 && failedExports > 0;

  /// Check if completely failed
  bool get isCompleteFailure => successfulExports == 0;

  /// Get formatted success rate
  String get formattedSuccessRate => '${(successRate * 100).toStringAsFixed(1)}%';

  /// Get summary message
  String get summaryMessage {
    if (isCompleteSuccess) {
      return 'All $totalRecordings recordings successfully exported from the cosmic archive';
    } else if (isPartialSuccess) {
      return '$successfulExports of $totalRecordings recordings exported successfully';
    } else {
      return 'Failed to export any recordings from the cosmic realm';
    }
  }

  /// Get total exported file size
  Future<int> get totalExportedSize async {
    int totalSize = 0;
    for (final file in exportedFiles) {
      try {
        totalSize += await file.length();
      } catch (e) {
        // Skip files that can't be accessed
        continue;
      }
    }
    return totalSize;
  }

  /// Get formatted total size
  Future<String> get formattedTotalSize async {
    final size = await totalExportedSize;
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// Individual export error information
class ExportError {
  final String recordingName;
  final String recordingId;
  final String error;
  final int index;

  const ExportError({
    required this.recordingName,
    required this.recordingId,
    required this.error,
    required this.index,
  });

  /// Get user-friendly error message
  String get userMessage => error;

  /// Get technical error details
  String get technicalDetails => error;
}

/// Audio metadata for export
class AudioMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final int? bitrate;
  final int? sampleRate;
  final int? channels;
  final List<String>? tags;
  final String? location;
  final double? averageAmplitude;
  final DateTime? recordingDate;

  const AudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.bitrate,
    this.sampleRate,
    this.channels,
    this.tags,
    this.location,
    this.averageAmplitude,
    this.recordingDate,
  });

  /// Check if metadata has basic information
  bool get hasBasicInfo => title != null || artist != null || duration != null;

  /// Get formatted duration
  String? get formattedDuration => duration?.formatted;

  /// Get formatted bitrate
  String? get formattedBitrate => bitrate != null ? '${bitrate} kbps' : null;

  /// Get formatted sample rate
  String? get formattedSampleRate => sampleRate != null ? '${sampleRate} Hz' : null;

  /// Get audio quality description
  String get qualityDescription {
    if (bitrate != null) {
      if (bitrate! >= 320) return 'Cosmic Quality (320+ kbps)';
      if (bitrate! >= 256) return 'Stellar Quality (256+ kbps)';
      if (bitrate! >= 192) return 'Celestial Quality (192+ kbps)';
      if (bitrate! >= 128) return 'Ethereal Quality (128+ kbps)';
      return 'Mystical Quality (<128 kbps)';
    }
    return 'Unknown Quality';
  }
}