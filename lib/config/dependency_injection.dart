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
import '../services/audio/audio_service_coordinator.dart';
import '../services/location/geolocation_service.dart';

/// Global service locator — use sl<T>() to resolve dependencies
final GetIt sl = GetIt.instance;

/// Register all app-wide singletons and initialize audio.
///
/// Must be called once in main(), after the database is open.
/// Safe to call multiple times (GetIt will not re-register).
Future<void> setupDependencies() async {
  // ── Services ──────────────────────────────────────────────
  if (!sl.isRegistered<AudioServiceCoordinator>()) {
    sl.registerLazySingleton<AudioServiceCoordinator>(
      () => AudioServiceCoordinator(),
    );
  }

  if (!sl.isRegistered<GeolocationService>()) {
    sl.registerLazySingleton<GeolocationService>(
      () => GeolocationService(),
    );
  }

  // ── Repositories ──────────────────────────────────────────
  if (!sl.isRegistered<RecordingRepository>()) {
    sl.registerLazySingleton<RecordingRepository>(
      () => RecordingRepository(),
    );
  }

  // ── Audio initialization ───────────────────────────────────
  // Initialize the audio coordinator eagerly so it is ready
  // before the first BLoC is created. The guard inside
  // AudioServiceCoordinator.initialize() makes this idempotent.
  final audioInitialized = await sl<AudioServiceCoordinator>().initialize();
  if (!audioInitialized) {
    // Non-fatal: app continues, recording will fail gracefully
    assert(false, 'AudioServiceCoordinator failed to initialize');
  }
}
