// File: services/file/import_service.dart
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../core/constants/app_constants.dart';
import '../../core/enums/audio_format.dart';
import '../../core/extensions/string_extensions.dart';
import '../../domain/entities/recording_entity.dart';
import '../../domain/entities/folder_entity.dart';
import 'file_manager_service.dart';
import 'metadata_service.dart';

/// Cosmic Import Service - Mystical File Integration
///
/// Handles importing external audio files into the cosmic realm including:
/// - Multi-format audio file import with transcendent conversion
/// - Batch import operations with ethereal efficiency
/// - File validation and format verification with divine wisdom
/// - Metadata extraction and preservation with universal knowledge
/// - Progress tracking and error handling with cosmic awareness
/// - Location-based import with mystical organization
class ImportService {

  final FileManagerService _fileManager;
  final MetadataService _metadataService;

  ImportService({
    FileManagerService? fileManager,
    MetadataService? metadataService,
  }) : _fileManager = fileManager ?? FileManagerService(),
        _metadataService = metadataService ?? MetadataService();

  // Supported import formats
  static const List<String> supportedFormats = [
    '.m4a', '.aac', '.mp3', '.wav', '.flac',
    '.ogg', '.wma', '.amr', '.3gp'
  ];

  // ==== SINGLE FILE IMPORT ====

