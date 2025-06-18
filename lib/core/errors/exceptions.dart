// File: core/errors/exceptions.dart

/// Base class for all custom exceptions in the WavNote app
///
/// Provides a consistent structure for exception handling across
/// the application with enhanced error information and context.
abstract class WavNoteException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;

  const WavNoteException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
    this.context,
  });

  @override
  String toString() {
    final buffer = StringBuffer('${runtimeType}: $message');
    if (code != null) buffer.write(' (Code: $code)');
    if (context?.isNotEmpty == true) {
      buffer.write(' Context: $context');
    }
    return buffer.toString();
  }

  /// Get user-friendly error message
  String get userMessage => message;

  /// Check if this is a critical error that should crash the app
  bool get isCritical => false;

  /// Check if this error can be retried
  bool get isRetryable => false;
}

// ==== AUDIO RECORDING EXCEPTIONS ====

/// Exception thrown when audio recording operations fail
class AudioRecordingException extends WavNoteException {
  final AudioRecordingErrorType errorType;

  const AudioRecordingException({
    required String message,
    required this.errorType,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
    stackTrace: stackTrace,
    context: context,
  );

  @override
  String get userMessage {
    switch (errorType) {
      case AudioRecordingErrorType.microphonePermissionDenied:
        return 'Microphone permission is required to record audio. Please enable it in Settings.';
      case AudioRecordingErrorType.microphoneUnavailable:
        return 'Microphone is not available. Please check if another app is using it.';
      case AudioRecordingErrorType.audioServiceInitializationFailed:
        return 'Failed to initialize audio recording. Please restart the app.';
      case AudioRecordingErrorType.recordingStartFailed:
        return 'Could not start recording. Please try again.';
      case AudioRecordingErrorType.recordingStopFailed:
        return 'Could not stop recording properly. Your recording may be incomplete.';
      case AudioRecordingErrorType.unsupportedAudioFormat:
        return 'The selected audio format is not supported on this device.';
      case AudioRecordingErrorType.insufficientStorage:
        return 'Not enough storage space to save the recording.';
      case AudioRecordingErrorType.audioDeviceError:
        return 'Audio device error occurred. Please check your microphone.';
      case AudioRecordingErrorType.recordingInterrupted:
        return 'Recording was interrupted. Your partial recording has been saved.';
    }
  }

  @override
  bool get isRetryable {
    switch (errorType) {
      case AudioRecordingErrorType.recordingStartFailed:
      case AudioRecordingErrorType.audioDeviceError:
      case AudioRecordingErrorType.recordingInterrupted:
        return true;
      default:
        return false;
    }
  }
}

/// Types of audio recording errors
enum AudioRecordingErrorType {
  microphonePermissionDenied,
  microphoneUnavailable,
  audioServiceInitializationFailed,
  recordingStartFailed,
  recordingStopFailed,
  unsupportedAudioFormat,
  insufficientStorage,
  audioDeviceError,
  recordingInterrupted,
}

// ==== AUDIO PLAYBACK EXCEPTIONS ====

/// Exception thrown when audio playback operations fail
class AudioPlaybackException extends WavNoteException {
  final AudioPlaybackErrorType errorType;

  const AudioPlaybackException({
    required String message,
    required this.errorType,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
    stackTrace: stackTrace,
    context: context,
  );

  @override
  String get userMessage {
    switch (errorType) {
      case AudioPlaybackErrorType.audioFileNotFound:
        return 'The audio file could not be found. It may have been deleted.';
      case AudioPlaybackErrorType.audioFileCorrupted:
        return 'The audio file appears to be corrupted and cannot be played.';
      case AudioPlaybackErrorType.unsupportedAudioFormat:
        return 'This audio format is not supported for playback.';
      case AudioPlaybackErrorType.playbackInitializationFailed:
        return 'Failed to initialize audio playback. Please try again.';
      case AudioPlaybackErrorType.playbackStartFailed:
        return 'Could not start playing the audio. Please try again.';
      case AudioPlaybackErrorType.audioServiceUnavailable:
        return 'Audio service is currently unavailable. Please restart the app.';
      case AudioPlaybackErrorType.audioDeviceError:
        return 'Audio device error occurred. Please check your speakers/headphones.';
      case AudioPlaybackErrorType.playbackInterrupted:
        return 'Playback was interrupted by another app or system event.';
    }
  }

  @override
  bool get isRetryable {
    switch (errorType) {
      case AudioPlaybackErrorType.playbackStartFailed:
      case AudioPlaybackErrorType.audioDeviceError:
      case AudioPlaybackErrorType.playbackInterrupted:
        return true;
      default:
        return false;
    }
  }
}

/// Types of audio playback errors
enum AudioPlaybackErrorType {
  audioFileNotFound,
  audioFileCorrupted,
  unsupportedAudioFormat,
  playbackInitializationFailed,
  playbackStartFailed,
  audioServiceUnavailable,
  audioDeviceError,
  playbackInterrupted,
}

// ==== FILE SYSTEM EXCEPTIONS ====

/// Exception thrown when file system operations fail
class FileSystemException extends WavNoteException {
  final FileSystemErrorType errorType;

