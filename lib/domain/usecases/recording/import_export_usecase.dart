// File: domain/usecases/recording/import_export_usecase.dart
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../../../core/enums/audio_format.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/recording_repository.dart';
import '../../entities/recording_entity.dart';

/// Use case for managing audio file import and export operations
///
/// Provides functionality to import external audio files into the app
/// and export recordings to external storage with optional format conversion.
/// Handles batch operations, metadata export, and comprehensive error handling.
class ImportExportUseCase {

  final RecordingRepository _recordingRepository;

  ImportExportUseCase({
    required RecordingRepository recordingRepository,
  }) : _recordingRepository = recordingRepository;

  // ==== IMPORT OPERATIONS ====

  /// Import a single audio file from external storage
  Future<ImportResult> importAudioFile({
    required String sourceFilePath,
    String? targetFolderId,
    String? customName,
    AudioFormat? preferredFormat,
  }) async {
    try {
      // Validate source file
      if (!await _validateSourceFile(sourceFilePath)) {
        return ImportResult.failure('Source file not found or invalid: $sourceFilePath');
      }

      // Detect audio format from file extension
      final sourceFormat = _detectFormatFromExtension(sourceFilePath);
      if (sourceFormat == null) {
        return ImportResult.failure('Unsupported audio format');
      }

      // Generate unique target path
      final fileName = customName ?? _generateImportedFileName(sourceFilePath);
      final targetFormat = preferredFormat ?? sourceFormat;
      final targetPath = await _generateTargetFilePath(fileName, targetFormat);

      // Copy file to app directory
      final copySuccess = await _copyAudioFile(sourceFilePath, targetPath);
      if (!copySuccess) {
        return ImportResult.failure('Failed to copy audio file');
      }

      // Get file information
      final fileInfo = await _getFileInfo(targetPath);

      // Create recording entity
      final recording = RecordingEntity.create(
        name: fileName,
        filePath: targetPath,
        folderId: targetFolderId ?? 'default',
        format: targetFormat,
        duration: fileInfo.duration,
        fileSize: fileInfo.size,
        sampleRate: fileInfo.sampleRate,
      );

      // Save to database
      final savedRecording = await _recordingRepository.createRecording(recording);

      print('✅ Successfully imported: $fileName');
      return ImportResult.success(savedRecording);

    } catch (e) {
      print('❌ Import failed: $e');
      return ImportResult.failure('Import error: ${e.toString()}');
    }
  }

  /// Import multiple audio files in batch
  Future<BatchImportResult> importMultipleFiles({
    required List<String> sourceFilePaths,
    String? targetFolderId,
    AudioFormat? preferredFormat,
    Function(int current, int total)? onProgress,
  }) async {
    final results = <ImportResult>[];
    final successful = <RecordingEntity>[];
    final failed = <String>[];

    try {
      for (int i = 0; i < sourceFilePaths.length; i++) {
        onProgress?.call(i + 1, sourceFilePaths.length);

        final result = await importAudioFile(
          sourceFilePath: sourceFilePaths[i],
          targetFolderId: targetFolderId,
          preferredFormat: preferredFormat,
        );

        results.add(result);

        if (result.isSuccess) {
          successful.add(result.recording!);
        } else {
          failed.add(sourceFilePaths[i]);
        }
      }

      print('✅ Batch import completed: ${successful.length}/${sourceFilePaths.length}');
      return BatchImportResult(
        successful: successful,
        failed: failed,
        results: results,
      );

    } catch (e) {
      print('❌ Batch import error: $e');
      return BatchImportResult(
        successful: successful,
        failed: failed,
        results: results,
      );
    }
  }

  // ==== EXPORT OPERATIONS ====