  /// Import single audio file with cosmic integration
  Future<ImportResult> importAudioFile({
    required File sourceFile,
    required FolderEntity targetFolder,
    String? customName,
    bool preserveOriginalName = false,
    bool overwriteExisting = false,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      // Validate source file
      await _validateSourceFile(sourceFile);

      // Extract metadata from source
      final metadata = await _metadataService.extractMetadata(sourceFile);

      // Generate target filename
      final targetName = _generateTargetFilename(
        sourceFile: sourceFile,
        customName: customName,
        preserveOriginalName: preserveOriginalName,
        metadata: metadata,
      );

      // Create target file path
      final targetDir = await _fileManager.createFolderDirectory(targetFolder.id);
      final targetPath = path.join(targetDir.path, targetName);
      final targetFile = File(targetPath);

      // Check if target exists
      if (await targetFile.exists() && !overwriteExisting) {
        throw Exception('Target file already exists in the cosmic realm');
      }

      // Copy file to target location
      final importedFile = await _fileManager.copyFile(
        sourceFile: sourceFile,
        destinationPath: targetPath,
        overwrite: overwriteExisting,
      );

      // Verify import integrity
      await _verifyImportIntegrity(sourceFile, importedFile);

      stopwatch.stop();

      // Create recording entity
      final recording = RecordingEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: customName ?? metadata.title ?? path.basenameWithoutExtension(targetName),
        filePath: importedFile.path,
        duration: metadata.duration ?? Duration.zero,
        createdAt: DateTime.now(),
        folderId: targetFolder.id,
        fileSize: await importedFile.length(),
        format: _detectAudioFormat(importedFile.path),
        sampleRate: metadata.sampleRate ?? 44100,
        tags: metadata.tags ?? [],
      );

      return ImportResult(
        success: true,
        recording: recording,
        importedFile: importedFile,
        originalMetadata: metadata,
        message: 'File successfully imported into the cosmic archive',
      );

    } catch (e) {
      return ImportResult(
        success: false,
        error: e.toString(),
        message: 'Import failed due to cosmic interference',
      );
    }
  }

  /// Import multiple files with batch cosmic processing
  Future<BatchImportResult> importMultipleFiles({
    required List<File> sourceFiles,
    required FolderEntity targetFolder,
    bool preserveOriginalNames = false,
    bool overwriteExisting = false,
    Function(int current, int total, String filename)? onProgress,
  }) async {
    final results = <ImportResult>[];
    final errors = <ImportError>[];
    int processedCount = 0;

    final stopwatch = Stopwatch()..start();

    try {
      for (final sourceFile in sourceFiles) {
        onProgress?.call(processedCount, sourceFiles.length, path.basename(sourceFile.path));

        try {
          final result = await importAudioFile(
            sourceFile: sourceFile,
            targetFolder: targetFolder,
            preserveOriginalName: preserveOriginalNames,
            overwriteExisting: overwriteExisting,
          );

          results.add(result);

          if (!result.success && result.error != null) {
            errors.add(ImportError(
              filename: path.basename(sourceFile.path),
              filePath: sourceFile.path,
              error: result.error!,
              index: processedCount,
            ));
          }
        } catch (e) {
          errors.add(ImportError(
            filename: path.basename(sourceFile.path),
            filePath: sourceFile.path,
            error: 'Unexpected error during cosmic import: ${e.toString()}',
            index: processedCount,
          ));
        }

        processedCount++;
      }

      stopwatch.stop();

      final successfulResults = results.where((r) => r.success).toList();

      return BatchImportResult(
        totalFiles: sourceFiles.length,
        successfulImports: successfulResults.length,
        failedImports: errors.length,
        results: results,
        errors: errors,
        recordings: successfulResults.map((r) => r.recording!).toList(),
      );

    } catch (e) {
      stopwatch.stop();

      return BatchImportResult(
        totalFiles: sourceFiles.length,
        successfulImports: 0,
        failedImports: sourceFiles.length,
        results: [],
        errors: [ImportError(
          filename: 'batch_operation',
          filePath: 'multiple_files',
          error: 'Batch import failed due to cosmic disturbance: ${e.toString()}',
          index: -1,
        )],
        recordings: [],
      );
    }
  }

  // ==== FORMAT CONVERSION ====

  /// Convert audio file to supported format
  Future<File?> convertToSupportedFormat({
    required File sourceFile,
    required AudioFormat targetFormat,
    required String outputPath,
  }) async {
    try {
      // Note: This is a placeholder for actual audio conversion
      // In a real implementation, you would use a library like FFmpeg
      // or platform-specific audio conversion APIs

      final sourceExtension = path.extension(sourceFile.path).toLowerCase();
      final targetExtension = '.${targetFormat.fileExtension}';

      // If already in target format, just copy
      if (sourceExtension == targetExtension) {
        return await _fileManager.copyFile(
          sourceFile: sourceFile,
          destinationPath: outputPath,
        );
      }

      // For now, we'll simulate conversion by copying
      // In production, implement actual audio format conversion
      final convertedFile = await _fileManager.copyFile(
        sourceFile: sourceFile,
        destinationPath: outputPath,
      );

      return convertedFile;

    } catch (e) {
      throw Exception('Failed to convert audio format in the cosmic converter');
    }
  }

  // ==== VALIDATION METHODS ====

  /// Validate source file for import
  Future<void> _validateSourceFile(File sourceFile) async {
    // Check if file exists
    if (!await sourceFile.exists()) {
      throw Exception('Source file has vanished from the material plane');
    }

    // Check file extension
    final extension = path.extension(sourceFile.path).toLowerCase();
    if (!supportedFormats.contains(extension)) {
      throw Exception('Audio format not supported in the cosmic realm: $extension');
    }

    // Check file size
    final stat = await sourceFile.stat();
    if (stat.size == 0) {
      throw Exception('Source file contains no cosmic energy (empty file)');
    }

    if (stat.size > AppConstants.maxRecordingFileSize) {
      throw Exception('File too large for cosmic storage (${stat.size.toString()})');
    }

    // Validate audio file integrity
    final isValid = await _fileManager.validateAudioFile(sourceFile);
    if (!isValid) {
      throw Exception('Audio file corrupted or invalid in the cosmic analysis');
    }
  }

  /// Verify import integrity
  Future<void> _verifyImportIntegrity(File source, File imported) async {
    final sourceStat = await source.stat();
    final importedStat = await imported.stat();

    if (sourceStat.size != importedStat.size) {
      throw Exception('Import verification failed - cosmic energy not preserved');
    }

    // Additional integrity checks could be added here
    final isValid = await _fileManager.checkFileIntegrity(imported);
    if (!isValid) {
      throw Exception('Imported file integrity compromised during cosmic transfer');
    }
  }

  // ==== HELPER METHODS ====

  /// Generate target filename with cosmic naming
  String _generateTargetFilename({
    required File sourceFile,
    String? customName,
    bool preserveOriginalName = false,
    AudioMetadata? metadata,
  }) {
    final sourceBasename = path.basenameWithoutExtension(sourceFile.path);
    final extension = path.extension(sourceFile.path);

    if (customName != null && customName.isNotEmpty) {
      return '${customName.safeFileName}$extension';
    }

    if (preserveOriginalName) {
      return '${sourceBasename.safeFileName}$extension';
    }

    // Use metadata title if available
    if (metadata?.title != null && metadata!.title!.isNotEmpty) {
      return '${metadata.title!.safeFileName}$extension';
    }

    // Generate cosmic name with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'imported_${sourceBasename.safeFileName}_$timestamp$extension';
  }

  /// Detect audio format from file path
  AudioFormat _detectAudioFormat(String filePath) {
    final extension = path.extension(filePath).toLowerCase().substring(1);

    for (final format in AudioFormat.values) {
      if (format.fileExtension == extension) {
        return format;
      }
    }

    // Default to M4A for unknown formats
    return AudioFormat.m4a;
  }

  // ==== UTILITY METHODS ====

  /// Check if file format is supported
  static bool isFormatSupported(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return supportedFormats.contains(extension);
  }

  /// Get supported format descriptions
  static Map<String, String> getSupportedFormats() {
    return {
      '.m4a': 'MPEG-4 Audio (Apple)',
      '.aac': 'Advanced Audio Coding',
      '.mp3': 'MPEG Layer-3 Audio',
      '.wav': 'Waveform Audio File',
      '.flac': 'Free Lossless Audio Codec',
      '.ogg': 'Ogg Vorbis',
      '.wma': 'Windows Media Audio',
      '.amr': 'Adaptive Multi-Rate',
      '.3gp': '3GPP Audio',
    };
  }

  /// Get file size limit description
  static String getFileSizeLimit() {
    return '${AppConstants.maxRecordingFileSize ~/ (1024 * 1024)} MB';
  }
}

