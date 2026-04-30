# WavNote — Architettura e Moduli

> Documento di riferimento per capire come è strutturato il progetto. Aggiorna quando aggiungi file o cambi responsabilità di un modulo.

---

## Panoramica

WavNote è un'app Flutter di registrazione vocale. Architettura **Clean Architecture** a 4 layer + un layer di servizi audio nativo.

```
┌─────────────────────────────────────────────────────────────┐
│  PRESENTATION  (BLoC + Screens + Widgets)                   │
├─────────────────────────────────────────────────────────────┤
│  DOMAIN  (Entities + UseCases + Repository Interfaces)      │
├─────────────────────────────────────────────────────────────┤
│  DATA  (Repository Implementations + Models + Database)     │
├─────────────────────────────────────────────────────────────┤
│  SERVICES  (Audio, File, Location, Permission, Logging)     │
├─────────────────────────────────────────────────────────────┤
│  CORE  (Utils, Extensions, Errors, Routing, Constants)      │
└─────────────────────────────────────────────────────────────┘
```

**Regola fondamentale:** ogni layer dipende solo dal layer sotto di lui. `domain/` non importa nulla da `data/` o `presentation/`. `presentation/` non parla mai direttamente con `data/`.

---

## Flusso dati tipico (esempio: avvia registrazione)

```
UI tap bottone Record
  → RecordingBloc.add(StartRecording)
  → StartRecordingUseCase.execute()
  → IAudioServiceRepository (interfaccia)
    → AudioServiceCoordinator (implementazione concreta)
      → AudioEngineService (nativo iOS/macOS via MethodChannel)
        → AVAudioEngine (Swift)
  → Stream amplitude/durata → BLoC
  → BLoC emette RecordingInProgress
  → BlocBuilder ricostruisce UI
```

---

## Dependency Injection

Tutto registrato in `lib/config/dependency_injection.dart` via **GetIt**. Nessuna istanziazione nei costruttori BLoC o in `main.dart`. Ogni servizio/repository/use case ha un'unica istanza registrata.

```dart
sl<IAudioPlaybackEngine>()       // → AudioPlaybackEngineImpl
sl<IAudioPreparationService>()   // → AudioPreparationService
sl<IAudioServiceRepository>()    // → RecordingServiceRepository
sl<IRecordingRepository>()       // → RecordingRepository
sl<IFolderRepository>()          // → FolderRepository
sl<StartRecordingUseCase>()
sl<StopRecordingUseCase>()
// ...
```

---

## `lib/main.dart` — Entry Point (355 righe)

Responsabilità: inizializzazione database, DI, BLoC providers, GoRouter.

**Problema noto:** 355 righe è troppo per un entry point. Contiene logica di init, setup router, e provider che andrebbero separati.

---

## `lib/config/`

### `app_config.dart`
Costanti di configurazione app: versione, build number, feature flags, environment.

### `dependency_injection.dart`
**Unica fonte di verità per GetIt.** Registra nell'ordine corretto: database → servizi audio → repositories → use cases → BLoC (non registrato qui, ma nei BlocProvider di main).

---

## `lib/core/`

Layer trasversale. Non contiene business logic. Nessun import da `domain/`, `data/`, `presentation/`.

### `constants/app_constants.dart`
Costanti globali: timeout, limiti storage, durate animazioni, valori default.

### `enums/audio_format.dart`
Enum `AudioFormat` con i tre formati supportati:
- `wav` — qualità massima, file grande, sample rate 44100 Hz
- `m4a` — qualità alta, file piccolo, sample rate 44100 Hz
- `flac` — qualità massima, file medio-grande, sample rate 48000 Hz

Ogni valore porta i metadata UI (label, colore, icona) e tecnici (fileExtension, qualityScore).

### `enums/folder_type.dart`
Enum `FolderType`: `allRecordings`, `favorites`, `recentlyDeleted`, `custom`.

### `utils/file_utils.dart` (501 righe)
Utility per path: costruzione, validazione, conversione path relativo↔assoluto, estrazione nome/estensione, calcolo dimensioni.