  /// Export a single recording to external storage
  Future<ExportResult> exportRecording({
    required String recordingId,
    required String targetDirectory,
    String? customFileName,
    AudioFormat? targetFormat,
    bool includeMetadata = false,
  }) async {
    try {
      // Get recording from database
      final recording = await _recordingRepository.getRecordingById(recordingId);
      if (recording == null) {
        return ExportResult.failure('Recording not found: $recordingId');
      }

      // Validate source file exists
      if (!await _validateSourceFile(recording.filePath)) {
        return ExportResult.failure('Source recording file not found');
      }

      // Ensure target directory exists
      await _ensureDirectoryExists(targetDirectory);

      // Generate export file path
      final fileName = customFileName ?? _sanitizeFileName(recording.name);
      final exportFormat = targetFormat ?? recording.format;
      final exportPath = _generateExportPath(targetDirectory, fileName, exportFormat);

      // Copy/convert file
      final exportSuccess = await _exportAudioFile(
        recording.filePath,
        exportPath,
        recording.format,
        exportFormat,
      );

      if (!exportSuccess) {
        return ExportResult.failure('Failed to export audio file');
      }

      // Export metadata if requested
      String? metadataPath;
      if (includeMetadata) {
        metadataPath = await _exportMetadata(recording, targetDirectory);
      }

      print('✅ Successfully exported: $fileName');
      return ExportResult.success(exportPath, metadataPath);

    } catch (e) {
      print('❌ Export failed: $e');
      return ExportResult.failure('Export error: ${e.toString()}');
    }
  }

  /// Export multiple recordings in batch
  Future<BatchExportResult> exportMultipleRecordings({
    required List<String> recordingIds,
    required String targetDirectory,
    AudioFormat? targetFormat,
    bool includeMetadata = false,
    Function(int current, int total)? onProgress,
  }) async {
    final successful = <String>[];
    final failed = <String>[];

    try {
      for (int i = 0; i < recordingIds.length; i++) {
        onProgress?.call(i + 1, recordingIds.length);

        final result = await exportRecording(
          recordingId: recordingIds[i],
          targetDirectory: targetDirectory,
          targetFormat: targetFormat,
          includeMetadata: includeMetadata,
        );

        if (result.isSuccess) {
          successful.add(result.filePath!);
        } else {
          failed.add(recordingIds[i]);
        }
      }

      print('✅ Batch export completed: ${successful.length}/${recordingIds.length}');
      return BatchExportResult(
        successful: successful,
        failed: failed,
      );

    } catch (e) {
      print('❌ Batch export error: $e');
      return BatchExportResult(
        successful: successful,
        failed: failed,
      );
    }
  }

  /// Export all recordings metadata as JSON
  Future<ExportResult> exportMetadataDatabase({
    required String targetDirectory,
    bool includeStatistics = true,
  }) async {
    try {
      // Get all recordings
      final recordings = await _recordingRepository.getAllRecordings();

      // Build metadata structure
      final metadata = {
        'exportInfo': {
          'exportDate': DateTime.now().toIso8601String(),
          'totalRecordings': recordings.length,
          'appVersion': '1.0.0',
        },
        'recordings': recordings.map((recording) => {
          'id': recording.id,
          'name': recording.name,
          'filePath': recording.filePath,
          'folderId': recording.folderId,
          'format': recording.format.name,
          'duration': recording.duration.inMilliseconds,
          'fileSize': recording.fileSize,
          'sampleRate': recording.sampleRate,
          'createdAt': recording.createdAt.toIso8601String(),
          'hasLocation': recording.hasLocation,
          'isFavorite': recording.isFavorite,
          'tags': recording.tags,
        }).toList(),
      };

      // Add statistics if requested
      if (includeStatistics) {
        metadata['statistics'] = await _generateExportStatistics(recordings);
      }

      // Generate file path
      final fileName = 'recordings_metadata_${DateFormatter.formatForExport(DateTime.now())}.json';
      final filePath = path.join(targetDirectory, fileName);

      // Write to file
      final jsonString = const JsonEncoder.withIndent('  ').convert(metadata);
      await File(filePath).writeAsString(jsonString);

      print('✅ Metadata database exported: $fileName');
      return ExportResult.success(filePath);

    } catch (e) {
      print('❌ Metadata export failed: $e');
      return ExportResult.failure('Metadata export error: ${e.toString()}');
    }
  }

  // ==== HELPER METHODS ====

