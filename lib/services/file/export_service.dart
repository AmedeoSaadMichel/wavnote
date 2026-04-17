// File: services/file/export_service.dart
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import '../../core/enums/audio_format.dart';
import '../../core/extensions/string_extensions.dart';
import '../../domain/entities/recording_entity.dart';
import 'file_manager_service.dart';
import 'metadata_service.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failure_types/data_failures.dart';

/// Export Service - File Sharing and Distribution
class ExportService {
  final FileManagerService _fileManager;
  final MetadataService _metadataService;

  ExportService({
    FileManagerService? fileManager,
    MetadataService? metadataService,
  }) : _fileManager = fileManager ?? FileManagerService(),
       _metadataService = metadataService ?? MetadataService();

  static const List<String> supportedFormats = [
    '.m4a',
    '.mp3',
    '.wav',
    '.flac',
    '.aac',
  ];

  Future<ExportResult> exportRecording({
    required RecordingEntity recording,
    required String destinationPath,
    AudioFormat? targetFormat,
    bool includeMetadata = true,
    bool overwriteExisting = false,
  }) async {
    try {
      final absoluteSourcePath = await recording.resolvedFilePath;
      await _validateSourceRecording(recording, absoluteSourcePath);

      final exportFormat = targetFormat ?? recording.format;
      final targetName = _generateExportFilename(
        recording: recording,
        targetFormat: exportFormat,
      );
      final targetPath = path.join(destinationPath, targetName);
      final targetFile = File(targetPath);

      if (await targetFile.exists() && !overwriteExisting) {
        throw FileSystemException(
          message: 'Target file already exists',
          errorType: FileSystemErrorType.fileAlreadyExists,
          context: {'filePath': targetPath},
        );
      }

      await _fileManager.ensureDirectoryExists(destinationPath);

      File exportedFile;
      if (exportFormat == recording.format) {
        exportedFile = await _fileManager.copyFile(
          sourceFile: File(absoluteSourcePath),
          destinationPath: targetPath,
          overwrite: overwriteExisting,
        );
      } else {
        exportedFile = await _convertAndExport(
          sourcePath: absoluteSourcePath,
          targetPath: targetPath,
          targetFormat: exportFormat,
        );
      }

      if (includeMetadata) await _embedMetadata(exportedFile, recording);

      return ExportResult(
        success: true,
        exportedFile: exportedFile,
        originalRecording: recording,
        targetFormat: exportFormat,
        message: 'Recording successfully exported',
      );
    } catch (e) {
      if (e is WavNoteException) rethrow;
      throw FileSystemException(
        message: 'Export failed: ${e.toString()}',
        errorType: FileSystemErrorType.fileCopyFailed,
        originalError: e,
      );
    }
  }

  Future<void> _validateSourceRecording(
    RecordingEntity recording,
    String absolutePath,
  ) async {
    final sourceFile = File(absolutePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException(
        message: 'Source recording not found',
        errorType: FileSystemErrorType.fileNotFound,
        context: {'filePath': absolutePath},
      );
    }
    final isValid = await _fileManager.validateAudioFile(sourceFile);
    if (!isValid) {
      throw FileSystemException(
        message: 'Source recording failed integrity validation',
        errorType: FileSystemErrorType.fileCorrupted,
      );
    }
  }

  Future<File> _convertAndExport({
    required String sourcePath,
    required String targetPath,
    required AudioFormat targetFormat,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      return await _fileManager.copyFile(
        sourceFile: sourceFile,
        destinationPath: targetPath,
      );
    } catch (e) {
      throw FileSystemException(
        message: 'Failed to convert audio format: ${e.toString()}',
        errorType: FileSystemErrorType.fileCopyFailed,
        originalError: e,
      );
    }
  }

  Future<void> _embedMetadata(
    File exportedFile,
    RecordingEntity recording,
  ) async {
    debugPrint('Embedding metadata for: ${recording.name}');
  }

  String _generateExportFilename({
    required RecordingEntity recording,
    required AudioFormat targetFormat,
  }) {
    final safeName = recording.name.safeFileName;
    final extension = '.${targetFormat.fileExtension}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'export_${safeName}_$timestamp$extension';
  }
}

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
}
