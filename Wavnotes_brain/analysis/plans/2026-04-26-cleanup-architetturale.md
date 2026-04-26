# Piano Cleanup Architetturale — WavNote

**Goal:** Risolvere i 7 problemi architetturali identificati mantenendo esattamente le stesse funzionalità dell'app.

**Principio:** ogni task è indipendente e può essere eseguito in sessioni separate. Nessun task introduce nuove funzionalità — solo pulizia e ristrutturazione.

**Riferimento:** [[project/architecture]] — sezione "Problemi architetturali noti"

---

## Task 1 — Rimuovere `SwiftLogChannelService` 🔴

**File da modificare:**
- `lib/main.dart`
- `lib/services/logging/swift_log_channel_service.dart` (eliminare)
- `lib/config/dependency_injection.dart`

**Cosa fare:**
- [ ] In `main.dart` rimuovere la riga `SwiftLogChannelService.instance.initialize()` e il relativo import
- [ ] In `dependency_injection.dart` rimuovere la registrazione GetIt di `SwiftLogChannelService` (se presente)
- [ ] Eliminare il file `lib/services/logging/swift_log_channel_service.dart`
- [ ] Verificare con `dart analyze` che non ci siano riferimenti rimasti
- [ ] Sul lato Swift (`ios/Runner/`, `macos/Runner/`): rimuovere il canale `EventChannel("com.wavnote/swift_logs")` da `AppDelegate` o dal plugin corrispondente se esiste codice dedicato
- [ ] `dart analyze` → 0 errori nuovi

**Rischio:** nessuno — è solo un canale di debug logging.

---

## Task 2 — Rimuovere `AudioPlayerService` deprecated e `AudioCacheManager` inutilizzato

**File da modificare:**
- `lib/services/audio/audio_player_service.dart` (eliminare)
- `lib/services/audio/audio_cache_manager.dart` (eliminare)
- `lib/config/dependency_injection.dart`
- Qualsiasi import residuo nei file che li importano

**Cosa fare:**
- [ ] `grep -r "AudioPlayerService\|AudioCacheManager" lib/` — elenca tutti i file che li referenziano
- [ ] Per ogni file trovato: rimuovere import e utilizzo (aspettati solo import orfani, dato che sono già deprecated/non usati)
- [ ] Rimuovere registrazioni GetIt in `dependency_injection.dart`
- [ ] Eliminare `audio_player_service.dart` e `audio_cache_manager.dart`
- [ ] `dart analyze` → 0 errori nuovi

**Rischio:** basso — `AudioPlayerService` è @Deprecated e non usato nei path UI migrati. `AudioCacheManager` è iniettato ma non consumato.

---

## Task 3 — Fix anti-pattern Either→Exception in `recording_bloc_lifecycle.dart`

**File da modificare:**
- `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart`

**Problema:** 4 punti dove `isLeft()` + `throw Exception()` violano il pattern Either. Il `throw` dentro un `try/catch` che emette `RecordingError` funziona, ma è verboso e nasconde l'intenzione.

Le 4 righe da trasformare:
```dart
// PRIMA (anti-pattern):
if (owResult1.isLeft()) throw Exception(owResult1.fold((f) => f.message, (_) => ''));

// DOPO:
owResult1.fold(
  (failure) {
    emit(RecordingError('Failed to apply previous overwrite: ${failure.message}'));
    return;
  },
  (_) {},
);
// se il blocco successivo dipende dal successo, wrappa in if/return
```

**Cosa fare:**
- [ ] Trovare le 4 righe `isLeft()` (righe ~139, ~507, ~628, ~789 dopo rimozione LEGACY)
- [ ] Per ognuna: trasformare in `.fold()` con emit diretto nel branch left + `return` per uscire dall'handler
- [ ] Rimuovere i `try/catch` che avvolgono solo il pattern isLeft (non rimuovere catch che gestiscono altre eccezioni)
- [ ] `dart analyze` → 0 errori nuovi
- [ ] Verificare che la logica di `return` sia corretta in ogni caso (il handler deve uscire se il fold emette errore)

**Rischio:** basso — logica invariata, solo forma diversa.

---

## Task 4 — Split `recording_bloc_lifecycle.dart` (829 righe → sotto 800)

**File da creare:**
- `lib/presentation/bloc/recording/recording_bloc_overdub.dart` — nuova extension con la logica overdub

**File da modificare:**
- `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart` — rimane con start/stop/pause/resume base
- `lib/presentation/bloc/recording/recording_bloc.dart` — aggiunge `part` per il nuovo file

**Divisione responsabilità:**

`recording_bloc_lifecycle.dart` mantiene:
- `_onStartRecording`
- `_onStopRecording`
- `_onPauseRecording`
- `_onResumeRecording` (resume semplice senza overdub)
- Handler amplitude/clock tick
- `_startAmplitudeUpdates`, `_startDurationUpdates`, helper interni

