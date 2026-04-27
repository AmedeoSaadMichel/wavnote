// File: lib/config/dependency_injection.dart
//
// Dependency Injection - Config Layer
// ====================================
//
// Single source of truth for all service and repository registrations.
// Uses GetIt as the service locator — all singletons are registered here
// and nowhere else (never in main.dart or BLoC constructors).
//
// Initialization order:
// 1. Database must be open before calling setupDependencies()
// 2. Call setupDependencies() in main() after DatabaseHelper.database
// 3. Audio service is initialized here so BLoCs receive a ready instance
//
// Usage:
//   final audio = sl<AudioServiceCoordinator>();
//   final repo  = sl<RecordingRepository>();

import 'dart:io';
import 'package:get_it/get_it.dart';

import '../data/repositories/recording_repository.dart';
import '../data/repositories/folder_repository.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/i_audio_recording_repository.dart';
import '../domain/repositories/i_audio_trimmer_repository.dart';
import '../domain/repositories/i_folder_repository.dart';
import '../domain/repositories/i_location_repository.dart';
import '../domain/repositories/i_recording_repository.dart';
import '../domain/repositories/i_settings_repository.dart';
import '../services/audio/audio_recorder_service.dart';
import '../services/audio/audio_engine_service.dart';
import '../services/audio/audio_service_coordinator.dart';
import '../services/audio/recording_service_repository.dart';
import '../services/audio/audio_trimmer_service.dart';
import '../services/location/geolocation_service.dart';

// Nuovi import per la riproduzione audio
import '../services/audio/i_audio_playback_engine.dart';
import '../services/audio/audio_playback_engine_impl.dart';
import '../services/audio/audio_engine_playback_adapter.dart';
import '../services/audio/i_audio_preparation_service.dart';
import '../services/audio/audio_preparation_service.dart'; // Implementazione concreta
import '../presentation/screens/recording/controllers/recording_playback_coordinator.dart';

/// Global service locator — use `sl<T>()` to resolve dependencies
final GetIt sl = GetIt.instance;

/// Register all app-wide singletons and initialize audio.
///
/// Must be called once in main(), after the database is open.
/// Safe to call multiple times (GetIt will not re-register).
Future<void> setupDependencies() async {
  // ── Services ──────────────────────────────────────────────
  if (!sl.isRegistered<AudioRecorderService>()) {
    sl.registerLazySingleton<AudioRecorderService>(() => AudioRecorderService());
  }
  if (!sl.isRegistered<AudioEngineService>()) {
    sl.registerLazySingleton<AudioEngineService>(() => AudioEngineService());
  }

  if (!sl.isRegistered<ILocationRepository>()) {
    sl.registerLazySingleton<ILocationRepository>(() => GeolocationService());
  }

  // Nuove registrazioni per il playback audio (Engine e PreparationService sono Singleton)
  if (!sl.isRegistered<IAudioPlaybackEngine>()) {
    sl.registerLazySingleton<IAudioPlaybackEngine>(
      () => (Platform.isIOS || Platform.isMacOS)
          ? AudioEnginePlaybackAdapter(engineService: sl<AudioEngineService>())
          : AudioPlaybackEngineImpl(),
    );
  }

  if (!sl.isRegistered<AudioServiceCoordinator>()) {
    sl.registerLazySingleton<AudioServiceCoordinator>(
      () => AudioServiceCoordinator(
        engineService: sl<AudioEngineService>(),
      ),
    );
  }

  if (!sl.isRegistered<IAudioRecordingRepository>()) {
    sl.registerLazySingleton<IAudioRecordingRepository>(
      () => RecordingServiceRepository(
        coordinator: sl<AudioServiceCoordinator>(),
      ),
    );
  }

  if (!sl.isRegistered<IAudioPreparationService>()) {
    sl.registerLazySingleton<IAudioPreparationService>(
      () => AudioPreparationService(engine: sl<IAudioPlaybackEngine>()),
    );
  }

  // RecordingPlaybackCoordinator è ora un factory per istanze per ogni schermata.
  // Verrà creato e inizializzato dalla schermata stessa.
  if (!sl.isRegistered<RecordingPlaybackCoordinator>()) {
    sl.registerFactory<RecordingPlaybackCoordinator>(
      () => RecordingPlaybackCoordinator(
        engine: sl<IAudioPlaybackEngine>(),
        preparationService: sl<IAudioPreparationService>(),
      ),
    );
  }

  // ── Repositories ──────────────────────────────────────────
  if (!sl.isRegistered<IRecordingRepository>()) {
    sl.registerLazySingleton<IRecordingRepository>(() => RecordingRepository());
  }

  if (!sl.isRegistered<IFolderRepository>()) {
    sl.registerLazySingleton<IFolderRepository>(() => FolderRepository());
  }

  if (!sl.isRegistered<IAudioTrimmerRepository>()) {
    sl.registerLazySingleton<IAudioTrimmerRepository>(
      () => AudioTrimmerService(),
    );
  }

  if (!sl.isRegistered<ISettingsRepository>()) {
    sl.registerLazySingleton<ISettingsRepository>(
      () => SettingsRepositoryImpl(),
    );
  }

  // ── Audio initialization ───────────────────────────────────
  final audioInitialized = await sl<IAudioRecordingRepository>().initialize();
  if (!audioInitialized) {
    assert(false, 'AudioServiceCoordinator failed to initialize');
  }
}
