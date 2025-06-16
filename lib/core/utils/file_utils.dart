// File: core/utils/file_utils.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../enums/audio_format.dart';
import '../constants/app_constants.dart';
import 'date_formatter.dart';

/// Utility class for file system operations
///
/// Handles file management, path operations, and storage utilities
/// for the voice memo application.
class FileUtils {

  // ==== DIRECTORY MANAGEMENT ====

  /// Get application documents directory
  static Future<Directory> getAppDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get recordings directory
  static Future<Directory> getRecordingsDirectory() async {
    final appDir = await getAppDocumentsDirectory();
    final recordingsDir = Directory(path.join(appDir.path, AppConstants.recordingsDirectory));

    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    return recordingsDir;
  }

  /// Get folder-specific recordings directory
  static Future<Directory> getFolderDirectory(String folderId) async {
    final recordingsDir = await getRecordingsDirectory();
    final folderDir = Directory(path.join(recordingsDir.path, folderId));

    if (!await folderDir.exists()) {
      await folderDir.create(recursive: true);
    }

    return folderDir;
  }

  /// Get temp directory for processing
  static Future<Directory> getTempDirectory() async {
    final appDir = await getAppDocumentsDirectory();
    final tempDir = Directory(path.join(appDir.path, AppConstants.tempDirectory));

    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    return tempDir;
  }

  /// Get backups directory
  static Future<Directory> getBackupDirectory() async {
    final appDir = await getAppDocumentsDirectory();
    final backupDir = Directory(path.join(appDir.path, AppConstants.backupDirectory));

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    return backupDir;
  }

  // ==== FILE PATH OPERATIONS ====

