# Piano — Riduzione latenza controlli Dynamic Island

_Data: 2026-05-01_  
_Stato: proposta, nessuna modifica di logica autorizzata_  
_Area: Live Activity / Dynamic Island / AppIntents / Recording BLoC_

## Obiettivo

Ridurre la percezione di ritardo quando l'utente preme `PAUSE`, `RESUME`, `STOP` o `CANCEL` dalla Dynamic Island / Live Activity.

Il comportamento desiderato è:

- feedback visivo quasi immediato nella Live Activity;
- audio engine messo in pausa/ripreso/fermato nel modo più diretto possibile;
- Flutter/BLoC riallineato senza perdere la source of truth applicativa;
- nessuna regressione su durata file, preview pausa, waveform interna o background recording.

## Root cause osservata

Dal log del 2026-05-01 il comando parte dalla Dynamic Island e passa da App Intents:

```text
-[WFIsolatedShortcutRunner init] Taking sandbox extensions for execution
...
flutter: ⏸️ PAUSE CALC ...
flutter: SWIFT LOG: ... pauseRecording — isRecording=true isPaused=false
```

Percorso attuale:

```text
Dynamic Island Button
→ LiveActivityIntent
→ WFIsolatedShortcutRunner / AppIntents
→ WavNoteRecordingControlDispatcher
→ AudioEnginePlugin.sendLiveActivityControl
→ EventChannel verso Flutter
→ AudioEngineService.externalControlStream
→ RecordingBloc._onExternalControlAction
→ PauseRecordingUseCase
→ MethodChannel pauseRecording
→ AudioEnginePlugin+Recording.pauseRecording
→ ActivityKit update paused
```

Questa catena aggiunge latenza per tre motivi:

1. App Intents viene eseguito dal sistema e non è un callback Flutter diretto.
2. Il comando rientra in Flutter via `EventChannel`, poi torna a Swift via `MethodChannel`.
3. Nel BLoC lo stato `RecordingPaused` viene emesso dopo `_assemblePreviewFile(...)`, quindi l'UI Flutter può aspettare la preparazione preview.

## Vincoli

- Modifiche a BLoC/use case/repository richiedono autorizzazione esplicita.
- Non aggiungere dipendenze.
- Non usare API private Apple.
- Non fare update ActivityKit ad alta frequenza.
- Non introdurre due source of truth permanenti per lo stato recording.
- Preservare durata corretta del file WAV e chiusura header su pausa.
- Mantenere comportamento idempotente dove applicabile.

## Strategia raccomandata

Implementare un percorso "optimistic native control" solo per comandi provenienti dalla Live Activity.

Idea:

1. Il `LiveActivityIntent` aggiorna subito lo stato ActivityKit in modo ottimistico.
2. Il plugin nativo esegue direttamente `pause/resume/stop/cancel`, senza passare prima da Flutter.
3. Flutter riceve un evento di conferma e aggiorna il BLoC con i dati già prodotti dal nativo.
4. Se il comando fallisce, la Live Activity viene riportata allo stato reale.

Questo mantiene Flutter come source of truth dell'app, ma rimuove il giro inutile:

```text
Intent → Flutter → MethodChannel → Swift
```

e lo sostituisce con:

```text
Intent → Swift audio engine → Flutter sync event
```

## Piano operativo

### Fase 1 — Misurazione esplicita della latenza

File:

- `ios/Shared/WavNoteRecordingControlIntents.swift`
- `ios/Runner/AudioEnginePlugin.swift`
- `ios/Runner/AudioEnginePlugin+Recording.swift`
- `lib/services/audio/audio_engine_service.dart`
- `lib/presentation/bloc/recording/recording_bloc.dart`

Azioni:

- Aggiungere timestamp/log temporanei ai punti della catena:
  - tap intent ricevuto;
  - dispatch verso plugin;
  - evento ricevuto da Dart;
  - evento BLoC aggiunto;
  - ingresso use case;
  - ingresso metodo nativo `pauseRecording`;
  - `activity.update` completato.

Verifica:

- ottenere un log con delta approssimativi tra ogni step;
- capire se il grosso del ritardo è AppIntents, bridge Flutter o preview assembly.

Rischio:

- solo rumore di log, basso.

### Fase 2 — Feedback ActivityKit immediato

File:

- `ios/Runner/WavNoteLiveActivityController.swift`
- `ios/Shared/WavNoteRecordingControlIntents.swift`

Azioni:

