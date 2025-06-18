// File: core/errors/failure_types/data_failures.dart
import 'package:equatable/equatable.dart';
import '../failures.dart';
import '../exceptions.dart';

// ==== FILE SYSTEM FAILURES ====

/// Failure in file system operations
class FileSystemFailure extends Failure {
  final FileSystemErrorType errorType;

  const FileSystemFailure({
    required String message,
    required this.errorType,
    String? code,
    FailureSeverity severity = FailureSeverity.error,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    severity: severity,
    context: context,
  );

  /// Create failure from exception
  factory FileSystemFailure.fromException(FileSystemException exception) {
    return FileSystemFailure(
      message: exception.userMessage,
      errorType: exception.errorType,
      code: exception.code,
      context: exception.context,
    );
  }

  /// Create failure for file not found
  factory FileSystemFailure.fileNotFound(String filePath) {
    return FileSystemFailure(
      message: 'File not found: $filePath',
      errorType: FileSystemErrorType.fileNotFound,
      code: 'FILE_NOT_FOUND',
      context: {'filePath': filePath},
    );
  }

  /// Create failure for access denied
  factory FileSystemFailure.accessDenied(String path) {
    return FileSystemFailure(
      message: 'Access denied to: $path',
      errorType: FileSystemErrorType.accessDenied,
      code: 'ACCESS_DENIED',
      context: {'path': path},
    );
  }

  /// Create failure for insufficient storage
  factory FileSystemFailure.insufficientStorage() {
    return const FileSystemFailure(
      message: 'Not enough storage space available',
      errorType: FileSystemErrorType.insufficientStorage,
      code: 'INSUFFICIENT_STORAGE',
    );
  }

  /// Create failure for invalid file name
  factory FileSystemFailure.invalidFileName(String fileName) {
    return FileSystemFailure(
      message: 'Invalid file name: $fileName',
      errorType: FileSystemErrorType.invalidFileName,
      code: 'INVALID_FILE_NAME',
      context: {'fileName': fileName},
    );
  }

  /// Create failure for file already exists
  factory FileSystemFailure.fileAlreadyExists(String filePath) {
    return FileSystemFailure(
      message: 'File already exists: $filePath',
      errorType: FileSystemErrorType.fileAlreadyExists,
      code: 'FILE_ALREADY_EXISTS',
      context: {'filePath': filePath},
    );
  }

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

  @override
  List<Object?> get props => [...super.props, errorType];
}

// ==== DATABASE FAILURES ====

/// Failure in database operations
class DatabaseFailure extends Failure {
  final DatabaseErrorType errorType;

  const DatabaseFailure({
    required String message,
    required this.errorType,
    String? code,
    FailureSeverity severity = FailureSeverity.error,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    severity: severity,
    context: context,
  );

  /// Create failure from exception
  factory DatabaseFailure.fromException(DatabaseException exception) {
    return DatabaseFailure(
      message: exception.userMessage,
      errorType: exception.errorType,
      code: exception.code,
      severity: exception.isCritical ? FailureSeverity.critical : FailureSeverity.error,
      context: exception.context,
    );
  }

  /// Create failure for initialization failed
  factory DatabaseFailure.initializationFailed([String? reason]) {
    return DatabaseFailure(
      message: reason ?? 'Database initialization failed',
      errorType: DatabaseErrorType.initializationFailed,
      code: 'DB_INIT_FAILED',
      severity: FailureSeverity.critical,
    );
  }

  /// Create failure for query failed
  factory DatabaseFailure.queryFailed(String query, [String? reason]) {
    return DatabaseFailure(
      message: reason ?? 'Database query failed',
      errorType: DatabaseErrorType.queryFailed,
      code: 'QUERY_FAILED',
      context: {'query': query},
    );
  }

  /// Create failure for insert failed
  factory DatabaseFailure.insertFailed(String table, [Map<String, dynamic>? data]) {
    return DatabaseFailure(
      message: 'Failed to insert data into $table',
      errorType: DatabaseErrorType.insertFailed,
      code: 'INSERT_FAILED',
      context: {'table': table, if (data != null) 'data': data},
    );
  }

  /// Create failure for update failed
  factory DatabaseFailure.updateFailed(String table, [Map<String, dynamic>? data]) {
    return DatabaseFailure(
      message: 'Failed to update data in $table',
      errorType: DatabaseErrorType.updateFailed,
      code: 'UPDATE_FAILED',
      context: {'table': table, if (data != null) 'data': data},
    );
  }

  /// Create failure for delete failed
  factory DatabaseFailure.deleteFailed(String table, [String? identifier]) {
    return DatabaseFailure(
      message: 'Failed to delete data from $table',
      errorType: DatabaseErrorType.deleteFailed,
      code: 'DELETE_FAILED',
      context: {'table': table, if (identifier != null) 'id': identifier},
    );
  }

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

  @override
  List<Object?> get props => [...super.props, errorType];
}

// ==== VALIDATION FAILURES ====

/// Failure in validation operations
class ValidationFailure extends Failure {
  final ValidationErrorType errorType;
  final String field;

  const ValidationFailure({
    required String message,
    required this.errorType,
    required this.field,
    String? code,
    FailureSeverity severity = FailureSeverity.warning,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    severity: severity,
    context: context,
  );

  /// Create failure from exception
  factory ValidationFailure.fromException(ValidationException exception) {
    return ValidationFailure(
      message: exception.userMessage,
      errorType: exception.errorType,
      field: exception.field,
      code: exception.code,
      context: exception.context,
    );
  }

  /// Create failure for required field
  factory ValidationFailure.required(String field) {
    return ValidationFailure(
      message: '$field is required',
      errorType: ValidationErrorType.required,
      field: field,
      code: 'FIELD_REQUIRED',
    );
  }

  /// Create failure for invalid format
  factory ValidationFailure.invalidFormat(String field, [String? expectedFormat]) {
    return ValidationFailure(
      message: expectedFormat != null
          ? '$field must be in format: $expectedFormat'
          : '$field has invalid format',
      errorType: ValidationErrorType.invalidFormat,
      field: field,
      code: 'INVALID_FORMAT',
      context: {'expectedFormat': expectedFormat},
    );
  }

  /// Create failure for too short
  factory ValidationFailure.tooShort(String field, int minLength) {
    return ValidationFailure(
      message: '$field must be at least $minLength characters',
      errorType: ValidationErrorType.tooShort,
      field: field,
      code: 'TOO_SHORT',
      context: {'minLength': minLength},
    );
  }

  /// Create failure for too long
  factory ValidationFailure.tooLong(String field, int maxLength) {
    return ValidationFailure(
      message: '$field must be no more than $maxLength characters',
      errorType: ValidationErrorType.tooLong,
      field: field,
      code: 'TOO_LONG',
      context: {'maxLength': maxLength},
    );
  }

  /// Create failure for duplicate value
  factory ValidationFailure.duplicate(String field, String value) {
    return ValidationFailure(
      message: '$field "$value" already exists',
      errorType: ValidationErrorType.duplicateValue,
      field: field,
      code: 'DUPLICATE_VALUE',
      context: {'value': value},
    );
  }

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

  @override
  List<Object?> get props => [...super.props, errorType, field];
}