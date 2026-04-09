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
  // Initialize the audio coordinator eagerly so it is ready
  // before the first BLoC is created. The guard inside
  // AudioServiceCoordinator.initialize() makes this idempotent.
  final audioInitialized = await sl<IAudioServiceRepository>().initialize();
  if (!audioInitialized) {
    // Non-fatal: app continues, recording will fail gracefully
    assert(false, 'AudioServiceCoordinator failed to initialize');
  }
}