// ==== DATA CLASSES ====

/// Single import operation result
class ImportResult {
  final bool success;
  final RecordingEntity? recording;
  final File? importedFile;
  final AudioMetadata? originalMetadata;
  final String? error;
  final String message;

  const ImportResult({
    required this.success,
    this.recording,
    this.importedFile,
    this.originalMetadata,
    this.error,
    required this.message,
  });

  /// Check if import was successful
  bool get isSuccess => success && recording != null;
}

/// Batch import operation result
class BatchImportResult {
  final int totalFiles;
  final int successfulImports;
  final int failedImports;
  final List<ImportResult> results;
  final List<ImportError> errors;
  final List<RecordingEntity> recordings;

  const BatchImportResult({
    required this.totalFiles,
    required this.successfulImports,
    required this.failedImports,
    required this.results,
    required this.errors,
    required this.recordings,
  });

  /// Calculate success rate
  double get successRate {
    if (totalFiles == 0) return 0.0;
    return successfulImports / totalFiles;
  }

  /// Check if all imports were successful
  bool get isCompleteSuccess => failedImports == 0 && successfulImports == totalFiles;

  /// Check if partially successful
  bool get isPartialSuccess => successfulImports > 0 && failedImports > 0;

  /// Check if completely failed
  bool get isCompleteFailure => successfulImports == 0;

  /// Get formatted success rate
  String get formattedSuccessRate => '${(successRate * 100).toStringAsFixed(1)}%';

  /// Get summary message
  String get summaryMessage {
    if (isCompleteSuccess) {
      return 'All $totalFiles files successfully imported into the cosmic archive';
    } else if (isPartialSuccess) {
      return '$successfulImports of $totalFiles files imported successfully';
    } else {
      return 'Failed to import any files into the cosmic realm';
    }
  }
}

/// Individual import error information
class ImportError {
  final String filename;
  final String filePath;
  final String error;
  final int index;

  const ImportError({
    required this.filename,
    required this.filePath,
    required this.error,
    required this.index,
  });

  /// Get user-friendly error message
  String get userMessage => error;

  /// Get technical error details
  String get technicalDetails => error;
}

/// Import exception types
enum ImportErrorType {
  fileNotFound,
  unsupportedFormat,
  emptyFile,
  fileTooLarge,
  invalidAudioFile,
  fileExists,
  conversionFailed,
  integrityCheckFailed,
  batchFailed,
  unknown,
}

/// Import exception with cosmic messaging
class ImportException implements Exception {
  final String message;
  final ImportErrorType type;
  final String filePath;
  final Object? originalException;

  const ImportException(
      this.message,
      this.type,
      this.filePath, {
        this.originalException,
      });

  /// Get user-friendly error message
  String get userMessage {
    switch (type) {
      case ImportErrorType.fileNotFound:
        return 'File not found in the cosmic realm';
      case ImportErrorType.unsupportedFormat:
        return 'Audio format not supported by the cosmic archive';
      case ImportErrorType.emptyFile:
        return 'File contains no cosmic energy (empty)';
      case ImportErrorType.fileTooLarge:
        return 'File too large for cosmic storage';
      case ImportErrorType.invalidAudioFile:
        return 'Audio file corrupted or invalid';
      case ImportErrorType.fileExists:
        return 'File already exists in the cosmic archive';
      case ImportErrorType.conversionFailed:
        return 'Failed to convert audio format';
      case ImportErrorType.integrityCheckFailed:
        return 'File integrity compromised during import';
      case ImportErrorType.batchFailed:
        return 'Batch import operation failed';
      case ImportErrorType.unknown:
        return 'Unknown cosmic interference during import';
    }
  }

  @override
  String toString() {
    return 'ImportException: $message (Type: $type, File: $filePath)';
  }
}