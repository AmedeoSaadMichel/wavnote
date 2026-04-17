// File: services/file/import_service.dart
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/audio_format.dart';
import '../../core/extensions/string_extensions.dart';
import '../../domain/entities/recording_entity.dart';
import '../../domain/entities/folder_entity.dart';
import 'file_manager_service.dart';
import 'metadata_service.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/app_file_utils.dart';

/// Service for importing audio files into the application.
class ImportService {
  final FileManagerService _fileManager;
  final MetadataService _metadataService;

  ImportService({
    FileManagerService? fileManager,
    MetadataService? metadataService,
  }) : _fileManager = fileManager ?? FileManagerService(),
       _metadataService = metadataService ?? MetadataService();

  static const List<String> supportedFormats = [
    '.m4a',
    '.aac',
    '.mp3',
    '.wav',
    '.flac',
    '.ogg',
    '.wma',
    '.amr',
    '.3gp',
  ];

  Future<ImportResult> importAudioFile({
    required File sourceFile,
    required FolderEntity targetFolder,
    String? customName,
    bool preserveOriginalName = false,
    bool overwriteExisting = false,
  }) async {
    try {
      await _validateSourceFile(sourceFile);
      final metadata = await _metadataService.extractMetadata(sourceFile);
      final targetName = _generateTargetFilename(
        sourceFile: sourceFile,
        customName: customName,
        preserveOriginalName: preserveOriginalName,
        metadata: metadata,
      );

      final targetDir = await _fileManager.createFolderDirectory(
        targetFolder.id,
      );
      final targetPath = path.join(targetDir.path, targetName);
      final targetFile = File(targetPath);

      if (await targetFile.exists() && !overwriteExisting) {
        throw FileSystemException(
          message: 'Target file already exists',
          errorType: FileSystemErrorType.fileAlreadyExists,
          context: {'filePath': targetPath},
        );
      }

      final importedFile = await _fileManager.copyFile(
        sourceFile: sourceFile,
        destinationPath: targetPath,
        overwrite: overwriteExisting,
      );

      await _verifyImportIntegrity(sourceFile, importedFile);

      // Conversione del path in relativo
      final relativePath = await AppFileUtils.toRelative(importedFile.path);

      final recording = RecordingEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name:
            customName ??
            metadata.title ??
            path.basenameWithoutExtension(targetName),
        filePath: relativePath,
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
        message: 'File successfully imported',
      );
    } catch (e) {
      if (e is WavNoteException) rethrow;
      throw FileSystemException(
        message: 'Unexpected import error: ${e.toString()}',
        errorType: FileSystemErrorType.fileCopyFailed,
        originalError: e,
      );
    }
  }

  // ==== VALIDATION METHODS ====
  Future<void> _validateSourceFile(File sourceFile) async {
    if (!await sourceFile.exists()) {
      throw FileSystemException(
        message: 'Source file does not exist',
        errorType: FileSystemErrorType.fileNotFound,
        context: {'filePath': sourceFile.path},
      );
    }
    final extension = path.extension(sourceFile.path).toLowerCase();
    if (!supportedFormats.contains(extension)) {
      throw FileSystemException(
        message: 'Audio format not supported: $extension',
        errorType: FileSystemErrorType.invalidFileName,
      );
    }
    final stat = await sourceFile.stat();
    if (stat.size == 0) {
      throw FileSystemException(
        message: 'Source file is empty',
        errorType: FileSystemErrorType.fileCorrupted,
      );
    }
    final isValid = await _fileManager.validateAudioFile(sourceFile);
    if (!isValid) {
      throw FileSystemException(
        message: 'Audio file corrupted or invalid',
        errorType: FileSystemErrorType.fileCorrupted,
      );
    }
  }

  Future<void> _verifyImportIntegrity(File source, File imported) async {
    final sourceStat = await source.stat();
    final importedStat = await imported.stat();
    if (sourceStat.size != importedStat.size) {
      throw FileSystemException(
        message: 'Import verification failed - size mismatch',
        errorType: FileSystemErrorType.fileCopyFailed,
      );
    }
  }

  String _generateTargetFilename({
    required File sourceFile,
    String? customName,
    bool preserveOriginalName = false,
    dynamic metadata,
  }) {
    final sourceBasename = path.basenameWithoutExtension(sourceFile.path);
    final extension = path.extension(sourceFile.path);
    if (customName != null && customName.isNotEmpty)
      return '${customName.safeFileName}$extension';
    if (preserveOriginalName) return '${sourceBasename.safeFileName}$extension';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'imported_${sourceBasename.safeFileName}_$timestamp$extension';
  }

  AudioFormat _detectAudioFormat(String filePath) {
    final extension = path.extension(filePath).toLowerCase().substring(1);
    for (final format in AudioFormat.values) {
      if (format.fileExtension == extension) return format;
    }
    return AudioFormat.m4a;
  }
}

// Data class (Re-added)
class ImportResult {
  final bool success;
  final RecordingEntity? recording;
  final File? importedFile;
  final dynamic originalMetadata;
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
}
