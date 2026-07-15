# Divergenza registrazione iOS vs macOS — 2026-07-15

Confronto tra `ios/Runner/AudioEnginePlugin*.swift` (4 file, ~1900 righe) e `macos/Runner/AudioEnginePlugin.swift` (1244 righe, fork del plugin iOS mai riallineato). Il lato Dart è **condiviso** tra le due piattaforme (`_useNativeEngine => Platform.isIOS || Platform.isMacOS`), quindi ogni metodo/evento che manca sul plugin macOS produce comportamento diverso senza errori visibili (i catch Dart degradano in silenzio).

## Divergenze trovate (ordinate per impatto)

### 1. 🔴 `getRecordingStatus` non implementato su macOS → desync di stato
- Dart lo chiama in `AudioServiceCoordinator.getCurrentRecordingDuration()` e in `syncNativeRecordingStatus()` (audio_service_coordinator.dart:300, :310).
- `syncNativeRecordingStatus` è triggerato da `RecordingLifecycleService` ad ogni `AppLifecycleState.resumed` — su macOS scatta anche quando la finestra riprende il focus.
- Su macOS il method channel risponde `FlutterMethodNotImplemented` → il catch in `AudioEngineService.getRecordingStatus()` (audio_engine_service.dart:155) ritorna `AudioEngineRecordingStatus.idle()`.
- `syncRecordingStatusFromNative(idle)` marca `_isRecording=false` e azzera `_currentRecordingPath`; il coordinator azzera `_iosNativeActive` e chiude lo stream ampiezze — **mentre nativamente la registrazione continua**. Risultato: UI/BLoC che si "dimenticano" della registrazione in corso al cambio focus finestra.

### 2. 🔴 `waveformBuckets` mai emessi su macOS
- Il `ClockStreamHandler` macOS ha solo `sendRecordingTick`/`sendPlaybackTick`; manca `sendWaveformBuckets` e tutta la bucket logic nel tap (presente su iOS in `AudioEnginePlugin+Recording.swift`: `appendWaveformBucketSample`, `flushWaveformBucket`, `consumePendingWaveformBuckets`).
- Il BLoC costruisce `waveformAmplitudeSamples` **solo** dai bucket (`_onUpdateRecordingWaveformBuckets`). Su macOS resta vuoto → waveform da bucket (catch-up, stato pausa, preview assembly) assente; sopravvive solo l'ampiezza live del `recordingTick`.

### 3. 🔴 Posizione non cumulativa dopo pause/resume su macOS
- macOS: `positionMs = audioFile.length / sampleRate` — solo il **segmento corrente** (AudioEnginePlugin.swift:388). Dopo un resume il file è nuovo → il tick riparte da ~0.
- iOS: `totalFrames = framesInPreviousSegments + framesWrittenThisSegment` — cumulativo attraverso i segmenti.
- Effetto: su macOS timer/durata mostrati sbagliati dopo la prima pausa.

### 4. 🟡 `initialElapsedMs` ignorato su macOS
- Dart lo invia sempre in `startRecording` (audio_engine_service.dart:291); il handler macOS non lo legge. Usato su iOS per l'offset visuale overdub/seek-and-resume. L'overdub su macOS parte con elapsed visuale a 0.

### 5. 🟡 Nessun interruption/lifecycle handling nativo su macOS
- iOS: observer `AVAudioSession.interruptionNotification` (auto-pausa con chiusura segmento) + observer background/foreground con restart engine e riconfigurazione session.
- macOS: nessun observer. Cambio device audio (es. stacco cuffie/mic USB) o sleep possono fermare l'engine senza auto-pausa né recovery.

### 6. ⚪ Differenze strutturali per piattaforma (attese, non bug)
- Niente `AVAudioSession` su macOS (`setAudioSessionCategory` è no-op che ritorna true — ok).
- Niente Live Activity / Dynamic Island / `liveActivityControlCompleted` / `getPendingLiveActivityControlCompleted` (il Dart li gestisce con catch → null, ok).
- Permessi: macOS via `AVCaptureDevice` (`checkMicPermission`/`requestMicPermission`, gestiti da `PermissionService` con branch `Platform.isMacOS` — ok).

## Perché è successo
Il plugin macOS è un fork del plugin iOS pre-ADR clock cumulativo e pre-bucket nativi (2026-05-03): le evoluzioni successive (frames cumulativi, bucket waveform, getRecordingStatus per il reconcile) sono state applicate solo a iOS.

## Fix suggeriti (in ordine)
1. Implementare `getRecordingStatus` su macOS (banale: stessi campi, durata da frame cumulativi del punto 3).
2. Portare `framesInPreviousSegments`/`framesWrittenThisSegment` su macOS per posizione cumulativa.
3. Portare la bucket logic waveform (è autocontenuta in ~60 righe del tap iOS).
4. Leggere `initialElapsedMs` (anche solo per parcheggiarla finché non serve).
5. Valutare observer per cambio device audio/sleep su macOS.

Link: [[project/tech-debt]] · [[project/hot]] · [[_index]]