- Aggiungere un metodo nativo leggero, per esempio:

```swift
func markPausedOptimistically()
func markRecordingOptimistically()
```

- Da `WavNotePauseRecordingIntent.perform()` chiamare subito l'update ottimistico prima del dispatch Flutter.
- Per `resume`, fare l'opposto.
- Per `stop/cancel`, mostrare stato visivo coerente o disabilitare/chiudere appena possibile.

Verifica:

- il badge `PAUSED/REC` cambia quasi subito anche se Flutter impiega più tempo;
- se il comando nativo fallisce, lo stato Live Activity torna coerente.

Rischio:

- stato visuale temporaneamente divergente se la pausa fallisce.
- Mitigazione: rollback su errore o update successivo dallo stato reale.

### Fase 3 — Esecuzione nativa diretta dei comandi

File:

- `ios/Shared/WavNoteRecordingControlIntents.swift`
- `ios/Runner/AudioEnginePlugin.swift`
- `ios/Runner/AudioEnginePlugin+Recording.swift`

Azioni:

- Esporre sul plugin un metodo dedicato per comandi Live Activity:

```swift
func handleLiveActivityControl(action: String)
```

- Per `pause`:
  - controllare `isRecording && !isPaused`;
  - chiamare una variante interna di `pauseRecording` che non dipende da `FlutterResult`;
  - aggiornare Live Activity subito;
  - inviare a Flutter un evento `liveActivityControlCompleted` con durata, action e success/failure.

- Per `resume`:
  - controllare `isRecording && isPaused`;
  - chiamare la logica nativa di resume;
  - aggiornare Live Activity;
  - inviare conferma a Flutter.

- Per `stop/cancel`:
  - valutare se eseguire subito nativamente o lasciare a Flutter, perché stop/cancel toccano salvataggio, repository e lista.
  - raccomandazione iniziale: ottimizzare prima solo `pause/resume`.

Verifica:

- log mostra ingresso in `pauseRecording` quasi subito dopo `perform()`;
- la registrazione si ferma anche se Flutter è in background o più lento;
- nessun doppio pause quando Flutter riceve la conferma.

Rischio:

- alta attenzione: si sposta una parte del comando fuori dal BLoC.
- Serve progettare bene l'evento di riallineamento per non duplicare pausa/resume.

### Fase 4 — Riallineamento BLoC senza doppia esecuzione

File:

- `lib/domain/entities/recording_external_control_action.dart`
- `lib/services/audio/audio_engine_service.dart`
- `lib/presentation/bloc/recording/recording_bloc.dart`
- `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart`

Azioni:

- Distinguere eventi:

```text
liveActivityControlRequested
liveActivityControlCompleted
```

- Per `pause/resume` completati dal nativo, il BLoC non deve richiamare `PauseRecordingUseCase.executePause()` o `executeResume()`.
- Aggiungere eventi BLoC dedicati, per esempio:

```dart
ExternalRecordingPaused(nativeDuration: ...)
ExternalRecordingResumed(...)
```

- Costruire lo stato Dart usando i dati nativi già confermati.
- Mantenere `_assemblePreviewFile` come step separato e non bloccante per l'emissione base dello stato paused.

Verifica:

- un solo comando nativo per tap;
- `RecordingPaused` appare subito;
- preview file arriva dopo senza bloccare feedback;
- waveform interna resta allineata.

Rischio:

- questa fase tocca BLoC e quindi richiede autorizzazione esplicita.

### Fase 5 — Rendere `_assemblePreviewFile` non bloccante

File:

- `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart`

Problema attuale:

```dart
final previewPath = await _assemblePreviewFile(pausedState);
emit(pausedState.copyWith(previewFilePath: previewPath));
```

Azioni:

- Emettere subito `RecordingPaused(..., previewFilePath: null)`.
- Avviare `_assemblePreviewFile` in background.
- Quando pronto, emettere una copia aggiornata con `previewFilePath`.

Verifica:

- la UI passa a pausa subito;
- il playback preview compare appena disponibile;
- nessun flicker o regressione nello seek.

Rischio:

- medio: bisogna assicurarsi che la UI gestisca bene `previewFilePath: null`.

### Fase 6 — Test manuali su device/simulatore

Casi minimi:

1. Foreground, tap pausa dalla Dynamic Island.
   - badge passa a `PAUSED` rapidamente;
   - audio smette di registrare;
   - UI Flutter si riallinea.

