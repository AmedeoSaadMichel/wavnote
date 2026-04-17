// File: lib/services/audio/audio_preparation_result.dart
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart'; // Assicurati che questo path sia corretto

class AudioPreparationResult {
  final Either<Failure, Duration> result;
  final String? preparedFilePath;

  const AudioPreparationResult({required this.result, this.preparedFilePath});

  bool get isSuccess => result.isRight();

  // Helper per estrarre la durata o 0
  Duration get duration => result.fold((l) => Duration.zero, (r) => r);

  // Helper per estrarre il messaggio di errore per la UI
  String? get errorMessage => result.fold((l) => l.message, (r) => null);
}
