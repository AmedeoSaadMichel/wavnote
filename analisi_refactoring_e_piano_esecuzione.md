# Analisi Refactoring WavNote e Piano di Esecuzione per AI

## 1. Contesto

Questo documento confronta il commit `b59c241` (pre-refactoring, tutte le funzionalita funzionanti) con lo stato attuale `d9fbe2b` (post-refactoring). L'obiettivo e mappare le funzionalita che funzionavano, identificare i problemi introdotti dal refactoring, e fornire un piano di esecuzione dettagliato per un'AI che deve completare/correggere il lavoro.

Il refactoring ha toccato **52 file**, con **3042 righe aggiunte** e **2442 righe rimosse**.

---

## 2. Funzionalita Funzionanti nel Commit Pre-Refactoring (b59c241)

### 2.1 Registrazione Audio
- Registrazione audio completa con `record` package
- Pause/Resume durante la registrazione
- Denominazione automatica basata sulla geolocalizzazione (via `GeolocationService`)
- Seek-and-resume: possibilita di riascoltare durante la registrazione e riprendere dal punto di seek
- Audio trimming: taglio dell'audio registrato tramite `AudioTrimmerService` (plugin nativo iOS/Android)
- Waveform live durante la registrazione

### 2.2 Riproduzione Audio
- Riproduzione con `just_audio`
- Playback da card di registrazione con waveform visuale
- Controlli play/pause/seek
- Gestione stato audio centralizzata tramite `AudioStateManager`
- Single AudioPlayer architecture a livello di screen

### 2.3 Gestione Cartelle
- Creazione cartelle personalizzate con icona (`IconData`) e colore (`Color`)
- Rinomina e cancellazione cartelle
- Cartelle di sistema (All Recordings, Recently Deleted)
- Ordinamento cartelle con criteri multipli
- Spostamento registrazioni tra cartelle

### 2.4 Gestione Registrazioni
- CRUD completo delle registrazioni
- Ricerca avanzata e filtri
- Ordinamento per data, nome, durata
- Operazioni bulk (selezione multipla, cancellazione)
- Import/export file audio
- Statistiche per cartella

### 2.5 Impostazioni
- Gestione formato audio (m4a, wav, aac)
- Gestione sample rate
- Persistenza impostazioni su database SQLite
- Ultimo folder aperto memorizzato

### 2.6 Architettura Pre-Refactoring
- Clean Architecture con BLoC pattern
- `FolderBloc` creato senza parametri (auto-istanziava `FolderRepository`)
- `SettingsBloc` creato senza parametri (accedeva direttamente a `DatabaseHelper`)
- `RecordingBloc` riceveva classi concrete: `AudioServiceCoordinator`, `RecordingRepository`, `GeolocationService`
- Use case con dipendenze concrete
- SQL helper methods (`sqlOrderBy`) direttamente sulle enum del domain layer

---

## 3. Cambiamenti Introdotti dal Refactoring

### 3.1 Sprint 1: Isolamento Servizi Audio

**Cosa e cambiato:**
- Creata `IAudioTrimmerRepository` (interfaccia astratta per trim audio)
- Creata `ILocationRepository` (interfaccia astratta per geolocalizzazione)
- `IAudioServiceRepository` arricchita con property `needsDisposal` e metodo `dispose()`
- Use case refactorizzati per usare interfacce:
  - `SeekAndResumeUseCase`: `AudioTrimmerService` -> `IAudioTrimmerRepository`
  - `RecordingLifecycleUseCase`: usa interfacce
  - `StartRecordingUseCase`: `GeolocationService` -> `ILocationRepository`
  - `StopRecordingUseCase`: `GeolocationService` -> `ILocationRepository`
- `RecordingBloc`: `geolocationService` -> `locationRepository`, `AudioTrimmerService` -> `IAudioTrimmerRepository`

**Breaking changes:**
- Firma costruttore `RecordingBloc` cambiata (parametro rinominato)
- Firma costruttore di tutti e 4 i use case cambiata
- `RecordingLifecycleBloc`: inizializzazione audio ora asincrona via evento `InitializeRecordingService`

