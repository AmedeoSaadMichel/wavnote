# Piano Cleanup Architetturale — WavNote

**Goal:** Risolvere i problemi architetturali identificati mantenendo esattamente le stesse funzionalità dell'app.

**Principio:** ogni task è indipendente e può essere eseguito in sessioni separate. Nessun task introduce nuove funzionalità — solo pulizia e ristrutturazione.

**Riferimento:** [[project/architecture]] — sezione "Problemi architetturali noti"

---

## Task 2 — Rimuovere `AudioPlayerService` deprecated e `AudioCacheManager` inutilizzato

**File da eliminare:**
- `lib/services/audio/audio_player_service.dart`
- `lib/services/audio/audio_cache_manager.dart`

**File da modificare:**
- `lib/config/dependency_injection.dart`
- Qualsiasi import residuo nei file che li importano

**Cosa fare:**
- [ ] `grep -r "AudioPlayerService\|AudioCacheManager" lib/` — elenca tutti i file che li referenziano
- [ ] Per ogni file trovato: rimuovere import e utilizzo
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
```

**Cosa fare:**
- [ ] Trovare le 4 righe `isLeft()` nel file
- [ ] Per ognuna: trasformare in `.fold()` con emit diretto nel branch left + `return` per uscire dall'handler
- [ ] Rimuovere i `try/catch` che avvolgono solo il pattern isLeft (non rimuovere catch che gestiscono altre eccezioni reali)
- [ ] `dart analyze` → 0 errori nuovi
- [ ] Verificare che la logica di `return` sia corretta in ogni caso

**Rischio:** basso — logica invariata, solo forma diversa.

---

## Task 4 — Split `recording_bloc_lifecycle.dart` (801 righe → sotto 800)

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

**Rischio:** basso — il pattern `part of` garantisce accesso completo ai campi privati.

---

## Task 5 — Split `IAudioServiceRepository` in due interfacce

**File da creare:**
- `lib/domain/repositories/i_audio_recording_repository.dart` — solo recording ops

**File da modificare:**
- `lib/domain/repositories/i_audio_service_repository.dart` — marca `@deprecated`
- `lib/services/audio/recording_service_repository.dart` — implementa `IAudioRecordingRepository`
- `lib/config/dependency_injection.dart` — aggiorna registrazione
- `lib/presentation/bloc/recording/recording_bloc.dart` — aggiorna costruttore

**Cosa fare:**
- [ ] `grep "_audioService\." lib/presentation/bloc/recording/recording_bloc_lifecycle.dart` — elenca tutti i metodi chiamati
- [ ] Creare `i_audio_recording_repository.dart` con esattamente i metodi usati dal BLoC
- [ ] `RecordingServiceRepository implements IAudioRecordingRepository`
- [ ] Nel DI: `sl.registerSingleton<IAudioRecordingRepository>(sl<RecordingServiceRepository>())`
- [ ] Nel `RecordingBloc`: sostituire `IAudioServiceRepository _audioService` con `IAudioRecordingRepository _audioService`
- [ ] `dart analyze` → 0 errori nuovi

**Rischio:** medio — tocca DI + BLoC. Fare per ultimo.

---

## Task 6 — Estrarre init logic da `main.dart`

**File da creare:**
- `lib/config/app_initializer.dart`

**File da modificare:**
- `lib/main.dart`

**Cosa fare:**
- [ ] Creare `AppInitializer` con metodo statico `Future<void> initialize()` che esegue in ordine: DatabaseHelper → setupDependencies → altri init
- [ ] `main()` diventa: `await AppInitializer.initialize(); runApp(WavNoteApp());`
- [ ] Se `main.dart` rimane sopra 200 righe: estrarre `WavNoteApp` in `lib/app.dart`
- [ ] `dart analyze` → 0 errori nuovi

**Rischio:** basso — pura estrazione senza modifica logica.

---

## Ordine di esecuzione

```
Task 2  (rimozione dead code, nessun rischio)
Task 3  (fix stile Either, logica invariata)
Task 6  (estrazione init, basso rischio)
Task 4  (split file, medio)
Task 5  (split interfaccia, medio — fare per ultimo)
```

---

## Stima

| Task | Tempo | Rischio |
|------|-------|---------|
| 2 — AudioPlayerService + CacheManager | 20 min | 🟢 |
| 3 — Either→Exception | 30 min | 🟢 |
| 4 — Split lifecycle/overdub | 45 min | 🟡 |
| 5 — Split IAudioServiceRepository | 60 min | 🟡 |
| 6 — main.dart init | 20 min | 🟢 |
| **Totale** | **~3 ore** | |

_Aggiornato: 2026-04-26_
