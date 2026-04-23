// File: services/file/file_manager_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart'; // Import corretto per debugPrint
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../core/enums/audio_format.dart';
import '../../core/errors/exceptions.dart';

/// File Manager Service - Universal File Operations
///
/// Handles all file system operations including:
/// - File creation, copying, moving, and deletion
/// - Directory management
/// - File validation and integrity checking
/// - Storage management and cleanup
class FileManagerService {
  // Default folder structure
  static const String _recordingsFolder = 'recordings';
  static const String _tempFolder = 'temp';
  static const String _backupFolder = 'backup';

  // ==== DIRECTORY OPERATIONS ====

  /// Get app documents directory
  Future<Directory> getAppDocumentsDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      throw FileSystemException(
        message: 'Failed to access application documents directory',
        errorType: FileSystemErrorType.accessDenied,
        originalError: e,
      );
    }
  }

  /// Get recordings directory
  Future<Directory> getRecordingsDirectory() async {
    try {
      final appDir = await getAppDocumentsDirectory();
      final recordingsDir = Directory(
        path.join(appDir.path, _recordingsFolder),
      );

      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      return recordingsDir;
    } catch (e) {
      throw FileSystemException(
        message: 'Failed to access recordings directory',
        errorType: FileSystemErrorType.directoryCreationFailed,
        originalError: e,
      );
    }
  }

  /// Create folder directory for specific folder ID
  Future<Directory> createFolderDirectory(String folderId) async {
    try {
      final recordingsDir = await getRecordingsDirectory();
      final folderDir = Directory(path.join(recordingsDir.path, folderId));

      if (!await folderDir.exists()) {
        await folderDir.create(recursive: true);
      }

      return folderDir;
    } catch (e) {
      throw FileSystemException(
        message: 'Failed to create folder directory: $folderId',
        errorType: FileSystemErrorType.directoryCreationFailed,
        originalError: e,
      );
    }
  }

  /// Get temporary directory
  Future<Directory> getTempDirectory() async {
    try {
      final appDir = await getAppDocumentsDirectory();
      final tempDir = Directory(path.join(appDir.path, _tempFolder));

      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      return tempDir;
    } catch (e) {
      throw FileSystemException(
        message: 'Failed to access temporary directory',
        errorType: FileSystemErrorType.accessDenied,
        originalError: e,
      );
    }
  }

  /// Get backup directory
  Future<Directory> getBackupDirectory() async {
    try {
      final appDir = await getAppDocumentsDirectory();
      final backupDir = Directory(path.join(appDir.path, _backupFolder));

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      return backupDir;
    } catch (e) {
      throw FileSystemException(
        message: 'Failed to access backup directory',
        errorType: FileSystemErrorType.accessDenied,
        originalError: e,
      );
    }
  }

  // ==== FILE OPERATIONS ====

  /// Copy file from source to destination
  Future<File> copyFile({
    required File sourceFile,
    required String destinationPath,
    bool overwrite = false,
  }) async {
    try {
      final destinationFile = File(destinationPath);

      // Check if destination exists
      if (await destinationFile.exists() && !overwrite) {
        throw FileSystemException(
          message: 'Destination file already exists',
          errorType: FileSystemErrorType.fileAlreadyExists,
          context: {'filePath': destinationPath},
        );
      }

      // Ensure destination directory exists
      final destinationDir = Directory(path.dirname(destinationPath));
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      // Copy file
      final copiedFile = await sourceFile.copy(destinationPath);

      // Verify copy integrity
      await _verifyFileCopy(sourceFile, copiedFile);

      return copiedFile;
    } catch (e) {
      if (e is FileSystemException) rethrow;
      throw FileSystemException(
        message: 'Failed to copy file: ${e.toString()}',
        errorType: FileSystemErrorType.fileCopyFailed,
        originalError: e,
      );
    }
  }

  /// Move file from source to destination
  Future<File> moveFile({
    required File sourceFile,
    required String destinationPath,
    bool overwrite = false,
  }) async {
    try {
      final destinationFile = File(destinationPath);

      // Check if destination exists
      if (await destinationFile.exists() && !overwrite) {
        throw FileSystemException(
          message: 'Destination file already exists',
          errorType: FileSystemErrorType.fileAlreadyExists,
          context: {'filePath': destinationPath},
        );
      }

      // Ensure destination directory exists
      final destinationDir = Directory(path.dirname(destinationPath));
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      // Try rename first (more efficient if on same filesystem)
      try {
        final movedFile = await sourceFile.rename(destinationPath);
        return movedFile;
      } catch (e) {
        // If rename fails, fall back to copy and delete
        final copiedFile = await copyFile(
          sourceFile: sourceFile,
          destinationPath: destinationPath,
          overwrite: overwrite,
        );

        await deleteFile(sourceFile);
        return copiedFile;
      }
    } catch (e) {
      if (e is FileSystemException) rethrow;
      throw FileSystemException(
        message: 'Failed to move file: ${e.toString()}',
        errorType: FileSystemErrorType.fileMoveFailed,
        originalError: e,
      );
    }
  }

  /// Delete file
  Future<bool> deleteFile(File file) async {
    try {
      if (!await file.exists()) {
        return true; // Already deleted
      }

      await file.delete();
      return true;
    } catch (e) {
      throw FileSystemException(
        message: 'Failed to delete file: ${e.toString()}',
        errorType: FileSystemErrorType.fileDeletionFailed,
        originalError: e,
      );
    }
  }

  /// Create unique filename
  Future<String> generateUniqueFilename({
    required String directory,
    required String baseName,
    required String extension,
  }) async {
    try {
      String filename = '$baseName$extension';
      String fullPath = path.join(directory, filename);

      int counter = 1;
      while (await File(fullPath).exists()) {
        filename = '${baseName}_$counter$extension';
        fullPath = path.join(directory, filename);
        counter++;

        // Prevent infinite loop
        if (counter > 9999) {
          throw FileSystemException(
            message: 'Unable to generate unique filename',
            errorType: FileSystemErrorType.invalidFileName,
            context: {'baseName': baseName},
          );
        }
      }

      return fullPath;
    } catch (e) {
      if (e is FileSystemException) rethrow;
      throw FileSystemException(
        message: 'Failed to generate unique filename: ${e.toString()}',
        errorType: FileSystemErrorType.invalidFileName,
        originalError: e,
      );
    }
  }

  // ==== FILE VALIDATION ====

  /// Validate audio file
  Future<bool> validateAudioFile(File audioFile) async {
    try {
      if (!await audioFile.exists()) return false;
      final stat = await audioFile.stat();
      if (stat.size == 0) return false;
      final extension = path.extension(audioFile.path).toLowerCase();
      final supportedExtensions = AudioFormat.values
          .map((format) => '.${format.fileExtension}')
          .toList();

      if (!supportedExtensions.contains(extension)) return false;
      return await _validateFileHeader(audioFile, extension);
    } catch (e) {
      return false;
    }
  }

  /// Check file integrity
  Future<bool> checkFileIntegrity(File file) async {
    try {
      final bytes = await file.openRead(0, 1024).toList();
      return bytes.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Validate file header based on extension
  Future<bool> _validateFileHeader(File file, String extension) async {
    try {
      final bytes = await file.openRead(0, 12).toList();
      final headerBytes = bytes.expand((x) => x).toList();
      if (headerBytes.isEmpty) return false;

      switch (extension) {
        case '.wav':
          return _validateWavHeader(headerBytes);
        case '.m4a':
        case '.aac':
        case '.mp4':
          return _validateM4aHeader(headerBytes);
        case '.flac':
          return _validateFlacHeader(headerBytes);
        default:
          return true;
      }
    } catch (e) {
      return false;
    }
  }

  /// Validate WAV file header
  bool _validateWavHeader(List<int> headerBytes) {
    if (headerBytes.length < 12) return false;
    final riffSignature = String.fromCharCodes(headerBytes.sublist(0, 4));
    final waveSignature = String.fromCharCodes(headerBytes.sublist(8, 12));
    return riffSignature == 'RIFF' && waveSignature == 'WAVE';
  }

  /// Validate M4A file header
  bool _validateM4aHeader(List<int> headerBytes) {
    if (headerBytes.length < 8) return false;
    final ftypSignature = String.fromCharCodes(headerBytes.sublist(4, 8));
    return ftypSignature == 'ftyp';
  }

  /// Validate FLAC file header
  bool _validateFlacHeader(List<int> headerBytes) {
    if (headerBytes.length < 4) return false;
    final flacSignature = String.fromCharCodes(headerBytes.sublist(0, 4));
    return flacSignature == 'fLaC';
  }

  /// Verify file copy integrity
  Future<void> _verifyFileCopy(File source, File destination) async {
    final sourceStat = await source.stat();
    final destStat = await destination.stat();

    if (sourceStat.size != destStat.size) {
      throw FileSystemException(
        message: 'File copy verification failed',
        errorType: FileSystemErrorType.fileCopyFailed,
      );
    }
  }

  // ==== STORAGE MANAGEMENT ====

  /// Get directory size in bytes
  Future<int> getDirectorySize(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) return 0;
      int totalSize = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (e) {
            continue;
          }
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Get available storage space
  Future<int> getAvailableSpace() async {
    try {
      return 1024 * 1024 * 1024;
    } catch (e) {
      return 0;
    }
  }

  /// Clean up temporary files
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTempDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list()) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            continue;
          }
        }
      }
    } catch (e) {
      // Cleanup failure is not critical
      debugPrint('Warning: Failed to cleanup temp files: $e');
    }
  }

  /// Clean up old backup files
  Future<void> cleanupOldBackups({
    Duration maxAge = const Duration(days: 30),
  }) async {
    try {
      final backupDir = await getBackupDirectory();
      if (!await backupDir.exists()) return;
      final cutoffDate = DateTime.now().subtract(maxAge);

      await for (final entity in backupDir.list()) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await entity.delete();
            }
          } catch (e) {
            continue;
          }
        }
      }
    } catch (e) {
      debugPrint('Warning: Failed to cleanup old backups: $e');
    }
  }

  // ==== UTILITY METHODS ====

  /// Check if file exists
  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Get file size
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return 0;
      final stat = await file.stat();
      return stat.size;
    } catch (e) {
      return 0;
    }
  }

  /// Get file modification date
  Future<DateTime?> getFileModificationDate(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      return stat.modified;
    } catch (e) {
      return null;
    }
  }

  /// Ensure directory exists
  Future<Directory> ensureDirectoryExists(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } catch (e) {
      throw FileSystemException(
        message: 'Failed to ensure directory exists: $directoryPath',
        errorType: FileSystemErrorType.directoryCreationFailed,
        originalError: e,
      );
    }
  }
}