### 3.2 Sprint 2: Purificare FolderEntity

**Cosa e cambiato:**
- `FolderEntity`: `IconData icon` -> `int iconCodePoint`, `Color color` -> `int colorValue`
- Creato `FolderUiMapper` per convertire `int` -> `IconData`/`Color` nel presentation layer
- `FolderModel` aggiornato di conseguenza
- `FolderRepository` aggiornato

**Breaking changes:**
- `CreateFolder` event: `color: Color` -> `colorValue: int`, `icon: IconData` -> `iconCodePoint: int`
- Tutti i punti che creano `FolderEntity` devono usare la nuova firma
- Tutti i widget che leggono `folder.icon`/`folder.color` devono usare `FolderUiMapper`
- `FolderBloc` ora richiede parametro obbligatorio `folderRepository: IFolderRepository`

### 3.3 Sprint 3: Repository per Settings

**Cosa e cambiato:**
- Creata `ISettingsRepository` (interfaccia) e `SettingsRepositoryImpl` (implementazione)
- `SettingsBloc` refactorizzato: non accede piu a `DatabaseHelper` direttamente
- Metodi statici di `SettingsBloc` ora usano `sl<ISettingsRepository>()`

**Breaking changes:**
- `SettingsBloc` ora richiede parametro obbligatorio `settingsRepository: ISettingsRepository`
- `SettingsBloc()` senza parametri -> errore di compilazione

### 3.4 Sprint 4: Rimuovere SQL dal Domain Layer

**Cosa e cambiato:**
- Creati `RecordingSortMapper` e `FolderSortMapper` nel data layer
- Rimossi extension method `sqlOrderBy` dalle enum del domain layer
- Repository aggiornati per usare i mapper

**Breaking changes:**
- Codice che usava `criteria.sqlOrderBy` deve usare `FolderSortMapper.toSqlOrderBy(criteria)`

### 3.5 Cambiamenti Aggiuntivi (Non Documentati nel Summary)

**AudioPlayerService** (il file con il diff piu grande: 1243 righe):
- Firma `initialize()` cambiata da `initialize([VoidCallback? onStateChanged])` a `initialize()`
- Metodi rimossi: `expandRecording()`, `resetAudioState()`, `setupAudioForRecording()`
- Logica estratta in `RecordingPlaybackController` (nuovo file)
- Creato `AudioCacheManager` (estrazione della logica LRU cache)

**RecordingCard:**
- Rimossi `operator ==` e `hashCode` (potenziale regressione di performance per rebuild)

**AudioFormatUiMapper:**
- Nuovo mapper per separare logica UI dalle enum audio format

**main.dart:**
- Tutti i `BlocProvider` aggiornati con parametri obbligatori e interfacce

---

## 4. Problemi Identificati

### 4.1 Problemi CRITICI (Bloccano la Compilazione)

| # | Problema | File Coinvolti |
|---|----------|----------------|
| 1 | `FolderBloc()` richiede ora `folderRepository` obbligatorio | main.dart, qualsiasi punto che crea FolderBloc |
| 2 | `SettingsBloc()` richiede ora `settingsRepository` obbligatorio | main.dart, qualsiasi punto che crea SettingsBloc |
| 3 | `CreateFolder` event usa `iconCodePoint`/`colorValue` (int) invece di `icon`/`color` | create_folder_dialog.dart, qualsiasi UI che crea folder |
| 4 | `RecordingBloc` parametro rinominato: `geolocationService` -> `locationRepository` | main.dart |
| 5 | `AudioPlayerService.initialize()` firma cambiata | Tutti i caller di initialize |
| 6 | Metodi rimossi da `AudioPlayerService`: `expandRecording()`, `resetAudioState()` | Widget/screen che li usavano |
| 7 | `sl<AudioServiceCoordinator>()` -> `sl<IAudioServiceRepository>()` | Tutti gli accessi via GetIt |

### 4.2 Problemi ALTI (Runtime Errors Potenziali)

