// File: core/errors/failure_utils.dart
import 'failures.dart';
import 'failure_types/audio_failures.dart';
import 'failure_types/data_failures.dart';
import 'failure_types/system_failures.dart';
import 'exceptions.dart';

// ==== UTILITY FUNCTIONS ====

/// Convert exception to appropriate failure
Failure convertExceptionToFailure(Exception exception) {
  if (exception is AudioRecordingException) {
    return AudioRecordingFailure.fromException(exception);
  } else if (exception is AudioPlaybackException) {
    return AudioPlaybackFailure.fromException(exception);
  } else if (exception is FileSystemException) {
    return FileSystemFailure.fromException(exception);
  } else if (exception is DatabaseException) {
    return DatabaseFailure.fromException(exception);
  } else if (exception is PermissionException) {
    return PermissionFailure.fromException(exception);
  } else if (exception is ValidationException) {
    return ValidationFailure.fromException(exception);
  } else if (exception is NetworkException) {
    return NetworkFailure.fromException(exception);
  } else {
    return UnexpectedFailure.fromException(exception);
  }
}

/// Create a failure with context
Failure createFailureWithContext({
  required String message,
  required String code,
  FailureSeverity severity = FailureSeverity.error,
  Map<String, dynamic>? context,
}) {
  return UnexpectedFailure(
    message: message,
    code: code,
    context: context,
  );
}

/// Create a success result
Success createSuccess({
  required String message,
  Map<String, dynamic>? context,
}) {
  return Success(
    message: message,
    context: context,
  );
}

/// Combine multiple failures into one
CombinedFailure combineFailures(List<Failure> failures, [String? message]) {
  return CombinedFailure(
    failures: failures,
    message: message,
  );
}

/// Check if a failure is retryable
bool isFailureRetryable(Failure failure) {
  return failure.isRetryable;
}

/// Get user-friendly message from failure
String getFailureMessage(Failure failure) {
  return failure.userMessage;
}

/// Check if failure should be logged
bool shouldLogFailure(Failure failure) {
  return failure.shouldLog;
}

/// Get failure severity level
FailureSeverity getFailureSeverity(Failure failure) {
  return failure.severity;
}

/// Check if failure is critical
bool isFailureCritical(Failure failure) {
  return failure.severity == FailureSeverity.critical;
}

/// Get failure context data
Map<String, dynamic>? getFailureContext(Failure failure) {
  return failure.context;
}

/// Create a cache failure
CacheFailure createCacheFailure({
  required String message,
  String? code,
  Map<String, dynamic>? context,
}) {
  return CacheFailure(
    message: message,
    code: code,
    context: context,
  );
}

/// Create an unexpected failure
UnexpectedFailure createUnexpectedFailure({
  required String message,
  String? code,
  Map<String, dynamic>? context,
}) {
  return UnexpectedFailure(
    message: message,
    code: code,
    context: context,
  );
}