// File: config/dependency_injection.dart
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

import 'package:get_it/get_it.dart';

import '../data/repositories/recording_repository.dart';
import '../data/repositories/folder_repository.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/i_audio_service_repository.dart';
import '../domain/repositories/i_audio_trimmer_repository.dart';
import '../domain/repositories/i_folder_repository.dart';
import '../domain/repositories/i_location_repository.dart';
import '../domain/repositories/i_recording_repository.dart';
import '../domain/repositories/i_settings_repository.dart';
import '../services/audio/audio_service_coordinator.dart';
import '../services/audio/audio_trimmer_service.dart';
import '../services/location/geolocation_service.dart';

// Nuovi import per la riproduzione audio
import '../services/audio/i_audio_playback_engine.dart';
import '../services/audio/audio_playback_engine_impl.dart';
import '../services/audio/i_audio_preparation_service.dart';
import '../services/audio/audio_preparation_service.dart'; // Implementazione concreta
import '../services/audio/audio_cache_manager.dart'; // Cache Manager
import '../presentation/screens/recording/controllers/recording_playback_coordinator.dart';

/// Global service locator — use sl<T>() to resolve dependencies
final GetIt sl = GetIt.instance;

/// Register all app-wide singletons and initialize audio.
///
/// Must be called once in main(), after the database is open.
/// Safe to call multiple times (GetIt will not re-register).
Future<void> setupDependencies() async {
  // ── Services ──────────────────────────────────────────────
  if (!sl.isRegistered<IAudioServiceRepository>()) {
    sl.registerLazySingleton<IAudioServiceRepository>(
      () => AudioServiceCoordinator(),
    );
  }

  if (!sl.isRegistered<ILocationRepository>()) {
    sl.registerLazySingleton<ILocationRepository>(() => GeolocationService());
  }

  // Nuove registrazioni per il playback audio (Engine e PreparationService sono Singleton)
  if (!sl.isRegistered<IAudioPlaybackEngine>()) {
    sl.registerLazySingleton<IAudioPlaybackEngine>(
      () => AudioPlaybackEngineImpl(),
    );
  }

  if (!sl.isRegistered<AudioCacheManager>()) {
    sl.registerLazySingleton<AudioCacheManager>(() => AudioCacheManager());
  }

  if (!sl.isRegistered<IAudioPreparationService>()) {
    sl.registerLazySingleton<IAudioPreparationService>(
      () => AudioPreparationService(
        engine: sl<IAudioPlaybackEngine>(),
        cacheManager: sl<AudioCacheManager>(),
      ),
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
  // Inizializza i servizi audio singleton (Engine e PreparationService)
  final engineInitialized = await sl<IAudioPlaybackEngine>().initialize();
  if (!engineInitialized) {
    assert(false, 'AudioPlaybackEngine failed to initialize');
  }
  // Il PreparationService non necessita di una initialize esplicita al momento se è singleton.
  // sl<IAudioPreparationService>().initialize(); // Se avesse un metodo initialize

  // Il RecordingPlaybackCoordinator, essendo un factory, sarà inizializzato
  // dalla schermata che lo richiede.

  // TODO: Valutare la rimozione o la riorganizzazione di questa sezione
  // Inizializzazione del vecchio AudioServiceCoordinator, potrebbe non essere più necessario per il playback
  // final audioInitialized = await sl<IAudioServiceRepository>().initialize();
  // if (!audioInitialized) {
  //   // Non-fatal: app continues, recording will fail gracefully
  //   assert(false, 'AudioServiceCoordinator failed to initialize');
  // }
}
