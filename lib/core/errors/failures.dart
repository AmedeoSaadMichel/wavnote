// File: core/errors/failures.dart
import 'package:equatable/equatable.dart';
import 'failure_types/audio_failures.dart';
import 'failure_types/data_failures.dart';
import 'failure_types/system_failures.dart';
import 'failure_utils.dart';

// Export specific failure types for public API
export 'failure_types/audio_failures.dart';
export 'failure_types/data_failures.dart';
export 'failure_types/system_failures.dart';
export 'failure_utils.dart';

/// Base class for all failure types in the WavNote app
///
/// Failures represent the result of operations that can fail,
/// providing structured error information for the presentation layer.
/// This follows the Clean Architecture principle of separating
/// exceptions (infrastructure) from failures (domain/application).
abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final FailureSeverity severity;
  final Map<String, dynamic>? context;

  const Failure({
    required this.message,
    this.code,
    this.severity = FailureSeverity.error,
    this.context,
  });

  /// Get user-friendly error message
  String get userMessage => message;

  /// Check if this failure can be retried
  bool get isRetryable => false;

  /// Check if this failure should be logged
  bool get shouldLog => severity != FailureSeverity.info;

  /// Get failure icon for UI
  String get iconName {
    switch (severity) {
      case FailureSeverity.critical:
        return 'error';
      case FailureSeverity.error:
        return 'warning';
      case FailureSeverity.warning:
        return 'info';
      case FailureSeverity.info:
        return 'check';
    }
  }

  @override
  List<Object?> get props => [message, code, severity, context];

  @override
  String toString() => '$runtimeType: $message';
}

/// Severity levels for failures
enum FailureSeverity {
  critical, // App-breaking errors
  error,    // Standard errors
  warning,  // Non-critical issues
  info,     // Informational messages
}

