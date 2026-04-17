// File: core/errors/failure_utils.dart
import 'package:flutter/foundation.dart'; // Per debugPrint
import 'package:dartz/dartz.dart';

import 'package:wavnote/core/errors/failures.dart';
import 'package:wavnote/core/errors/exceptions.dart';
import 'package:wavnote/core/errors/failure_types/audio_failures.dart';
import 'package:wavnote/core/errors/failure_types/data_failures.dart';
import 'package:wavnote/core/errors/failure_types/system_failures.dart';

/// Utility functions for error handling and Failure conversion.
class FailureUtils {
  // Private constructor to prevent instantiation
  FailureUtils._();

  /// Converts an Exception to a specific Failure type.
  /// This is the primary mapping function to be used in data/service layers.
  static Failure convertExceptionToFailure(
    Object e, {
    String? contextMessage,
    FailureSeverity severity = FailureSeverity.error,
  }) {
    debugPrint(
      '⚠️ Converting Exception to Failure: $e${contextMessage != null ? ' - $contextMessage' : ''}',
    );

    if (e is AudioRecordingException) {
      return AudioRecordingFailure.fromException(e);
    } else if (e is AudioPlaybackException) {
      return AudioPlaybackFailure.fromException(e);
    } else if (e is FileSystemException) {
      return FileSystemFailure.fromException(e);
    } else if (e is DatabaseException) {
      return DatabaseFailure.fromException(e);
    } else if (e is PermissionException) {
      return PermissionFailure.fromException(e);
    } else if (e is NetworkException) {
      return NetworkFailure.fromException(e);
    } else if (e is ValidationException) {
      return ValidationFailure.fromException(e);
    } else if (e is ArgumentError) {
      return UnexpectedFailure(
        message: 'Invalid argument: ${e.message}',
        code: 'INVALID_ARGUMENT',
      );
    } else if (e is StateError) {
      return UnexpectedFailure(
        message: 'Invalid state: ${e.message}',
        code: 'INVALID_STATE',
      );
    }

    // Fallback generico per eccezioni non riconosciute
    return UnexpectedFailure(
      message:
          contextMessage ?? 'An unexpected error occurred: ${e.toString()}',
      code: 'UNEXPECTED_EXCEPTION',
    );
  }

  /// Returns a user-friendly message for a given Failure.
  static String getUserErrorMessage(Failure failure) {
    return failure.userMessage;
  }

  /// Logs a Failure, including its severity and context.
  static void logFailure(Failure failure) {
    if (failure.shouldLog) {
      debugPrint(
        '🔴 FAILURE LOG: Type: ${failure.runtimeType}, Message: ${failure.message}, ' +
            'Code: ${failure.code ?? 'N/A'}, Severity: ${failure.severity}, ' +
            'Context: ${failure.context ?? 'N/A'}',
      );
    }
  }

  /// Creates an Either<Failure, Unit> from a given Failure.
  static Either<Failure, Unit> leftUnit(Failure failure) {
    return Left(failure);
  }

  /// Creates an Either<Failure, Unit> for a successful operation.
  static Either<Failure, Unit> rightUnit() {
    return const Right(unit);
  }
}