2. Background, tap pausa dalla Dynamic Island.
   - audio engine pausa;
   - Live Activity aggiorna stato;
   - tornando in app, BLoC mostra stato paused.

3. Tap rapido pause/resume.
   - nessun doppio comando;
   - nessun errore `INVALID_STATE`;
   - durata cumulativa corretta.

4. Stop/cancel da Live Activity.
   - se non ottimizzati in questa fase, verificare che funzionino come oggi.
   - se ottimizzati, verificare salvataggio lista e chiusura Live Activity.

5. Registrazione lunga 60s background.
   - file finale leggibile;
   - durata file coerente;
   - nessuna Live Activity stale.

## Criteri di successo

- Tap su `PAUSE` dalla Dynamic Island produce feedback visivo entro circa 200-500ms su device reale.
- L'audio engine entra in pausa senza aspettare il giro completo Flutter → MethodChannel.
- BLoC resta coerente e non invia comandi duplicati.
- `flutter build ios --debug --no-codesign` passa.
- `dart analyze` passa.
- Nessuna modifica a repository/use case/BLoC senza autorizzazione esplicita.

## Approccio incrementale consigliato

1. Prima implementare solo Fase 1.
2. Se il log conferma il ritardo nel bridge, implementare Fase 2.
3. Se il feedback visivo non basta, implementare Fase 3 e Fase 4 solo per `pause/resume`.
4. Lasciare `stop/cancel` per una sessione separata, perché hanno più rischio su salvataggio e stato lista.

## Fuori scope

- Waveform Dynamic Island.
- Nuove dipendenze.
- API private o comportamento non documentato Apple.
- Refactor generale del BLoC recording.
- Rimozione completa dei log debug già presenti.

## Note Apple / sistema

I bottoni della Live Activity usano `LiveActivityIntent`, quindi passano dal sistema App Intents. Una latenza minima è normale, soprattutto in debug/simulatore.

L'obiettivo realistico non è renderli identici a un bottone Flutter foreground, ma:

- feedback visuale immediato;
- esecuzione nativa più diretta possibile;
- riallineamento Flutter affidabile.

## Implementato il 2026-05-01

Prima tranche applicata su `pause/resume`:

- `LiveActivityIntent` ora chiama `AudioEnginePlugin.handleLiveActivityControl(action:)`.
- `pause` e `resume` vengono eseguiti direttamente nel plugin Swift, senza fare prima il giro `EventChannel → Flutter → MethodChannel`.
- `stop/cancel` restano sul percorso precedente, perché toccano salvataggio e lista.
- Swift invia a Dart un evento `liveActivityControlCompleted` con `action`, `success` e `durationMs`.
- Dart distingue `RecordingExternalControlEvent.requested` da `RecordingExternalControlEvent.completed`.
- Il BLoC non richiama più il use case quando riceve `pause/resume` già completati dal nativo.
- Lo stato `RecordingPaused` viene emesso prima della preview; `_assemblePreviewFile` aggiorna `previewFilePath` dopo.

Verifiche:

- `flutter build ios --debug --no-codesign` passa.
- `dart analyze` non mostra errori bloccanti nuovi, ma resta fallito per 45 warning/info preesistenti nel progetto.

Prossima verifica manuale:

- tap `PAUSE` dalla Dynamic Island su device/simulatore;
- confermare che il log salti il percorso `liveActivityControl requested → PauseRecordingUseCase`;
- confermare che il badge `PAUSED` e la pausa audio arrivino più rapidamente.

## Correzione review 2026-05-01

Applicati i fix ai due finding P1:

- `AudioEngineService` aggiorna i flag locali `_isRecording` / `_isRecordingPaused` quando riceve `liveActivityControlCompleted`.
- `syncNativeRecordingStatus()` usa `getRecordingStatus()` per rilevare divergenze `paused/resumed` e riemettere un evento completed verso il BLoC se l'evento originale è stato perso mentre Flutter era sospeso.
- Il reconcile passa dallo stream esistente di `AudioEngineService`, senza aggiungere un secondo controller nel coordinator.

Verifiche:

- `dart analyze`: nessun errore introdotto; restano 45 warning/info preesistenti.
- `flutter build ios --debug --no-codesign`: passa.

## Link

- [[analysis/plans/2026-04-28-live-activity-dynamic-island]]
- [[analysis/plans/2026-04-30-dynamic-island-audio-driven-waveform]]
- [[project/hot]]
- [[project/features]]
- [[project/tech-debt]]
- [[_index]]