### `utils/app_file_utils.dart`
`AppFileUtils` — due metodi critici usati ovunque nell'audio pipeline:
- `AppFileUtils.resolve(relativePath)` → path assoluto sul device
- `AppFileUtils.toRelative(absolutePath)` → path relativo da salvare in DB

### `utils/waveform_generator.dart`
Genera dati forma d'onda (lista di double 0.0–1.0) da un file audio. Usato per la visualizzazione statica delle recording card.

### `utils/date_formatter.dart`
Formattazione date per UI: "Oggi 14:32", "Ieri", "12 Apr", "12 Apr 2025". Gestisce i18n.

### `utils/performance_logger.dart`
Logger di performance per debug. Non usato in produzione.

### `extensions/`
Extension methods su tipi standard Dart:
- `datetime_extensions.dart` — `isToday`, `isYesterday`, `formatForDisplay`, `toTimeAgo`
- `duration_extensions.dart` — `toMMSS`, `toHHMMSS`, `toReadableString`
- `string_extensions.dart` — validazione, sanitizzazione, capitalizzazione

### `errors/`
Sistema di error handling funzionale basato su `Either<Failure, T>` (dartz).

**`failures.dart`** — classe base `Failure` con `message` e `code`. Ogni errore nel sistema è un `Failure`, mai un'eccezione raw.

**`failure_types/`:**
- `audio_failures.dart` — `RecorderFailed`, `PlayerFailed`, `MicrophonePermissionDenied`, `AudioFileCorrupted`
- `data_failures.dart` — `DatabaseFailure`, `StorageFailure`, `NotFoundFailure`
- `system_failures.dart` — `PermissionFailure`, `NetworkFailure`, `UnknownFailure`