  const FileSystemException({
    required String message,
    required this.errorType,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
    stackTrace: stackTrace,
    context: context,
  );

  @override
  String get userMessage {
    switch (errorType) {
      case FileSystemErrorType.fileNotFound:
        return 'The requested file could not be found.';
      case FileSystemErrorType.accessDenied:
        return 'Access to the file or directory was denied.';
      case FileSystemErrorType.insufficientStorage:
        return 'Not enough storage space available.';
      case FileSystemErrorType.fileAlreadyExists:
        return 'A file with this name already exists.';
      case FileSystemErrorType.invalidFileName:
        return 'The file name contains invalid characters.';
      case FileSystemErrorType.fileCorrupted:
        return 'The file appears to be corrupted.';
      case FileSystemErrorType.directoryCreationFailed:
        return 'Could not create the required directory.';
      case FileSystemErrorType.fileDeletionFailed:
        return 'Could not delete the file.';
      case FileSystemErrorType.fileMoveFailed:
        return 'Could not move the file to the new location.';
      case FileSystemErrorType.fileCopyFailed:
        return 'Could not copy the file.';
    }
  }

  @override
  bool get isRetryable {
    switch (errorType) {
      case FileSystemErrorType.fileDeletionFailed:
      case FileSystemErrorType.fileMoveFailed:
      case FileSystemErrorType.fileCopyFailed:
      case FileSystemErrorType.directoryCreationFailed:
        return true;
      default:
        return false;
    }
  }
}

/// Types of file system errors
enum FileSystemErrorType {
  fileNotFound,
  accessDenied,
  insufficientStorage,
  fileAlreadyExists,
  invalidFileName,
  fileCorrupted,
  directoryCreationFailed,
  fileDeletionFailed,
  fileMoveFailed,
  fileCopyFailed,
}

// ==== DATABASE EXCEPTIONS ====

/// Exception thrown when database operations fail
class DatabaseException extends WavNoteException {
  final DatabaseErrorType errorType;

  const DatabaseException({
    required String message,
    required this.errorType,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
    stackTrace: stackTrace,
    context: context,
  );

  @override
  String get userMessage {
    switch (errorType) {
      case DatabaseErrorType.initializationFailed:
        return 'Failed to initialize the app database. Please restart the app.';
      case DatabaseErrorType.connectionFailed:
        return 'Could not connect to the database.';
      case DatabaseErrorType.queryFailed:
        return 'Database query failed. Please try again.';
      case DatabaseErrorType.insertFailed:
        return 'Could not save data to the database.';
      case DatabaseErrorType.updateFailed:
        return 'Could not update data in the database.';
      case DatabaseErrorType.deleteFailed:
        return 'Could not delete data from the database.';
      case DatabaseErrorType.migrationFailed:
        return 'Database upgrade failed. Please contact support.';
      case DatabaseErrorType.corruptedDatabase:
        return 'The app database is corrupted. Please reinstall the app.';
      case DatabaseErrorType.constraintViolation:
        return 'Data validation failed. Please check your input.';
    }
  }

  @override
  bool get isCritical {
    switch (errorType) {
      case DatabaseErrorType.initializationFailed:
      case DatabaseErrorType.migrationFailed:
      case DatabaseErrorType.corruptedDatabase:
        return true;
      default:
        return false;
    }
  }

  @override
  bool get isRetryable {
    switch (errorType) {
      case DatabaseErrorType.queryFailed:
      case DatabaseErrorType.insertFailed:
      case DatabaseErrorType.updateFailed:
      case DatabaseErrorType.deleteFailed:
        return true;
      default:
        return false;
    }
  }
}

/// Types of database errors
enum DatabaseErrorType {
  initializationFailed,
  connectionFailed,
  queryFailed,
  insertFailed,
  updateFailed,
  deleteFailed,
  migrationFailed,
  corruptedDatabase,
  constraintViolation,
}

// ==== PERMISSION EXCEPTIONS ====

/// Exception thrown when permission-related operations fail
class PermissionException extends WavNoteException {
  final PermissionErrorType errorType;