| # | Problema | File Coinvolti |
|---|----------|----------------|
| 1 | `IAudioServiceRepository.needsDisposal` deve essere implementato da `AudioServiceCoordinator` | audio_service_coordinator.dart |
| 2 | `FolderUiMapper` definisce enum `FolderType` locale che potrebbe conflittare con `core/enums/folder_type.dart` | folder_ui_mapper.dart |
| 3 | Widget che accedono a `folder.icon`/`folder.color` direttamente senza FolderUiMapper | folder_item.dart, folder_selection_dialog.dart |
| 4 | `AudioStateManager` lazy init potrebbe causare null pointer | audio_state_manager.dart |
| 5 | Conversione `IconData(codePoint, fontFamily: 'MaterialIcons')` non funziona per FontAwesome | folder_ui_mapper.dart |

### 4.3 Problemi MEDI (Test e Qualita)

| # | Problema | File Coinvolti |
|---|----------|----------------|
| 1 | Test aggiornati ma non verificabili (Flutter non disponibile nell'ambiente di analisi) | test/ |
| 2 | `RecordingCard` senza `==`/`hashCode` causa rebuild eccessivi | recording_card_main.dart |
| 3 | `main_screen.dart` e `recording_list_screen.dart` usano ancora `DatabaseHelper` direttamente | Segnalato nel refactoring_summary.md come "remaining issues" |

### 4.4 File di Struttura Non Aggiornati

- `idea_project_structure.txt` non include i nuovi file creati dal refactoring
- `project_structure.txt` non riflette lo stato attuale
- I nuovi file aggiunti (7 file creati) non sono documentati nei file di struttura

---

## 5. Mappa delle Dipendenze Aggiornate

### 5.1 Dependency Injection (GetIt)

```
PRIMA (b59c241):                          DOPO (d9fbe2b):
sl<AudioServiceCoordinator>        ->     sl<IAudioServiceRepository>
sl<RecordingRepository>            ->     sl<IRecordingRepository>
sl<GeolocationService>             ->     sl<ILocationRepository>
(non registrato)                   ->     sl<IFolderRepository>
(non registrato)                   ->     sl<ISettingsRepository>
(non registrato)                   ->     sl<IAudioTrimmerRepository>
```

### 5.2 Catena BLoC -> Use Case -> Repository

```
FolderBloc
  └── IFolderRepository (new: iniettato nel costruttore)

SettingsBloc
  └── ISettingsRepository (new: iniettato nel costruttore)

RecordingBloc
  ├── IAudioServiceRepository (era: AudioServiceCoordinator)
  ├── IRecordingRepository (era: RecordingRepository)
  ├── ILocationRepository (new: era GeolocationService)
  ├── IAudioTrimmerRepository (new: era AudioTrimmerService)
  ├── StartRecordingUseCase
  │   ├── IAudioServiceRepository
  │   └── ILocationRepository (era: GeolocationService)
  ├── StopRecordingUseCase
  │   ├── IAudioServiceRepository
  │   ├── IRecordingRepository
  │   └── ILocationRepository (era: GeolocationService)
  ├── SeekAndResumeUseCase
  │   ├── IAudioServiceRepository
  │   └── IAudioTrimmerRepository (era: AudioTrimmerService)
  └── RecordingLifecycleUseCase
      └── IAudioServiceRepository

RecordingLifecycleBloc
  └── IAudioServiceRepository
```

---

## 6. Piano di Esecuzione per AI

### FASE 0: Setup e Verifica (Prerequisiti)

**Obiettivo:** Capire lo stato esatto del progetto prima di intervenire.

1. Eseguire `flutter analyze` per ottenere la lista completa degli errori di compilazione
2. Eseguire `flutter test` per verificare lo stato dei test
3. Leggere `idea_project_structure.txt` e `project_structure.txt`
4. Leggere `CLAUDE.md` per le regole del progetto
5. Documentare tutti gli errori trovati prima di iniziare qualsiasi fix

**Output atteso:** Lista numerata di tutti gli errori di compilazione e test falliti.

---

### FASE 1: Fix Interfacce e Implementazioni Mancanti (Priorita CRITICA)

**Obiettivo:** Assicurarsi che tutte le interfacce siano correttamente definite e implementate.

**Step 1.1** - Verificare `IAudioServiceRepository`
- Controllare che contenga: property `bool get needsDisposal`, metodo `Future<void> dispose()`
- Verificare che `AudioServiceCoordinator` implementi correttamente l'interfaccia

**Step 1.2** - Verificare `IAudioTrimmerRepository`
- Controllare che l'interfaccia copra tutti i metodi usati da `SeekAndResumeUseCase`
- Verificare che `AudioTrimmerService` implementi l'interfaccia

**Step 1.3** - Verificare `ILocationRepository`
- Controllare che contenga `getRecordingLocationName()`
- Verificare che `GeolocationService` implementi l'interfaccia

**Step 1.4** - Verificare `ISettingsRepository` e `SettingsRepositoryImpl`
- Controllare metodi: `loadAllSettings()`, `loadSetting(String key)`, `saveSettings(Map)`
- Verificare che `SettingsRepositoryImpl` funzioni correttamente con `DatabaseHelper`

**Step 1.5** - Verificare `IFolderRepository`
- Controllare che copra tutti i metodi usati da `FolderBloc`
- Verificare che `FolderRepository` implementi l'interfaccia

---

### FASE 2: Fix Dependency Injection (Priorita CRITICA)

**Obiettivo:** Tutte le registrazioni GetIt devono essere corrette.

**Step 2.1** - Verificare `dependency_injection.dart`
- Controllare che TUTTE le interfacce siano registrate
- Verificare l'ordine di registrazione (dipendenze prima dei dipendenti)
- Assicurarsi che non ci siano registrazioni duplicate

**Step 2.2** - Verificare `main.dart`
- Controllare tutti i `BlocProvider`:
  - `FolderBloc(folderRepository: sl<IFolderRepository>())`
  - `SettingsBloc(settingsRepository: sl<ISettingsRepository>())`
  - `RecordingBloc(audioService: sl<IAudioServiceRepository>(), recordingRepository: sl<IRecordingRepository>(), locationRepository: sl<ILocationRepository>())`
- Assicurarsi che `setupDependencies()` sia chiamato prima della creazione dei BLoC

---

### FASE 3: Fix Presentation Layer (Priorita ALTA)

**Obiettivo:** L'UI deve usare correttamente i nuovi tipi.

**Step 3.1** - Fix `FolderEntity` usage nel Presentation Layer
- Cercare tutti gli usi di `folder.icon` e `folder.color` nel codice
- Sostituire con `FolderUiMapper.toIconData(folder.iconCodePoint)` e `FolderUiMapper.toColor(folder.colorValue)`
- File da controllare: `folder_item.dart`, `folder_selection_dialog.dart`, `main_screen.dart`

**Step 3.2** - Fix `CreateFolder` event
- Cercare tutti i dispatch di `CreateFolder` nel codice
- Aggiornare da `color: Colors.blue, icon: Icons.folder` a `colorValue: Colors.blue.value, iconCodePoint: Icons.folder.codePoint`
- File principale: `create_folder_dialog.dart`

**Step 3.3** - Fix accesso diretto a `DatabaseHelper` nel Presentation Layer
- `main_screen.dart`: sostituire accesso diretto a DB con `ISettingsRepository` o `SettingsBloc`
- `recording_list_screen.dart`: stessa cosa

**Step 3.4** - Fix `AudioPlayerService` consumers
- Verificare che nessun codice chiami `initialize(callback)` (ora e `initialize()`)
- Verificare che nessun codice chiami metodi rimossi (`expandRecording`, `resetAudioState`, `setupAudioForRecording`)
- Se necessario, migrare a `RecordingPlaybackController`

---

### FASE 4: Fix Sort Mapper e Domain Layer (Priorita MEDIA)

**Obiettivo:** Assicurarsi che sorting e query funzionino.

**Step 4.1** - Verificare `FolderSortMapper` e `RecordingSortMapper`
- Controllare che i mapper coprano tutti i criteri di ordinamento
- Verificare che i repository li usino correttamente

**Step 4.2** - Verificare che il domain layer non importi Flutter o SQL
- Nessun `import 'package:flutter/material.dart'` nel domain layer
- Nessun SQL raw nel domain layer

---

### FASE 5: Fix Test (Priorita MEDIA)

**Obiettivo:** Tutti i test devono passare.

**Step 5.1** - Aggiornare `test_helpers.dart`
- Verificare che i mock siano allineati con le nuove interfacce
- Aggiungere mock per: `IFolderRepository`, `ISettingsRepository`, `IAudioTrimmerRepository`, `ILocationRepository`

**Step 5.2** - Fix test dei BLoC
- `folder_bloc_test.dart`: aggiornare creazione BLoC con parametro `folderRepository`
- `settings_bloc_test.dart`: aggiornare con parametro `settingsRepository`
- `recording_bloc_test.dart`: aggiornare parametri rinominati

**Step 5.3** - Fix test degli Use Case
- Aggiornare le firme dei costruttori nei test
- Verificare che i mock implementino le interfacce corrette

**Step 5.4** - Eseguire `flutter test` e fixare eventuali errori residui

---

### FASE 6: Aggiornamento Documentazione (Priorita BASSA)

**Obiettivo:** I file di struttura devono riflettere lo stato reale.

**Step 6.1** - Aggiornare `idea_project_structure.txt`
- Aggiungere i 7 nuovi file creati
- Marcare come IMPLEMENTED i file che ora esistono
- Aggiornare i contatori

**Step 6.2** - Aggiornare `project_structure.txt`
- Sincronizzare con lo stato reale del filesystem

---

### FASE 7: Verifica Finale

**Step 7.1** - Eseguire `flutter analyze` -> 0 errori
**Step 7.2** - Eseguire `flutter test` -> tutti i test passano
**Step 7.3** - Verificare che nessun file superi le 800 righe
**Step 7.4** - Verificare che ogni file abbia il commento di percorso
**Step 7.5** - Build test: `flutter build ios --no-codesign` (o `flutter build apk`)

---

## 7. Note Importanti per l'AI Esecutrice

1. **NON rimuovere logica BLoC** - Preservare sempre `BlocBuilder`, `BlocConsumer`, `BlocListener`
2. **NON cambiare logica senza chiedere** - Quando si correggono errori, chiedere prima di modificare la logica
3. **Rispettare il limite di 800 righe per file** - Se un file supera il limite, refactorizzare
4. **Commento di percorso obbligatorio** - `// File: [percorso/esatto/del/file.dart]` in ogni file
5. **Scrivere in italiano** - Commenti e comunicazioni in italiano
6. **NON fare git commit/push autonomamente** - Chiedere sempre esplicitamente
7. **Aggiornare i file di struttura** - Ogni volta che si aggiunge un file, fornire entrambi i file aggiornati
8. **Usare `Either<Failure, Success>`** - Pattern coerente per gestione errori
9. **UI Responsivo** - Usare `Flexible`, `Expanded`, `FractionallySizedBox` invece di pixel fissi
10. **Design pulito e moderno** - Material Design, NO temi cosmici/mistici

---

## 8. Riepilogo Numerico

| Metrica | Valore |
|---------|--------|
| File toccati dal refactoring | 52 |
| Righe aggiunte | 3042 |
| Righe rimosse | 2442 |
| Nuovi file creati | 7 |
| Interfacce create | 5 (IAudioTrimmerRepo, ILocationRepo, ISettingsRepo + IFolderRepo, IAudioServiceRepo aggiornate) |
| Mapper creati | 4 (FolderSort, RecordingSort, FolderUi, AudioFormatUi) |
| Controller creati | 1 (RecordingPlaybackController) |
| Service creati | 1 (AudioCacheManager) |
| BLoC con firma costruttore cambiata | 3 (FolderBloc, SettingsBloc, RecordingBloc) |
| Use case con firma cambiata | 4 |
| Breaking changes critici | 7 |
| File test da aggiornare | 8 |
| Remaining issues dal summary | 2 (DatabaseHelper diretto in presentation) |
