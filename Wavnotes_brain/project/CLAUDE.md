# WavNote — Contesto permanente del progetto

## Stack tecnologico
| Layer | Tecnologia | Versione |
|-------|-----------|---------|
| Framework | Flutter | SDK ^3.8.0 |
| State management | flutter_bloc | ^9.1.1 |
| DI | get_it | ^8.0.3 |
| Navigation | go_router | ^14.6.1 |
| DB | sqflite | ^2.4.2 |
| Audio record | `record` (fallback) + AVAudioEngine nativo | ^6.0.0 |
| Audio playback | just_audio | ^0.10.4 |
| Waveform | audio_waveforms | ^1.3.0 |
| Functional | dartz (Either) | ^0.10.1 |
| Equality | equatable | ^2.0.7 |
| Location | geolocator + geocoding | ^14.0.1 / ^4.0.0 |
| Permissions | permission_handler | ^12.0.0+1 |
| Icons | font_awesome_flutter | ^10.7.0 |
| Date | intl | ^0.20.2 |
| Test | bloc_test, mocktail, mockito | — |

## Struttura cartelle (lib/)
```
lib/
├── main.dart                        ← entry point, MultiBlocProvider, theme
├── config/
│   ├── app_config.dart
│   └── dependency_injection.dart    ← UNICA fonte di verità per GetIt (sl<T>())
├── core/
│   ├── constants/app_constants.dart
│   ├── enums/                       ← AudioFormat (wav/m4a/flac), FolderType
│   ├── errors/                      ← failures.dart, failure_types/, exceptions.dart
│   ├── extensions/                  ← datetime, duration, string
│   ├── routing/app_router.dart      ← GoRouter (createRouterAsync)
│   └── utils/                       ← date_formatter, file_utils, waveform_generator…
├── data/
│   ├── database/database_helper.dart ← SQLite singleton idempotente
│   ├── mappers/                      ← folder_sort, recording_sort
│   ├── models/                       ← FolderModel, RecordingModel
│   └── repositories/                 ← RecordingRepository (split in base/crud/search/bulk/stats/utils)
├── domain/
│   ├── entities/                     ← RecordingEntity, FolderEntity
│   ├── repositories/                 ← interfacce i_*.dart
│   └── usecases/recording/           ← start/stop/pause/overwrite/lifecycle/get
├── presentation/
│   ├── bloc/
│   │   ├── folder/                   ← FolderBloc
│   │   ├── recording/                ← RecordingBloc (split: _lifecycle, _management)
│   │   ├── recording_lifecycle/      ← RecordingLifecycleBloc
│   │   └── settings/                 ← SettingsBloc
│   ├── mappers/                      ← audio_format_ui, folder_ui
│   ├── screens/
│   │   ├── main/main_screen.dart
│   │   ├── recording/                ← recording_list_screen, recording_list_logic, controllers/
│   │   └── settings/settings_screen.dart
│   └── widgets/
│       ├── common/                   ← custom_button, dialog, empty_state, skeleton_screen…
│       ├── dialogs/                  ← audio_format, create_folder, folder_selection, sample_rate
│       ├── folder/folder_item.dart
│       ├── inputs/search_bar.dart
│       ├── recording/
│       │   ├── bottom_sheet/         ← main, compact_view, fullscreen_view, control_buttons, waveform_components
│       │   ├── custom_waveform/      ← flutter_sound_waveform, recorder_wave_painter, label, utils
│       │   └── recording_card/       ← main, actions, info
│       └── settings/                 ← app_settings, audio_settings, recording_settings, storage_settings
└── services/
    ├── audio/
    │   ├── audio_service_coordinator.dart  ← orchestratore principale (usa AVAudioEngine su iOS/macOS)
    │   ├── audio_engine_service.dart       ← AVAudioEngine nativo
    │   ├── audio_player_service.dart       ← just_audio wrapper
    │   ├── audio_recorder_service.dart     ← package record (fallback)
    │   ├── audio_trimmer_service.dart
    │   ├── audio_analysis_service.dart
    │   ├── audio_cache_manager.dart
    │   ├── audio_state_manager.dart
    │   ├── waveform_processing_service.dart
    │   └── impl/                           ← audio_monitoring, audio_player_impl
    ├── file/                               ← export, import, file_manager, metadata
    ├── location/geolocation_service.dart
    ├── logging/swift_log_channel_service.dart  ← EventChannel debug bridge
    ├── permission/permission_service.dart
    └── storage/database_service.dart
```

## Pattern architetturali
| Pattern | Dove | Regola |
|---------|------|--------|
| Clean Architecture | tutti i layer | domain non dipende da data/services |
| BLoC | presentation/bloc/ | eventi → stati, no logica nell'UI |
| Repository | domain/repositories/ (interfacce) + data/ (impl) | BLoC usa solo interfacce |
| Use Case | domain/usecases/ | un use case = una responsabilità |
| Either<Failure,T> | repository + use case | `.fold()` nel BLoC, no eccezioni all'UI |
| GetIt singleton | config/dependency_injection.dart | unica registrazione per tipo |
| Idempotent init | tutti i servizi con `initialize()` | guard `_isInitialized` |

## Convenzioni di naming
- File: `snake_case.dart`
- Classi: `PascalCase`
- Interfacce repository: prefisso `I` → `IRecordingRepository`
- BLoC split: `recording_bloc.dart` + `_lifecycle.dart` + `_management.dart`
- Commento obbligatorio inizio file: `// File: path/relativo/file.dart`
- ID recording: `DateTime.now().millisecondsSinceEpoch.toString()`
- Folder speciale trash: `folderId == 'recently_deleted'`

## Tema UI
- Dark theme, Brightness.dark
- Primary: `Colors.yellowAccent` (CTA)
- Secondary: `Colors.cyan`
- Surface: `Color(0xFF5A2B8C)` deep purple
- Gradient accent: `Color(0xFF8E2DE2)`
- Font: Roboto

## Formati audio supportati
| Formato | Qualità | Dimensione | Sample rate default |
|---------|---------|-----------|-------------------|
| WAV | 5/5 | Grande | 44100 Hz |
| M4A | 4/5 | Piccola | 44100 Hz |
| FLAC | 5/5 | Media-grande | 48000 Hz |

## Inizializzazione app (ordine critico)
1. `DatabaseHelper.database` — apre SQLite
2. `setupDependencies()` — registra GetIt + inizializza AudioServiceCoordinator
3. `SwiftLogChannelService.instance.initialize()` — solo debug
4. `runApp(WavNoteApp())` — BLoC providers + GoRouter async

---

## Come usare questa vault

**Inizio sessione:**
1. Leggi `_index.md` → vai diretto alla nota necessaria
2. Non esplorare liberamente il vault
3. Usa `project/CLAUDE.md` per capire il contesto senza rileggere il codice

**Durante la sessione:**
- Nuova decisione architetturale → crea `project/adr/YYYY-MM-DD-titolo.md` dal template
- Feature completata/modificata → aggiorna `project/features.md`
- Workaround aggiunto → aggiungi a `project/tech-debt.md`

**Fine sessione (solo se >20 min o decisioni architetturali):**
- Crea `log/sessions/YYYY-MM-DD-topic.md` dal template `templates/session`
- Assicurati che ogni file di log creato contenga link espliciti (es. `[[project/features]]`) per mantenere il Graph di Obsidian connesso
- Aggiorna `features.md` e `tech-debt.md`
- Non scrivere mai in `_index.md` durante la sessione, solo a fine sessione se è cambiata la struttura