  /// Validate if source file exists and is accessible
  Future<bool> _validateSourceFile(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists() && await file.length() > 0;
    } catch (e) {
      return false;
    }
  }

  /// Detect audio format from file extension
  AudioFormat? _detectFormatFromExtension(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.wav':
        return AudioFormat.wav;
      case '.m4a':
      case '.mp4':
        return AudioFormat.m4a;
      case '.flac':
        return AudioFormat.flac;
      default:
        return null;
    }
  }

  /// Generate filename for imported file
  String _generateImportedFileName(String sourceFilePath) {
    final baseName = path.basenameWithoutExtension(sourceFilePath);
    final timestamp = DateFormatter.formatForFileName(DateTime.now());
    return 'Import_${baseName}_$timestamp';
  }

  /// Generate target file path for import
  Future<String> _generateTargetFilePath(String fileName, AudioFormat format) async {
    try {
      final recordingsDir = await FileUtils.getRecordingsDirectory();
      final extension = _getExtensionForFormat(format);
      final sanitizedName = _sanitizeFileName(fileName);

      return await FileUtils.generateUniqueFileName(
        recordingsDir.path,
        sanitizedName,
        '.$extension',
      );
    } catch (e) {
      throw Exception('Failed to generate target path: $e');
    }
  }

  /// Get file extension for audio format
  String _getExtensionForFormat(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return 'wav';
      case AudioFormat.m4a:
        return 'm4a';
      case AudioFormat.flac:
        return 'flac';
    }
  }

  /// Sanitize filename by removing invalid characters
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// Copy audio file from source to target
  Future<bool> _copyAudioFile(String sourcePath, String targetPath) async {
    try {
      final sourceFile = File(sourcePath);
      await sourceFile.copy(targetPath);
      return true;
    } catch (e) {
      print('❌ Copy failed: $e');
      return false;
    }
  }

  /// Get file information for imported file
  Future<FileInfo> _getFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      final stats = await file.stat();

      // For now, return basic info with estimates
      // TODO: Implement actual audio file analysis
      return FileInfo(
        size: stats.size,
        duration: const Duration(minutes: 1), // Placeholder
        sampleRate: 44100, // Default
      );
    } catch (e) {
      throw Exception('Failed to get file info: $e');
    }
  }

  /// Ensure target directory exists
  Future<void> _ensureDirectoryExists(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  /// Generate export file path
  String _generateExportPath(String directory, String fileName, AudioFormat format) {
    final extension = _getExtensionForFormat(format);
    return path.join(directory, '$fileName.$extension');
  }

  /// Export audio file with optional format conversion
  Future<bool> _exportAudioFile(
      String sourcePath,
      String targetPath,
      AudioFormat sourceFormat,
      AudioFormat targetFormat,
      ) async {
    try {
      if (sourceFormat == targetFormat) {
        // Simple copy
        await File(sourcePath).copy(targetPath);
      } else {
        // TODO: Implement format conversion
        // For now, just copy with warning
        await File(sourcePath).copy(targetPath);
        print('⚠️ Format conversion not yet implemented, copied as-is');
      }
      return true;
    } catch (e) {
      print('❌ Export copy failed: $e');
      return false;
    }
  }

  /// Export recording metadata to JSON file
  Future<String> _exportMetadata(RecordingEntity recording, String targetDirectory) async {
    final metadata = {
      'recording': {
        'id': recording.id,
        'name': recording.name,
        'format': recording.format.name,
        'duration': recording.duration.inMilliseconds,
        'durationFormatted': recording.durationFormatted,
        'fileSize': recording.fileSize,
        'fileSizeFormatted': recording.fileSizeFormatted,
        'sampleRate': recording.sampleRate,
        'qualityDescription': recording.qualityDescription,
        'createdAt': recording.createdAt.toIso8601String(),
        'folderId': recording.folderId,
        'hasLocation': recording.hasLocation,
        'isFavorite': recording.isFavorite,
        'tags': recording.tags,
      },
      'export': {
        'exportDate': DateTime.now().toIso8601String(),
        'exportedBy': 'WavNote Import/Export System',
      },
    };

    final fileName = '${_sanitizeFileName(recording.name)}_metadata.json';
    final metadataPath = path.join(targetDirectory, fileName);

    final jsonString = const JsonEncoder.withIndent('  ').convert(metadata);
    await File(metadataPath).writeAsString(jsonString);

    return metadataPath;
  }

  /// Generate export statistics
  Future<Map<String, dynamic>> _generateExportStatistics(List<RecordingEntity> recordings) async {
    if (recordings.isEmpty) {
      return {'message': 'No recordings available'};
    }

    final totalDuration = recordings.fold<Duration>(
      Duration.zero,
          (sum, recording) => sum + recording.duration,
    );

    final totalSize = recordings.fold<int>(
      0,
          (sum, recording) => sum + recording.fileSize,
    );

    final formatCounts = <String, int>{};
    final folderCounts = <String, int>{};

    for (final recording in recordings) {
      formatCounts[recording.format.name] = (formatCounts[recording.format.name] ?? 0) + 1;
      folderCounts[recording.folderId] = (folderCounts[recording.folderId] ?? 0) + 1;
    }

    return {
      'totalRecordings': recordings.length,
      'totalDuration': totalDuration.inMilliseconds,
      'totalDurationFormatted': _formatDuration(totalDuration),
      'totalSize': totalSize,
      'totalSizeFormatted': _formatFileSize(totalSize),
      'averageDuration': totalDuration.inMilliseconds ~/ recordings.length,
      'averageSize': totalSize ~/ recordings.length,
      'formatDistribution': formatCounts,
      'folderDistribution': folderCounts,
      'favoriteCount': recordings.where((r) => r.isFavorite).length,
      'withLocationCount': recordings.where((r) => r.hasLocation).length,
      'withTagsCount': recordings.where((r) => r.tags.isNotEmpty).length,
    };
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Check if a specific format is supported for import
  bool isFormatSupported(AudioFormat format) {
    return [AudioFormat.wav, AudioFormat.m4a, AudioFormat.flac].contains(format);
  }

  /// Get list of supported import formats
  List<AudioFormat> getSupportedFormats() {
    return [AudioFormat.wav, AudioFormat.m4a, AudioFormat.flac];
  }
}

// ==== HELPER CLASSES ====

/// File information for imported files
class FileInfo {
  final int size;
  final Duration duration;
  final int sampleRate;

  const FileInfo({
    required this.size,
    required this.duration,
    required this.sampleRate,
  });
}

// ==== RESULT CLASSES ====

/// Result of import operation
class ImportResult {
  final bool isSuccess;
  final String? errorMessage;
  final RecordingEntity? recording;

  ImportResult.success(this.recording)
      : isSuccess = true,
        errorMessage = null;

  ImportResult.failure(this.errorMessage)
      : isSuccess = false,
        recording = null;
}

/// Result of batch import operation
class BatchImportResult {
  final List<RecordingEntity> successful;
  final List<String> failed;
  final List<ImportResult> results;

  BatchImportResult({
    required this.successful,
    required this.failed,
    required this.results,
  });

  bool get hasFailures => failed.isNotEmpty;
  int get successCount => successful.length;
  int get failureCount => failed.length;
  int get totalCount => successCount + failureCount;
  double get successRate => totalCount > 0 ? successCount / totalCount : 0.0;
}

/// Result of export operation
class ExportResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? filePath;
  final String? metadataPath;

  ExportResult.success(this.filePath, [this.metadataPath])
      : isSuccess = true,
        errorMessage = null;

  ExportResult.failure(this.errorMessage)
      : isSuccess = false,
        filePath = null,
        metadataPath = null;
}

/// Result of batch export operation
class BatchExportResult {
  final List<String> successful;
  final List<String> failed;

  BatchExportResult({
    required this.successful,
    required this.failed,
  });

  bool get hasFailures => failed.isNotEmpty;
  int get successCount => successful.length;
  int get failureCount => failed.length;
  int get totalCount => successCount + failureCount;
  double get successRate => totalCount > 0 ? successCount / totalCount : 0.0;
}