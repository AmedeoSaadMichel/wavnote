// File: core/errors/failures.dart
//
// CONVENZIONE DI GESTIONE DEGLI ERRORI IN WAVNOTE
// ===============================================
//
// Questo file definisce la base per la gestione strutturata degli errori
// nell'applicazione WavNote, aderendo ai principi della Clean Architecture.
// L'obiettivo è separare le eccezioni tecniche/infrastrutturali (Eccezioni)
// dagli esiti applicativi (Failure) che vengono propagati attraverso i layer
// di dominio e presentazione.
//
// STRATO DI ASTRAZIONE:
// - Eccezioni (lib/core/errors/exceptions.dart): Rappresentano errori a basso livello
//   (es. I/O fallito, API HTTP non raggiungibile, errori di parsing).
//   Devono essere "catturate" nello strato di 'data' o 'services' (implementazioni
//   dei repository) e MAI propagate direttamente verso gli strati superiori.
//   Possono essere 'typed' per specificare la natura tecnica dell'errore.
//
// - Failure (lib/core/errors/failures.dart): Rappresentano esiti di operazioni
//   che il dominio o l'applicazione possono gestire o presentare all'utente.
//   Vengono create dai repository o dai servizi che catturano le eccezioni
//   e le traducono in un linguaggio di dominio più significativo.
//   Vengono propagate verso gli Use Case, i BLoC e i Coordinator UI
//   utilizzando il tipo `Either<Failure, T>` di `dartz`.
//
// REGOLE GENERALI:
// 1. SERVICES e DATA (implementazioni di repository):
//    - Possono lanciare `Exception` (preferibilmente typed da `exceptions.dart`).
//    - DEVONO catturare `Exception` (proprie o di librerie esterne).
//    - DEVONO convertire le `Exception` catturate in `Failure` (typed da `failure_types/`).
//    - DEVONO restituire `Future<Either<Failure, T>>` per le operazioni business.
//    - Possono restituire `Future<bool>` SOLO per check di stato puri (es. `fileExists`, `hasPermission`, `isInitialized`) che non rappresentano fallimenti di logica business.
//    - MAI propagare `Exception` generiche o di basso livello verso l'alto.
//
// 2. DOMAIN (interfacce repository e Use Cases):
//    - Le interfacce dei repository DEVONO esporre `Future<Either<Failure, T>>`.
//    - Gli Use Case DEVONO restituire `Either<Failure, T>`.
//    - MAI lanciare `Exception`.
//
// 3. PRESENTATION (BLoC e Coordinator UI):
//    - DEVONO consumare `Either<Failure, T>` usando il metodo `.fold()`.
//    - MAI lanciare `Exception` o `Failure` direttamente.
//    - DEVONO tradurre gli esiti `Left(Failure)` in stati UI appropriati.
//
// 4. WIDGETS:
//    - MAI fare `try/catch` di logica business o lanciare `Exception`/`Failure`.
//    - DEVONO leggere gli stati UI forniti dai BLoC/Coordinator.
//
// 5. Successo senza payload: Per operazioni che non restituiscono dati ma solo un successo,
//    si utilizzerà `Either<Failure, Unit>` (dove `Unit` proviene da `package:dartz/dartz.dart`).
//
// 6. Logging: I `Failure` DEVONO essere loggati una sola volta al punto di traduzione
//    dall'eccezione, o nel layer che li consuma se non c'è una traduzione diretta.
//
// Questa convenzione garantisce che gli errori siano gestiti in modo prevedibile,
// testabile e con messaggi chiari per l'utente, mantenendo una netta separazione
// delle responsabilità tra i layer.
import 'package:equatable/equatable.dart';
import 'package:dartz/dartz.dart'; // Importa dartz per Either e Unit

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
  error, // Standard errors
  warning, // Non-critical issues
  info, // Informational messages
}