  /// Generate unique file path for recording
  static Future<String> generateRecordingPath(String folderId, AudioFormat format) async {
    final folderDir = await getFolderDirectory(folderId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'recording_${timestamp}${format.fileExtension}';

    return path.join(folderDir.path, fileName);
  }

  /// Generate file path with custom name
  static Future<String> generateCustomRecordingPath(
      String folderId,
      String recordingName,
      AudioFormat format,
      ) async {
    final folderDir = await getFolderDirectory(folderId);
    final safeName = AppConstants.getSafeFileName(recordingName);
    final fileName = '${safeName}${format.fileExtension}';

    // Ensure unique filename
    String finalPath = path.join(folderDir.path, fileName);
    int counter = 1;

    while (await File(finalPath).exists()) {
      final nameWithoutExt = path.basenameWithoutExtension(fileName);
      final ext = path.extension(fileName);
      finalPath = path.join(folderDir.path, '${nameWithoutExt}_$counter$ext');
      counter++;
    }

    return finalPath;
  }

  /// Get relative path from app documents
  static Future<String> getRelativePath(String absolutePath) async {
    final appDir = await getAppDocumentsDirectory();
    return path.relative(absolutePath, from: appDir.path);
  }

  /// Get absolute path from relative path
  static Future<String> getAbsolutePath(String relativePath) async {
    final appDir = await getAppDocumentsDirectory();
    return path.join(appDir.path, relativePath);
  }

  // ==== FILE OPERATIONS ====

  /// Check if file exists
  static Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get file size in bytes
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
    }
  }

  /// Copy file to new location
  static Future<bool> copyFile(String sourcePath, String destinationPath) async {
    try {
      final sourceFile = File(sourcePath);
      final destFile = File(destinationPath);

      if (!await sourceFile.exists()) {
        return false;
      }

      // Create destination directory if needed
      await destFile.parent.create(recursive: true);

      await sourceFile.copy(destinationPath);
      return true;
    } catch (e) {
      print('❌ Error copying file: $e');
      return false;
    }
  }

  /// Move file to new location
  static Future<bool> moveFile(String sourcePath, String destinationPath) async {
    try {
      final sourceFile = File(sourcePath);
      final destFile = File(destinationPath);

      if (!await sourceFile.exists()) {
        return false;
      }

      // Create destination directory if needed
      await destFile.parent.create(recursive: true);

      await sourceFile.rename(destinationPath);
      return true;
    } catch (e) {
      print('❌ Error moving file: $e');
      return false;
    }
  }

  /// Delete file
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting file: $e');
      return false;
    }
  }

  /// Read file as bytes
  static Future<Uint8List?> readFileAsBytes(String filePath) async {
    try {
      final file = File(filePath);

      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      print('❌ Error reading file as bytes: $e');
      return null;
    }
  }

  /// Write bytes to file
  static Future<bool> writeBytesToFile(String filePath, Uint8List bytes) async {
    try {
      final file = File(filePath);

      // Create directory if needed
      await file.parent.create(recursive: true);

      await file.writeAsBytes(bytes);
      return true;
    } catch (e) {
      print('❌ Error writing bytes to file: $e');
      return false;
    }
  }

  // ==== DIRECTORY OPERATIONS ====

  /// Get all files in directory
  static Future<List<File>> getFilesInDirectory(
      String directoryPath, {
        String? extension,
        bool recursive = false,
      }) async {
    try {
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        return [];
      }

      final List<File> files = [];

      await for (final entity in directory.list(recursive: recursive)) {
        if (entity is File) {
          if (extension == null || entity.path.endsWith(extension)) {
            files.add(entity);
          }
        }
      }

      return files;
    } catch (e) {
      print('❌ Error getting files in directory: $e');
      return [];
    }
  }

  /// Get directory size
  static Future<int> getDirectorySize(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        return 0;
      }

      int totalSize = 0;

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      print('❌ Error getting directory size: $e');
      return 0;
    }
  }

  /// Clean directory (delete all files)
  static Future<bool> cleanDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        return true;
      }

      await for (final entity in directory.list()) {
        await entity.delete(recursive: true);
      }

      return true;
    } catch (e) {
      print('❌ Error cleaning directory: $e');
      return false;
    }
  }

  /// Delete directory and all contents
  static Future<bool> deleteDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);

      if (await directory.exists()) {
        await directory.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting directory: $e');
      return false;
    }
  }

  // ==== STORAGE ANALYSIS ====

  /// Get total storage usage by app
  static Future<int> getTotalAppStorageUsage() async {
    final appDir = await getAppDocumentsDirectory();
    return await getDirectorySize(appDir.path);
  }

  /// Get storage usage by recordings
  static Future<int> getRecordingsStorageUsage() async {
    final recordingsDir = await getRecordingsDirectory();
    return await getDirectorySize(recordingsDir.path);
  }

  /// Get storage usage by folder
  static Future<Map<String, int>> getStorageUsageByFolder() async {
    final Map<String, int> usage = {};

    try {
      final recordingsDir = await getRecordingsDirectory();

      await for (final entity in recordingsDir.list()) {
        if (entity is Directory) {
          final folderId = path.basename(entity.path);
          usage[folderId] = await getDirectorySize(entity.path);
        }
      }
    } catch (e) {
      print('❌ Error getting storage usage by folder: $e');
    }

    return usage;
  }

  /// Get available storage space
  static Future<int> getAvailableStorage() async {
    try {
      final appDir = await getAppDocumentsDirectory();
      final stat = await appDir.stat();

      // This is a simplified approach - in real implementation,
      // you'd need platform-specific code to get actual free space
      return 1024 * 1024 * 1024; // Return 1GB as placeholder
    } catch (e) {
      print('❌ Error getting available storage: $e');
      return 0;
    }
  }

  // ==== FILE VALIDATION ====

  /// Validate file name
  static bool isValidFileName(String fileName) {
    if (fileName.isEmpty || fileName.length > AppConstants.maxFileNameLength) {
      return false;
    }

    return !AppConstants.invalidFileNameChars.any(
          (char) => fileName.contains(char),
    );
  }

  /// Get file extension from path
  static String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  /// Check if file is audio format
  static bool isAudioFile(String filePath) {
    final extension = getFileExtension(filePath);
    return AudioFormat.values.any((format) => format.fileExtension == extension);
  }

  /// Get audio format from file path
  static AudioFormat? getAudioFormatFromPath(String filePath) {
    final extension = getFileExtension(filePath);

    for (final format in AudioFormat.values) {
      if (format.fileExtension == extension) {
        return format;
      }
    }

    return null;
  }

  // ==== BACKUP OPERATIONS ====

  /// Create backup file
  static Future<String?> createBackup(String backupName) async {
    try {
      final backupDir = await getBackupDirectory();
      final timestamp = DateTime.now();
      final fileName = '${backupName}_${DateFormatter.formatForExport(timestamp)}${AppConstants.backupFileExtension}';
      final backupPath = path.join(backupDir.path, fileName);

      // In a real implementation, you'd compress the recordings directory
      // For now, just create an empty file as placeholder
      final backupFile = File(backupPath);
      await backupFile.writeAsString('Backup created at ${timestamp.toIso8601String()}');

      return backupPath;
    } catch (e) {
      print('❌ Error creating backup: $e');
      return null;
    }
  }

  /// Clean old backup files
  static Future<int> cleanOldBackups() async {
    try {
      final backupDir = await getBackupDirectory();
      final backupFiles = await getFilesInDirectory(
        backupDir.path,
        extension: AppConstants.backupFileExtension,
      );

      // Sort by modification date
      backupFiles.sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // Keep only the most recent backup files
      int deletedCount = 0;

      for (int i = AppConstants.maxBackupFiles; i < backupFiles.length; i++) {
        await backupFiles[i].delete();
        deletedCount++;
      }

      return deletedCount;
    } catch (e) {
      print('❌ Error cleaning old backups: $e');
      return 0;
    }
  }

  // ==== HELPER METHODS ====

  /// Generate unique filename in directory
  static Future<String> generateUniqueFileName(
      String directoryPath,
      String baseName,
      String extension,
      ) async {
    String fileName = '$baseName$extension';
    String finalPath = path.join(directoryPath, fileName);
    int counter = 1;

    while (await File(finalPath).exists()) {
      fileName = '${baseName}_$counter$extension';
      finalPath = path.join(directoryPath, fileName);
      counter++;
    }

    return finalPath;
  }

  /// Extract file name without extension
  static String getFileNameWithoutExtension(String filePath) {
    return path.basenameWithoutExtension(filePath);
  }

  /// Get parent directory path
  static String getParentDirectory(String filePath) {
    return path.dirname(filePath);
  }
}