**`exceptions.dart`** — eccezioni interne ai servizi (non arrivano mai all'UI). Convertite in `Failure` da `failure_utils.dart` prima di uscire dal layer data.

**`failure_utils.dart`** — helper `exceptionToFailure()`, `mapFailure()`.

### `routing/app_router.dart`
Configurazione GoRouter. Route definite:
- `/` → `MainScreen`
- `/recordings/:folderId` → `RecordingListScreen`
- `/playback/:recordingId` → `PlaybackScreen`
- `/settings` → `SettingsScreen`

---

## `lib/domain/`

Layer puro Dart. Nessuna dipendenza da Flutter o da pacchetti esterni (eccezione: `equatable`, `dartz`).

### `entities/recording_entity.dart` (372 righe)
`RecordingEntity` — l'entità core del sistema. Immutabile, confrontabile con `Equatable`.

Campi principali:
```
id            String   — millisecondsSinceEpoch come stringa
name          String   — nome visualizzato
filePath      String   — path relativo (es. "all_recordings/Rec_2026.m4a")
folderId      String   — cartella di appartenenza
format        AudioFormat
duration      Duration
fileSize      int      — bytes
sampleRate    int
latitude/longitude   — posizione opzionale
tags          List<String>
isFavorite    bool
isDeleted     bool     — soft delete
```

### `entities/folder_entity.dart` (324 righe)
`FolderEntity` — cartella di organizzazione. Può essere default (non cancellabile) o custom.

Factory constructors: `createDefaultFolder()`, `createCustomFolder()`.

### `repositories/i_recording_repository.dart` (243 righe)
Interfaccia completa per CRUD recording:
- `getAllRecordings()` → `Either<Failure, List<RecordingEntity>>`
- `createRecording(entity)` → `Either<Failure, RecordingEntity>`
- `updateRecording(entity)` → `Either<Failure, RecordingEntity>`
- `softDeleteRecording(id)` / `restoreRecording(id)`
- `searchByName(query)`, `searchByDateRange(from, to)`, `searchByTags(tags)`
- `getRecordingStats()` — statistiche aggregate

### `repositories/i_folder_repository.dart`
CRUD cartelle + inizializzazione default folders.

### `repositories/i_audio_service_repository.dart` (317 righe)
**Interfaccia mista** — contiene sia recording ops che playback ops legacy. Storicamente usata dal BLoC per tutto. Oggi le playback ops sono marcate come non supportate nell'implementazione principale (`RecordingServiceRepository`).

**Problema noto:** questa interfaccia andrebbe splittatain `IAudioRecordingRepository` + `IAudioPlaybackRepository`.

### `repositories/i_settings_repository.dart`
`getSetting(key)` / `setSetting(key, value)` per preferenze persistite.

### `repositories/i_audio_trimmer_repository.dart`
`trimAudio(filePath, startMs, endMs)` — taglia un file audio.

### `usecases/start_recording_usecase.dart` (196 righe)
Avvia una nuova registrazione. Responsabilità:
1. Richiede permesso microfono
2. Costruisce il path del file con formato/cartella/timestamp
3. Chiama `IAudioServiceRepository.startRecording()`
4. Ritorna `RecordingEntity` parziale (senza durata finale)

**Dettaglio critico:** il path generato ha l'estensione del formato richiesto (es. `.m4a`), ma il native engine registra fisicamente in `.wav`. Il file `.m4a` non esiste su disco fino alla conversione finale in `StopRecordingUseCase`.

### `usecases/stop_recording_usecase.dart` (191 righe)
Ferma la registrazione, salva su DB. Se `raw: false`, il native converte WAV → formato finale.

### `usecases/overwrite_recording_usecase.dart`
Chiama il native trimmer per incollare un segmento audio su un file base (usato nell'overdub).

---

## `lib/data/`

Implementazioni concrete delle interfacce domain. Dipende da SQLite e dal filesystem.

### `database/database_helper.dart`
Singleton SQLite. Schema:

**Tabella `recordings`:**
```
id, name, filePath, folderId, format, duration, fileSize,
sampleRate, bitRate, latitude, longitude, locationName,
tags, isFavorite, isDeleted, deletedAt, createdAt, updatedAt
```

**Tabella `folders`:** id, name, iconCodePoint, colorValue, type, isDeletable

**Tabella `settings`:** key, value

Supporta migrations incrementali. Guard `_isInitialized` per init idempotente.

### `models/recording_model.dart`
Conversione `RecordingEntity` ↔ `Map<String, dynamic>` (per SQLite). Gestisce serializzazione di Duration, DateTime, List<String> (tags), AudioFormat.

### `models/folder_model.dart`
Conversione `FolderEntity` ↔ Map per SQLite.

### `repositories/recording_repository.dart`
Facade che compone 5 submodule in un unico repository:
- `RecordingRepositoryCrud` — getAllRecordings, createRecording, updateRecording, deleteRecording
- `RecordingRepositorySearch` — searchByName, searchByDateRange, searchByTags, searchByLocation
- `RecordingRepositoryBulk` — importRecordings, exportRecordings, softDeleteMultiple
- `RecordingRepositoryStats` — totalDuration, totalSize, countByFormat, countByFolder
- `RecordingRepositoryUtils` — path validation, file existence check
- `RecordingRepositoryBase` — helper condivisi (database access, entity→model conversion)

### `repositories/folder_repository.dart` (594 righe)
Gestisce cartelle default (All Recordings, Favorites, Recently Deleted) e custom. Aggiorna `recordingCount` automaticamente.

### `repositories/settings_repository_impl.dart`
Legge/scrive settings su SQLite. Usato da `SettingsBloc`.

### `mappers/`
- `recording_sort_mapper.dart` — converti preferenza sort UI → SQL ORDER BY clause
- `folder_sort_mapper.dart` — idem per folders

---

## `lib/presentation/bloc/`

### `recording/recording_bloc.dart` (328 righe)
Root del BLoC di registrazione. Registra gli event handler delegando a due extension:
- `_RecordingBlocLifecycle` (in `recording_bloc_lifecycle.dart`) — tutto il ciclo vita della registrazione
- `_RecordingBlocManagement` (in `recording_bloc_management.dart`) — operazioni sui file esistenti

Dipendenze: `IAudioServiceRepository`, `IRecordingRepository`, use cases, `IAudioPlaybackEngine`.

### `recording/recording_event.dart` (316 righe)
Tutti gli eventi che il BLoC può ricevere. Principali:
```
StartRecording          — avvia nuova registrazione
StopRecording           — ferma e salva
PauseRecording          — pausa
ResumeRecording         — riprende registrazione normale
ResumeWithAutoStop      — riprende in overdub mode (seek-and-resume)
StartOverwrite          — avvia sovrascrittura a posizione seekBarIndex
AmplitudeUpdated        — tick di ampiezza dal native
ClockTickReceived       — tick di durata dal native
UpdateSeekBarIndex      — posizione seek bar aggiornata
PlayRecordingPreview    — avvia preview playback durante pausa
StopRecordingPreview    — ferma preview playback
LoadRecordings          — carica lista
DeleteRecording         — elimina (soft)
ToggleFavorite          — toggle preferito
MoveToFolder            — sposta in cartella
```

### `recording/recording_state.dart` (412 righe)
Stati immutabili del BLoC:
```
RecordingLoading         — caricamento iniziale lista
RecordingLoaded          — lista caricata, nessuna registrazione attiva
RecordingStarting        — AVAudioSession in init (~3s), bottone non reattivo
RecordingInProgress      — registrazione attiva (porta amplitude, duration, waveData)
RecordingPaused          — registrazione in pausa (porta seekBarIndex, preview state)
RecordingStopping        — salvataggio in corso
RecordingError           — errore con messaggio
```

`RecordingInProgress` porta:
- `filePath` — path logico con estensione formato
- `amplitude` — valore 0.0–1.0 aggiornato ogni tick
- `seekBasePath` — path WAV base per overdub (null se nessun overdub in corso)
- `truncatedWaveData` — barre waveform fino al punto di seek
- `waveformDataForPlayer` — dati completi per il player
- `originalFilePathForOverwrite` — path originale pre-overdub

### `recording/recording_bloc_lifecycle.dart` (829 righe ⚠️ sopra limite)
Extension `_RecordingBlocLifecycle` con i gestori degli eventi lifecycle.

Handler principali:
- `_onStartRecording` — inizia registrazione, emette `RecordingStarting` → `RecordingInProgress`
- `_onPauseRecording` — pausa, assembla preview file WAV per playback nel bottom sheet
- `_onStopRecording` — ferma, merge overdub se presente, converte WAV→formato finale, salva su DB
- `_onStartOverwrite` — avvia sovrascrittura: stopRecording(raw:true), merge segmenti precedenti, avvia nuova registrazione
- `_onResumeWithAutoStop` — decide se è semplice resume o seek-and-overwrite
- `_onStopRecordingPreview` — ferma preview playback e prepara file per il player

**Logica overdub WAV-first:**
Durante tutto il processo di overdub, tutto viene tenuto in WAV grezzo. La conversione al formato finale avviene solo in `_onStopRecording`, quando l'utente preme Done. Questo evita perdite di qualità da doppia conversione.

**Problemi noti:** 829 righe (limite 800), 4 blocchi `[LEGACY]` commentati, 4 anti-pattern Either→Exception invece di `.fold()`.

### `recording/recording_bloc_management.dart` (359 righe)
Extension `_RecordingBlocManagement` per operazioni sui file esistenti:
- `_onLoadRecordings` — carica lista da repository
- `_onDeleteRecording` — soft delete
- `_onToggleFavorite` — toggle preferito
- `_onMoveToFolder` — sposta in cartella diversa
- `_onSearchRecordings` — filtra per testo/tag/data

### `folder/folder_bloc.dart` (570 righe)
Gestisce cartelle: CRUD, edit mode, selezione. Stato: `FolderLoading`, `FolderLoaded`, `FolderError`.

### `settings/settings_bloc.dart` (803 righe)
Gestisce tutte le preferenze utente: formato audio, sample rate, bitrate, animazioni, haptics. Persiste via `ISettingsRepository`.

---

## `lib/presentation/screens/`

### `main/main_screen.dart` (~357 righe)
Root screen dopo splash. Ora resta un orchestratore leggero:
- coordina tab Recordings/Settings e navigazione cartelle
- ascolta `FolderBloc`
- passa callback e stato ai widget estratti
- delega header e contenuto cartelle a file dedicati

### `main/main_screen_header.dart`
Header della main screen. Contiene titolo, azioni e stati UI legati alla parte superiore della schermata.

### `main/main_screen_folders.dart`
Contenuto cartelle della main screen. Renderizza default/custom folder, stati vuoti e azioni legate alla lista folder.

### `recording/recording_list_screen.dart` (~705 righe)
Schermata principale della cartella selezionata. Responsabilità:
- orchestrazione tra `RecordingBloc`, `RecordingBottomSheet` e `RecordingPlaybackCoordinator`
- gestione preview playback durante pausa/overdub
- conversione posizione audio → `seekBarIndex`
- `_cardIdsNotifier` — `ValueNotifier<(String?, String?)>` che si aggiorna solo quando cambiano `expandedRecordingId` o `activeRecordingId`, evitando rebuild a cascata ogni 100ms
- delega rendering lista a `RecordingListCardList`

### `recording/recording_list_content.dart`
Widget puro per la lista registrazioni:
- `RecordingCard` per ogni registrazione
- empty state e search-empty state
- `PullToSearchList`
- callback espliciti ricevuti dalla screen

### `recording/recording_list_logic.dart` (772 righe)
`mixin RecordingListLogic` usato da `RecordingListScreen`. Separa la logica dalla UI:
- Selezione recording
- Edit mode (multi-selezione, bulk delete)
- Filtering e sorting
- Coordinazione playback con il coordinator
- `_syncPausedPreviewPlaybackState` — aggiorna `seekBarIndex` ogni ~100ms durante preview

### `recording/controllers/recording_playback_coordinator.dart` (226 righe)
Coordinatore UI del playback. Non è un BLoC — è un `ChangeNotifier` che espone `RecordingPlaybackViewState`:
- `expandedRecordingId` — quale card è espansa
- `activeRecordingId` — quale recording sta suonando
- `position`, `duration`, `isPlaying`

Usato da `RecordingListScreen`, `PlaybackScreen`, e il bottom sheet. È l'unica fonte di verità per lo stato UI del playback.

### `playback/playback_screen.dart` (666 righe)
Player fullscreen per registrazioni esistenti. Waveform con scrubbing, play/pause/seek, info metadata (durata, formato, location). Usa `RecordingPlaybackCoordinator`.

### `settings/settings_screen.dart` (204 righe)
Form impostazioni audio e UI. Delegato a 4 section widget in `widgets/settings/`.

---

## `lib/presentation/widgets/`

### `common/`
Widget generici riutilizzabili in tutta l'app:
- `custom_button.dart` — bottone con varianti primary/secondary/outline
- `custom_dialog.dart` — dialog con titolo, body, azioni
- `empty_state.dart` — placeholder quando lista vuota
- `skeleton_screen.dart` — loading placeholder durante init DB (evita flash bianco)
- `loading_indicator.dart` — spinner e skeleton inline

### `dialogs/`
- `audio_format_dialog.dart` — selezione WAV/M4A/FLAC con info qualità/dimensione
- `create_folder_dialog.dart` — form creazione cartella (nome, icona emoji, colore)
- `folder_selection_dialog.dart` — scelta cartella destinazione per spostamento recording
- `sample_rate_dialog.dart` — selezione sample rate (8–48 kHz)

### `recording/recording_card/`
Card per ogni recording nella lista:
- `recording_card_main.dart` (755 righe) — expand/collapse, waveform statico, metadata
- `recording_card_info.dart` — data, durata, formato, location
- `recording_card_actions.dart` — bottoni play, condividi, elimina, preferito

### `recording/bottom_sheet/`
Bottom sheet sovrapposto durante sessione di registrazione attiva:

**`recording_bottom_sheet_main.dart` (613 righe)** — Coordinatore principale del bottom sheet. Gestisce in `didUpdateWidget`:
- `isSeekResume` — rileva seek-and-resume via `!identical(widget.truncatedWaveData, oldWidget.truncatedWaveData)`. `!identical` invece di null check perché dal secondo overdub `truncatedWaveData` è già non-null.
- `futureBarsCount` — barre future della waveform (grigie) calcolate al momento del seek
- Sync `seekBarIndex` locale con quello del BLoC

**`recording_compact_view.dart`** — Vista compatta (bottom sheet non espanso): nome, durata, pulsanti base.

**`recording_fullscreen_view.dart`** — Vista fullscreen: waveform a colori (segmento registrato vs futuro), seek bar, controlli avanzati.

**`control_buttons.dart`** — Pulsanti Record/Pause/Stop/Play condivisi tra compact e fullscreen view.

### `recording/custom_waveform/`
Rendering waveform custom (non usa librerie esterne per il disegno):
- `flutter_sound_waveform.dart` — widget container, gestisce lista double → barre
- `recorder_wave_painter.dart` — `CustomPainter` che disegna le barre con colori (registrato=giallo, futuro=grigio, seek=ciano)
- `waveform_components.dart` — label temporali, indicatore seek
- `waveform_utils.dart` — helper calcolo larghezze barre

### `settings/`
Sezioni della settings screen:
- `audio_settings_section.dart` — formato, sample rate, bitrate
- `recording_settings_section.dart` — impostazioni specifiche registrazione
- `storage_settings_section.dart` — spazio usato, pulizia cache, recently deleted
- `app_settings_section.dart` — animazioni, haptics, tema

---

## `lib/services/`

Layer che parla con il mondo esterno (filesystem, native code, network).

### `audio/audio_service_coordinator.dart` (512 righe)
**Orchestratore della registrazione.** Implementa `IAudioServiceRepository` (lato recording). Coordina:
- `AudioEngineService` — motore nativo iOS/macOS
- Stream amplitude/durata verso il BLoC
- `convertAudioFile()` — conversione finale WAV→M4A/FLAC

Non gestisce più il playback — quello è delegato a `IAudioPlaybackEngine`.

### `audio/audio_engine_service.dart` (454 righe)
Bridge verso il native AVAudioEngine via `MethodChannel('wavnote/audio_engine')`.

Metodi esposti al Dart:
- `startRecording(filePath, format, sampleRate, bitRate)` — avvia registrazione nativa
- `stopRecording(raw: bool)` → path del file risultante
- `convertAudioFile(input, output, format)` — conversione formato
- `getAudioDuration(filePath)` — durata tramite AVAsset

**Comportamento critico:** il native registra SEMPRE in PCM/WAV internamente, indipendentemente dal formato richiesto. Il file fisico è sempre `path.wav`. La conversione al formato finale avviene solo su `stopRecording(raw: false)`.

### `audio/audio_playback_engine_impl.dart` (314 righe)
Implementazione moderna di `IAudioPlaybackEngine`. Usa **just_audio**.

- `prepareAndPlay(filePath, startPosition)` — carica file e avvia
- `pause()`, `resume()`, `seek(position)`, `stop()`
- Stream: `positionStream`, `durationStream`, `playbackStateStream`

È il **singleton** usato da tutto il sistema playback: `RecordingPlaybackCoordinator`, `PlaybackScreen`, preview bottom sheet.

### `audio/audio_preparation_service.dart`
Prepara file audio per il playback: verifica esistenza, converte formato se necessario, warmup del player. Usato da `RecordingPlaybackCoordinator` prima di `prepareAndPlay`.

### `audio/audio_engine_playback_adapter.dart` (185 righe)
Adapter che espone `AudioEngineService` come `IAudioPlaybackEngine`. Usato per playback tramite il motore nativo invece di just_audio (path alternativo).

### `audio/audio_player_service.dart`
**⚠️ Deprecated.** Vecchio wrapper just_audio con singleton. Non più usato nei path UI migrati. Mantenuto per compatibilità temporanea.

### `audio/recording_service_repository.dart` (217 righe)
Implementa `IAudioServiceRepository` lato recording. Wrapper attorno a `AudioServiceCoordinator`. Le API playback ereditate dall'interfaccia sono implementate come `throw UnsupportedError` per bloccare nuovi usi.

### `audio/audio_analysis_service.dart` (414 righe)
Analisi audio: estrazione dati waveform da file, analisi spettrale. Usato per generare `waveformDataForPlayer` da file esistenti.

### `audio/audio_trimmer_service.dart`
Bridge verso `MethodChannel('wavnote/audio_trimmer')`. Espone `overwriteAudioSegment()` usato da `OverwriteRecordingUseCase`.

### `audio/audio_cache_manager.dart`
Cache LRU per file audio preparati. **Attualmente non usato** in nessun path UI reale — iniettato nel DI ma non consumato.

### `audio/impl/audio_monitoring_service.dart`
Sottosistema di monitoring: subscription agli stream amplitude e position dal native, forward verso il BLoC.

### `audio/impl/audio_player_impl.dart`
Implementazione interna just_audio usata da `AudioPlaybackEngineImpl`.

### `audio/i_audio_playback_engine.dart`
Interfaccia `IAudioPlaybackEngine` — contratto per il playback engine.

### `audio/i_audio_preparation_service.dart`
Interfaccia `IAudioPreparationService` — contratto per la preparazione file.

### `audio/audio_preparation_result.dart`
Data class risultato di `IAudioPreparationService.prepare()`: path assoluto, durata, waveform data.

### `audio/audio_playback_state.dart`
Enum `AudioPlaybackState`: `idle`, `buffering`, `playing`, `paused`, `completed`, `error`.

### `audio/audio_state_manager.dart`
Gestione stato audio condiviso tra servizi (evita conflitti recording/playback simultanei).

### `audio/waveform_processing_service.dart`
Processo dati waveform per normalizzazione e adattamento alla UI (scala barre, smoothing).

### `file/`
- `file_manager_service.dart` (488 righe) — I/O file: save, delete, move, copy, path management, validazione
- `metadata_service.dart` (501 righe) — Estrazione metadata audio (durata, format, sample rate) tramite AVAsset o FFmpeg
- `export_service.dart` — Export singolo/bulk con share sheet
- `import_service.dart` — Import file audio esterni, format detection

### `location/geolocation_service.dart`
Geolocalizzazione: coordinate GPS → nome location (geocoding). Opzionale, la registrazione funziona senza.

### `permission/permission_service.dart`
Richiesta e verifica permessi: microfono (obbligatorio), storage, location (opzionale).

### `logging/swift_log_channel_service.dart`
**Da rimuovere prima del rilascio.** Bridge `EventChannel` che riceve i log Swift dal native e li stampa in console Flutter. Utile solo in debug.

### `storage/database_service.dart`
Thin wrapper attorno a `DatabaseHelper`. Esposto via DI per chi ha bisogno solo di accesso DB senza logica repository.

---

## `ios/Runner/` e `macos/Runner/` — Native Swift

### `AudioEnginePlugin.swift`
Plugin AVAudioEngine. Gestisce:
- Registrazione PCM in WAV (sempre, indipendentemente dal formato richiesto)
- Conversione finale WAV → M4A/FLAC via AVAssetExportSession
- Playback tramite `AVAudioPlayerNode` con `reset()` obbligatorio in ogni cleanup path
- `EventChannel` per stream amplitude e completion events
- `seekOffsetFrames` per calcolo posizione cumulativa in overdub

### `AudioTrimmerPlugin.swift`
Plugin per operazioni di editing audio:
- `overwriteAudio(originalPath, insertionPath, startMs, overwriteDurationMs, outputPath, format)` — incolla `insertionPath` su `originalPath` a partire da `startMs`
- `pcmOverwrite()` — implementazione interna per file WAV
- Guard `FILE_NOT_FOUND` esplicito: se il file non esiste, ritorna `FlutterError` invece di crashare

---

## Problemi architetturali noti

| # | Problema | File | Priorità |
|---|----------|------|---------|
| 1 | `IAudioServiceRepository` mescola recording e playback ops | `domain/repositories/i_audio_service_repository.dart` | 🟡 Media |
| 2 | `recording_bloc_lifecycle.dart` sopra 800 righe con LEGACY e anti-pattern | `presentation/bloc/recording/recording_bloc_lifecycle.dart` | 🟡 Media |
| 3 | `AudioCacheManager` iniettato ma non usato | `services/audio/audio_cache_manager.dart` | 🟢 Bassa |
| 4 | `AudioPlayerService` deprecated ma non rimosso | `services/audio/audio_player_service.dart` | 🟢 Bassa |
| 5 | `main.dart` 355 righe con init + provider + routing | `main.dart` | 🟢 Bassa |
| 6 | `SwiftLogChannelService` attivo in produzione | `services/logging/swift_log_channel_service.dart` | 🔴 Alta |
| 7 | ~528 `print`/`debugPrint` nel codice | vari | 🟢 Bassa |

---

_Aggiornato: 2026-04-26_