  const PermissionException({
    required String message,
    required this.errorType,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
    stackTrace: stackTrace,
    context: context,
  );

  @override
  String get userMessage {
    switch (errorType) {
      case PermissionErrorType.microphonePermissionDenied:
        return 'Microphone permission is required to record audio. Please enable it in Settings.';
      case PermissionErrorType.storagePermissionDenied:
        return 'Storage permission is required to save recordings. Please enable it in Settings.';
      case PermissionErrorType.permissionPermanentlyDenied:
        return 'Permission was permanently denied. Please enable it manually in Settings.';
      case PermissionErrorType.permissionRequestFailed:
        return 'Failed to request permission. Please try again.';
    }
  }
}

/// Types of permission errors
enum PermissionErrorType {
  microphonePermissionDenied,
  storagePermissionDenied,
  permissionPermanentlyDenied,
  permissionRequestFailed,
}

// ==== VALIDATION EXCEPTIONS ====

/// Exception thrown when validation fails
class ValidationException extends WavNoteException {
  final ValidationErrorType errorType;
  final String field;

  const ValidationException({
    required String message,
    required this.errorType,
    required this.field,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
    stackTrace: stackTrace,
    context: context,
  );

  @override
  String get userMessage {
    switch (errorType) {
      case ValidationErrorType.required:
        return '$field is required.';
      case ValidationErrorType.invalidFormat:
        return '$field has an invalid format.';
      case ValidationErrorType.tooShort:
        return '$field is too short.';
      case ValidationErrorType.tooLong:
        return '$field is too long.';
      case ValidationErrorType.invalidCharacters:
        return '$field contains invalid characters.';
      case ValidationErrorType.duplicateValue:
        return '$field already exists.';
      case ValidationErrorType.outOfRange:
        return '$field value is out of valid range.';
    }
  }
}

/// Types of validation errors
enum ValidationErrorType {
  required,
  invalidFormat,
  tooShort,
  tooLong,
  invalidCharacters,
  duplicateValue,
  outOfRange,
}

// ==== NETWORK/SYNC EXCEPTIONS ====

/// Exception thrown when network or sync operations fail
class NetworkException extends WavNoteException {
  final NetworkErrorType errorType;

