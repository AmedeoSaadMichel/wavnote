// File: core/errors/failure_types/system_failures.dart
import 'package:equatable/equatable.dart';
import '../failures.dart';
import '../exceptions.dart';

// ==== PERMISSION FAILURES ====

/// Failure in permission operations
class PermissionFailure extends Failure {
  final PermissionErrorType errorType;

  const PermissionFailure({
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
  factory PermissionFailure.fromException(PermissionException exception) {
    return PermissionFailure(
      message: exception.userMessage,
      errorType: exception.errorType,
      code: exception.code,
      context: exception.context,
    );
  }

  /// Create failure for microphone permission denied
  factory PermissionFailure.microphonePermissionDenied() {
    return const PermissionFailure(
      message: 'Microphone permission denied',
      errorType: PermissionErrorType.microphonePermissionDenied,
      code: 'MICROPHONE_PERMISSION_DENIED',
    );
  }

  /// Create failure for storage permission denied
  factory PermissionFailure.storagePermissionDenied() {
    return const PermissionFailure(
      message: 'Storage permission denied',
      errorType: PermissionErrorType.storagePermissionDenied,
      code: 'STORAGE_PERMISSION_DENIED',
    );
  }

  /// Create failure for permanently denied permission
  factory PermissionFailure.permanentlyDenied(String permission) {
    return PermissionFailure(
      message: '$permission permission permanently denied',
      errorType: PermissionErrorType.permissionPermanentlyDenied,
      code: 'PERMISSION_PERMANENTLY_DENIED',
      context: {'permission': permission},
    );
  }

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

  @override
  List<Object?> get props => [...super.props, errorType];
}

// ==== NETWORK FAILURES ====

/// Failure in network operations
class NetworkFailure extends Failure {
  final NetworkErrorType errorType;

  const NetworkFailure({
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
  factory NetworkFailure.fromException(NetworkException exception) {
    return NetworkFailure(
      message: exception.userMessage,
      errorType: exception.errorType,
      code: exception.code,
      context: exception.context,
    );
  }

  /// Create failure for no connection
  factory NetworkFailure.noConnection() {
    return const NetworkFailure(
      message: 'No internet connection available',
      errorType: NetworkErrorType.noConnection,
      code: 'NO_CONNECTION',
    );
  }

  /// Create failure for timeout
  factory NetworkFailure.timeout() {
    return const NetworkFailure(
      message: 'Request timed out',
      errorType: NetworkErrorType.timeout,
      code: 'TIMEOUT',
    );
  }

  /// Create failure for server error
  factory NetworkFailure.serverError(int statusCode, [String? reason]) {
    return NetworkFailure(
      message: reason ?? 'Server error ($statusCode)',
      errorType: NetworkErrorType.serverError,
      code: 'SERVER_ERROR',
      context: {'statusCode': statusCode},
    );
  }

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

  @override
  List<Object?> get props => [...super.props, errorType];
}

// ==== GENERAL FAILURE TYPES ====

/// Generic failure for unknown or unexpected errors
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    required String message,
    String? code,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    severity: FailureSeverity.error,
    context: context,
  );

  /// Create failure from generic exception
  factory UnexpectedFailure.fromException(Exception exception) {
    return UnexpectedFailure(
      message: exception.toString(),
      code: 'UNEXPECTED_ERROR',
    );
  }

  @override
  String get userMessage => 'An unexpected error occurred. Please try again.';

  @override
  bool get isRetryable => true;
}

/// Cache failure for caching operations
class CacheFailure extends Failure {
  const CacheFailure({
    required String message,
    String? code,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    code: code,
    severity: FailureSeverity.warning,
    context: context,
  );

  @override
  String get userMessage => 'Cache operation failed. The app may run slower.';

  @override
  bool get isRetryable => true;
}

/// Combine multiple failures into a single failure
class CombinedFailure extends Failure {
  final List<Failure> failures;

  const CombinedFailure({
    required this.failures,
    String? message,
  }) : super(
    message: message ?? 'Multiple errors occurred',
    severity: FailureSeverity.error,
  );

  @override
  String get userMessage {
    if (failures.isEmpty) return 'No errors';
    if (failures.length == 1) return failures.first.userMessage;
    return 'Multiple errors occurred. Please check details.';
  }

  @override
  bool get isRetryable => failures.any((f) => f.isRetryable);

  @override
  List<Object?> get props => [...super.props, failures];
}

/// Success result (not a failure, but useful for consistent return types)
class Success extends Failure {
  const Success({
    required String message,
    Map<String, dynamic>? context,
  }) : super(
    message: message,
    severity: FailureSeverity.info,
    context: context,
  );

  @override
  String get userMessage => message;

  @override
  bool get shouldLog => false;
}