`recording_bloc_overdub.dart` riceve:
- `_onResumeWithAutoStop`
- `_onStartOverwrite`
- `_onStopRecordingPreview`
- `_assemblePreviewFile` (helper privato dell'overdub)

**Cosa fare:**
- [ ] Creare `recording_bloc_overdub.dart` con intestazione `// File: ...` e `part of 'recording_bloc.dart';`
- [ ] Spostare i 4 handler overdub nel nuovo file come `extension _RecordingBlocOverdub on RecordingBloc`
- [ ] In `recording_bloc.dart` aggiungere `part 'recording_bloc_overdub.dart';`
- [ ] Verificare che `_overwriteRecordingUseCase` e altri servizi privati del BLoC siano accessibili dall'extension (sì, perché `part of` condivide lo scope)
- [ ] `dart analyze` → 0 errori nuovi
- [ ] Verificare: `recording_bloc_lifecycle.dart` sotto 800 righe, `recording_bloc_overdub.dart` sotto 500

**Rischio:** basso — il pattern `part of` usato dal progetto garantisce accesso completo ai campi privati.

---

## Task 5 — Split `IAudioServiceRepository` in due interfacce

**File da creare:**
- `lib/domain/repositories/i_audio_recording_repository.dart` — solo recording ops
- `lib/domain/repositories/i_audio_playback_repository.dart` — solo playback ops (legacy, da tenere per retrocompatibilità temporanea)

**File da modificare:**
- `lib/domain/repositories/i_audio_service_repository.dart` — diventa alias/deprecato
- `lib/services/audio/recording_service_repository.dart` — implementa `IAudioRecordingRepository`
- `lib/services/audio/audio_playback_engine_impl.dart` — già implementa `IAudioPlaybackEngine`, non toccare
- `lib/config/dependency_injection.dart` — aggiorna registrazione
- `lib/presentation/bloc/recording/recording_bloc.dart` — dipende da `IAudioServiceRepository`, aggiornare il costruttore
- `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart` — accede a `_audioService`, verificare che usi solo recording ops

**Strategia:** introdurre la nuova interfaccia senza rompere nulla, poi migrare gradualmente.

**Cosa fare:**
- [ ] Creare `i_audio_recording_repository.dart` con le sole ops di recording (startRecording, stopRecording, pauseRecording, amplitude stream, duration stream, convertAudioFile, getAudioDuration)
- [ ] `RecordingServiceRepository` implementa `IAudioRecordingRepository` (già fa queste cose)
- [ ] Nel DI registrare `IAudioRecordingRepository → RecordingServiceRepository`
- [ ] Nel `RecordingBloc` sostituire `IAudioServiceRepository _audioService` con `IAudioRecordingRepository _audioService`
- [ ] Aggiornare costruttore BLoC e `dependency_injection.dart`
- [ ] `IAudioServiceRepository` originale: mantenerla ma marcarla `@deprecated`
- [ ] `dart analyze` → 0 errori nuovi

**Rischio:** medio — il BLoC usa `_audioService` in molti punti. La nuova interfaccia deve coprire tutti i metodi chiamati. Verificare con `grep "_audioService\." recording_bloc_lifecycle.dart` prima di iniziare.

---

## Task 6 — Estrarre init logic da `main.dart`

**File da creare:**
- `lib/config/app_initializer.dart` — logica di bootstrap sequenziale

**File da modificare:**
- `lib/main.dart` — rimane solo con `runApp` e provider setup

**Cosa fare:**
- [ ] Creare `AppInitializer` con metodo statico `Future<void> initialize()` che esegue in ordine:
  1. `DatabaseHelper.database` — apre SQLite
  2. `setupDependencies()` — registra GetIt
  3. Qualsiasi altro init sequenziale
- [ ] `main()` diventa: `await AppInitializer.initialize(); runApp(WavNoteApp());`
- [ ] Estrarre `WavNoteApp` (root widget) in un file separato se `main.dart` rimane sopra 200 righe
- [ ] `dart analyze` → 0 errori nuovi

**Rischio:** basso — pura estrazione senza modifica logica.

---

## Task 7 — Audit e rimozione `print`/`debugPrint`

**File da modificare:** ~528 occorrenze sparse nel progetto

**Strategia:** non rimuovere tutti ciecamente. Classificare prima:
- `print()` di debug temporaneo → rimuovere
- `debugPrint()` con informazione utile per troubleshooting → convertire in logging condizionale (`if (kDebugMode)`)
- Log nei servizi audio (amplitude, seek, etc.) → rimuovere o condizionare a flag

**Cosa fare:**
- [ ] `grep -rn "print\|debugPrint" lib/ --include="*.dart" | wc -l` — conta occorrenze attuali
- [ ] Rimuovere tutti i `print()` nei file audio (audio_engine_service, audio_playback_engine_impl, audio_service_coordinator) — sono i più rumorosi
- [ ] Rimuovere print nel BLoC (recording_bloc_lifecycle, recording_bloc_management)
- [ ] Nei widget: rimuovere print, mantenere al massimo `if (kDebugMode) debugPrint(...)` dove utile
- [ ] `dart analyze` → 0 errori nuovi

**Rischio:** nullo — i print non influenzano la logica.

---

## Ordine di esecuzione consigliato

```
Task 1  → Task 2  → Task 7   (rimozioni pure, indipendenti, nessun rischio)
Task 3                        (fix stile, logica invariata)
Task 6                        (estrazione init, basso rischio)
Task 4                        (split file, medio)
Task 5                        (split interfaccia, medio — fare per ultimo perché tocca DI + BLoC)
```

---

## Stima

| Task | Tempo | Rischio |
|------|-------|---------|
| 1 — SwiftLogChannelService | 15 min | 🟢 |
| 2 — AudioPlayerService + CacheManager | 20 min | 🟢 |
| 3 — Either→Exception | 30 min | 🟢 |
| 4 — Split lifecycle/overdub | 45 min | 🟡 |
| 5 — Split IAudioServiceRepository | 60 min | 🟡 |
| 6 — main.dart init | 20 min | 🟢 |
| 7 — print audit | 30 min | 🟢 |
| **Totale** | **~3.5 ore** | |

_Aggiornato: 2026-04-26_