  const NetworkException({
    required String message,
    required this.errorType,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
    stackTrace: stackTrace,
    context: context,
  );

  @override
  String get userMessage {
    switch (errorType) {
      case NetworkErrorType.noConnection:
        return 'No internet connection available.';
      case NetworkErrorType.timeout:
        return 'The request timed out. Please try again.';
      case NetworkErrorType.serverError:
        return 'Server error occurred. Please try again later.';
      case NetworkErrorType.invalidResponse:
        return 'Received invalid response from server.';
      case NetworkErrorType.syncFailed:
        return 'Failed to sync data. Your changes are saved locally.';
    }
  }

  @override
  bool get isRetryable => true;
}

/// Types of network errors
enum NetworkErrorType {
  noConnection,
  timeout,
  serverError,
  invalidResponse,
  syncFailed,
}

// ==== HELPER FUNCTIONS ====

/// Create an AudioRecordingException for common scenarios
AudioRecordingException createAudioRecordingException({
  required AudioRecordingErrorType type,
  String? customMessage,
  dynamic originalError,
  StackTrace? stackTrace,
  Map<String, dynamic>? context,
}) {
  String message = customMessage ?? _getDefaultAudioRecordingMessage(type);

  return AudioRecordingException(
    message: message,
    errorType: type,
    originalError: originalError,
    stackTrace: stackTrace,
    context: context,
  );
}

/// Create an AudioPlaybackException for common scenarios
AudioPlaybackException createAudioPlaybackException({
  required AudioPlaybackErrorType type,
  String? customMessage,
  dynamic originalError,
  StackTrace? stackTrace,
  Map<String, dynamic>? context,
}) {
  String message = customMessage ?? _getDefaultAudioPlaybackMessage(type);

  return AudioPlaybackException(
    message: message,
    errorType: type,
    originalError: originalError,
    stackTrace: stackTrace,
    context: context,
  );
}

/// Create a FileSystemException for common scenarios
FileSystemException createFileSystemException({
  required FileSystemErrorType type,
  String? customMessage,
  String? filePath,
  dynamic originalError,
  StackTrace? stackTrace,
}) {
  String message = customMessage ?? _getDefaultFileSystemMessage(type);
  Map<String, dynamic>? context = filePath != null ? {'filePath': filePath} : null;

  return FileSystemException(
    message: message,
    errorType: type,
    originalError: originalError,
    stackTrace: stackTrace,
    context: context,
  );
}

// Private helper functions for default messages
String _getDefaultAudioRecordingMessage(AudioRecordingErrorType type) {
  switch (type) {
    case AudioRecordingErrorType.microphonePermissionDenied:
      return 'Microphone permission denied';
    case AudioRecordingErrorType.microphoneUnavailable:
      return 'Microphone unavailable';
    case AudioRecordingErrorType.audioServiceInitializationFailed:
      return 'Audio service initialization failed';
    case AudioRecordingErrorType.recordingStartFailed:
      return 'Recording start failed';
    case AudioRecordingErrorType.recordingStopFailed:
      return 'Recording stop failed';
    case AudioRecordingErrorType.unsupportedAudioFormat:
      return 'Unsupported audio format';
    case AudioRecordingErrorType.insufficientStorage:
      return 'Insufficient storage space';
    case AudioRecordingErrorType.audioDeviceError:
      return 'Audio device error';
    case AudioRecordingErrorType.recordingInterrupted:
      return 'Recording interrupted';
  }
}

String _getDefaultAudioPlaybackMessage(AudioPlaybackErrorType type) {
  switch (type) {
    case AudioPlaybackErrorType.audioFileNotFound:
      return 'Audio file not found';
    case AudioPlaybackErrorType.audioFileCorrupted:
      return 'Audio file corrupted';
    case AudioPlaybackErrorType.unsupportedAudioFormat:
      return 'Unsupported audio format';
    case AudioPlaybackErrorType.playbackInitializationFailed:
      return 'Playback initialization failed';
    case AudioPlaybackErrorType.playbackStartFailed:
      return 'Playback start failed';
    case AudioPlaybackErrorType.audioServiceUnavailable:
      return 'Audio service unavailable';
    case AudioPlaybackErrorType.audioDeviceError:
      return 'Audio device error';
    case AudioPlaybackErrorType.playbackInterrupted:
      return 'Playback interrupted';
  }
}

String _getDefaultFileSystemMessage(FileSystemErrorType type) {
  switch (type) {
    case FileSystemErrorType.fileNotFound:
      return 'File not found';
    case FileSystemErrorType.accessDenied:
      return 'Access denied';
    case FileSystemErrorType.insufficientStorage:
      return 'Insufficient storage';
    case FileSystemErrorType.fileAlreadyExists:
      return 'File already exists';
    case FileSystemErrorType.invalidFileName:
      return 'Invalid file name';
    case FileSystemErrorType.fileCorrupted:
      return 'File corrupted';
    case FileSystemErrorType.directoryCreationFailed:
      return 'Directory creation failed';
    case FileSystemErrorType.fileDeletionFailed:
      return 'File deletion failed';
    case FileSystemErrorType.fileMoveFailed:
      return 'File move failed';
    case FileSystemErrorType.fileCopyFailed:
      return 'File copy failed';
  }
}