# WavNote — Hot Cache

> Cache operativa breve. Lo storico va in `log/sessions/`; gli elementi aperti vanno in `project/tech-debt.md`.

## Stato corrente

- Risanamento test 2026-07-14 COMPLETATO su branch `test/triage-test-falliti`: suite da 239/44 a **279 verdi / 0 falliti / 4 skip documentati**; analyzer invariato (47 issue). Dettagli e decisioni in `analysis/2026-07-14-triage-test-falliti.md`. Unica modifica a lib/: `recording_controls.dart` ignora il tap play/pause durante il loading. Falsi allarmi chiariti: touch target ok (56px reali, il test misurava il glifo), import settings ok (test usava indice enum sbagliato). Contratto confermato dall'utente: `stoppedSeekBarIndex` sempre applicato su StopRecordingPreview, anche natural completion. Decisioni aperte dietro i 4 skip: implementare o rimuovere FilterFolders/SortFolders (eventi senza handler); MainScreen deve mostrare gli stati RecordingError? Modifiche NON committate.
- Fix signing iOS 2026-07-13: Bundle Identifier della Live Activity allineato al prefisso dell'app (`com.amedeosaadmichel.wavnote.liveactivity`), dopo la modifica del Bundle ID principale eseguita in Xcode.
- UI 2026-07-13: slider della recording card interpolato per 120 ms tra i tick di posizione; l'onda decorativa ora scorre senza inversione ping-pong. Drag immediato invariato.
- Analisi 2026-07-11: `flutter analyze` rileva 47 issue (14 warning, 33 info), senza errori di compilazione; suite completa 239 test, 195 verdi e 44 falliti, soprattutto widget/integration test non riallineati alla UI corrente. Dettagli in `analysis/2026-07-11-analisi-progetto.md`.
- Branch attivo: `feature/renew-ui`.
- `main` remoto aggiornato a `f7fc5fe` con background recording + Live Activity prima tranche.
- Dynamic Island audio-driven waveform implementata: ActivityKit riceve `amplitudeSamples` + `waveformRevision`, ring buffer nativo fresco da 24 campioni e rendering SwiftUI interpolato su compact, expanded e Lock Screen; snapshot ora ~250ms, sample nativo ~35ms.
- Check 2026-05-01: Dynamic Island compact/expanded ricollegata a `MiniWaveView`, quindi usa `amplitudeSamples` + `waveformRevision` come la Lock Screen. Restano da validare su device iOS reale silenzio/parlato/pausa.
- Rifinitura 2026-05-01: `MiniWaveView` ora usa il `tick` del `TimelineView` per interpolare/scorrere i campioni reali in modo continuo tra update ActivityKit, con pausa congelata.
- Cambio 2026-05-01: waveform rimossa da Dynamic Island compact/expanded; Lock Screen mantiene la waveform e aggiunge i controlli pause/resume/stop/cancel come extended.
- Piano 2026-05-01 creato: `analysis/plans/2026-05-01-dynamic-island-control-latency.md` per ridurre la latenza dei controlli Dynamic Island tramite misurazione, feedback ActivityKit ottimistico e possibile percorso nativo diretto pause/resume.
- Piano latenza completato per i controlli esposti: `pause/resume/stop/cancel` da Dynamic Island passano direttamente dal plugin Swift; Dart riceve `liveActivityControlCompleted` solo per riallineare UI/database.
- Review latenza: fixati i due P1. `AudioEngineService` sincronizza i flag locali su completed e il lifecycle foreground reconcile riemette completed se l'evento Dynamic Island è stato perso.
- Patch 2026-05-03: gli AppIntent restituiscono errore se il dispatch fallisce; `stop` nativo invia `path/duration` a Flutter, che finalizza `RecordingEntity` e salvataggio senza richiamare il comando nativo; `cancel` nativo riallinea Flutter con stato cancellato. Aggiunto pending completed nativo consumabile al foreground se l'EventChannel era sospeso.
- Follow-up 2026-05-03: `stop` da Dynamic Island ora aspetta il completamento reale di `stopRecording` tramite continuation prima di far chiudere l'AppIntent; niente più successo anticipato prima di `path/duration`.
- Follow-up 2026-05-03: su device reale il `resume` da Dynamic Island può fallire in background con `NSOSStatusErrorDomain Code=560557684`; `resumeRecordingFromLiveActivity()` ora fa retry asincrono breve e pulisce eventuale segmento parziale. `handleDidEnterBackground` non riconfigura più `AVAudioSession` quando `isRecording=true`, anche se in pausa.
- Piano 2026-05-03 creato: `analysis/plans/2026-05-03-waveform-background-native-buckets.md` per allineare waveform live e durata usando bucket ampiezza nativi da 100ms invece del catch-up Flutter basato su campioni non temporizzati.
- Implementazione 2026-05-03: prima tranche bucket nativi completata. Swift emette `waveformBuckets` da frame reali, Dart li espone come `RecordingWaveformBucketBatch`, il BLoC li usa per `waveformAmplitudeSamples`; pausa manuale mantiene lo stream fino al flush finale. Build iOS debug OK, analyzer senza errori nuovi.
- UI 2026-05-03: rimossa definitivamente la mini waveform dalla Live Activity Lock Screen e dalla Dynamic Island expanded; eliminati anche `MiniWaveView`, probe e logger waveform dalla widget extension.
- UI 2026-05-03: sostituito l'occhio della Live Activity/Dynamic Island con il record pupil button in stile bottom sheet; pupilla dilatata in registrazione e chiusa in pausa.
- UI 2026-05-04: allineate larghezza e altezza del bottone `Edit/Done` al chip formato `WAV` negli header main e lista registrazioni.
- UI 2026-05-07: card registrazione salvata aggiornata solo su slider e bottone play centrale usando il riferimento `Recording Card Final`; resto layout invariato.
- UI 2026-05-07: animazione dello slider card resa ping-pong/ease-in-out, evitando lo scatto quando l'onda arriva in alto.
- Fix playback 2026-05-07: pause/play ripetuto nella card salvata non riparte più da zero; `AudioEnginePlaybackAdapter` conserva la posizione corrente alla pausa e riallinea la posizione locale al seek.
- Fix 2026-05-03: `RecordingCancelled` ora ricarica la lista della cartella corrente come `RecordingCompleted`; dopo `x`/cancel dalla Live Activity, il rientro dall’isola non lascia più la schermata senza lista aggiornata.
- Fix 2026-05-03: dopo stop/salvataggio da Dynamic Island, il bottom sheet Flutter resettava solo con `sessionCounter`; ora azzera `_waveData` e allinea il contatore campioni quando parte una nuova registrazione reale, evitando che riusi la waveform precedente.
- Debug temporaneo Live Activity: restano log nativi `LIVE_ACTIVITY` su sample append/update request e `LIVE_ACTIVITY_CONTROLLER` su start/update ActivityKit; rimossi probe e logger waveform dalla widget extension.
- Waveform interna: rimosso floor artificiale `0.08`; sotto soglia `0.03` il segnale viene trattato come silenzio e disegnato a 1px.
- Waveform interna live: fix offset iniziale. Durante recording attivo, la barra registrata più recente viene ancorata al playhead/centro anche con waveform corta; niente più partenza dal bordo sinistro.
- Analisi 2026-05-02: individuata discrepanza waveform oltre 100s. La durata nativa/BLoC arriva correttamente a 111.3s, ma la UI clampa `expectedBars` a `_maxWavePoints=1000`; piano di fix in `analysis/plans/2026-05-02-waveform-long-recording-timeline.md`.
- Obsidian cleanup avviato: `hot.md` è working memory; storico spostato in `log/sessions/2026-04-30-hot-eviction-live-activity-waveform.md`.
- Restano modifiche locali non correlate in `.claude/settings.local.json` e `.obsidian/`.
- Analisi generale 2026-07-08: progetto in buono stato, vedi `analysis/2026-07-08-analisi-generale-progetto.md`. Punti chiave: lavoro UI renew-ui uncommitted da committare, 348 `print()` da ripulire pre-release, hot.md era fermo da ~2 mesi.
- Analisi 2026-07-09: copertura test vs feature, vedi `analysis/2026-07-09-test-coverage-vs-features.md`. Core storico coperto bene; zero test su lifecycle Dynamic Island, bucket nativi, AudioEnginePlaybackAdapter e renew-ui; `folder_repository_test` e `recording_workflow_test` testavano mock (valore ~zero).
- Test 2026-07-09: aggiunta dev dependency `sqflite_common_ffi`; `test_helpers.dart` ora inizializza SQLite ffi con directory DB unica per isolate (i file di test girano in parallelo). `folder_repository_test` riscritto contro FolderRepository reale (23 test). `recording_repository_test` riparato: era marcito (26/27 falliti, API vecchia bool vs Either) → 27/27 verdi. Nuovo `audio_engine_playback_adapter_test.dart` (9 test): 8 verdi, 1 rosso volutamente.
- Fix 2026-07-09 (confermato utente): rimossa `_currentPosition = position;` da `seek()` in `audio_engine_playback_adapter.dart`. La riga rendeva sempre falso `shouldRestartFromSeek` in `play()` → seek in pausa + play riprendeva dalla posizione nativa pre-seek. Il fix pause/play del 2026-05-07 resta intatto (`pause()` cachea la posizione; `seek()` emette subito sullo stream per la UI). `audio_engine_playback_adapter_test.dart` ora 9/9 verdi. Da validare a orecchio sul device: pausa → slider → play nella card salvata.
- Nota comportamento repo: `getAllRecordings()` volutamente NON filtra i soft-deleted (usata solo da debug handler e waveform service); il filtro utente è in `getRecordingsByFolder`.

- Analisi qualità test 2026-07-14: `analysis/2026-07-14-analisi-qualita-test.md`. Sintesi: ~180/286 casi proteggono davvero; geolocation_service_test è quasi tutto facciata (mock definiti mai usati, 47 assert isA<String>); zero verify() nei bloc test; buchi invariati su lifecycle Dynamic Island, bucket nativi e Swift (zero XCTest). Priorità: gate CI subito, poi test lifecycle e bucket, poi bonifica del teatro.

## Prossimo step

1. Test device iOS 17+: recording → Dynamic Island/Lock Screen → background 60s → pause/resume ripetuti da Dynamic Island extended → stop/cancel → foreground → verificare stato UI, database, durata file, assenza di doppio stop e assenza di nuovi `NSOSStatusErrorDomain Code=560557684`.
2. Validare nuova registrazione dopo stop da Dynamic Island: al primo tick deve comparire `recordedBars=0/1`, non il valore della registrazione precedente.
3. Validare sul device i bucket nativi: nei log cercare `BLoC waveform buckets`, verificare che dopo foreground `pendingAmp` sia vicino a `barsToAdd` e che la waveform non venga stirata.
4. Test device iOS 16.1: controlli visuali fallback non interattivi, Live Activity start/update/end senza regressioni.
5. Applicare il piano `analysis/plans/2026-05-02-waveform-long-recording-timeline.md`: separare indici assoluti della timeline dal buffer visuale limitato a 1000 barre.
6. Implementare Live Activity / Dynamic Island per playback: preview file e ascolto registrazione a schermo chiuso/bloccato, con controlli player separati dalla registrazione.
7. Raccogliere log `DEBUG file su disco` per debug preview overdub e chiudere/rimuovere log temporanei.
8. Applicare il piano `analysis/plans/2026-04-30-ai-context-token-efficiency.md`: ridurre `_index.md`, creare eventuale archivio analisi, mantenere `hot.md` sotto 900 parole.
9. Dopo validazione device, aggiornare `project/features.md` e ripulire `project/tech-debt.md`.

## Decisioni recenti

- Eviction policy Obsidian: completato/storico → `log/sessions/`; aperto/actionable → `project/tech-debt.md`; piano/root cause → `analysis/`; decisione stabile → `project/adr/`.
- `CLAUDE.md` / `AGENTS.md` restano memoria procedurale e regole invarianti; non devono contenere storico di feature.
- Live Activity non deve ricevere update audio ad alta frequenza: usare snapshot compatti e animazione SwiftUI leggera.
- Rifinitura UI: Dynamic Island expanded ripristinata su background nero nativo; waveform Live Activity in ciano `0xFF00BCD4`, timer giallo, snapshot ActivityKit ~250ms + testina live locale sulle ultime 6 barre.
- Debug corrente: pipeline nativa confermata viva (`update completed`, `rev` crescente). Dopo test senza movimento su simulatore e iPhone reale, Dynamic Island compact/expanded riportata a una waveform sintetica semplice separata (`DynamicIslandAnimatedWaveView`) come nel commit `f7fc5fe`; update ActivityKit riportato a 1s e `start()` chiude tutte le Live Activity WavNote stale prima di richiederne una nuova.
- Durante recording attivo non riconfigurare `AVAudioSession` nei callback background/foreground.

## File caldi

- `ios/WavNoteLiveActivityExtension/WavNoteLiveActivityWidget.swift` — rendering Live Activity e Dynamic Island.
- `ios/Runner/AudioEnginePlugin+Recording.swift` — tap audio, ring buffer ampiezze e update ActivityKit.
- `ios/Shared/WavNoteRecordingControlIntents.swift` — AppIntent dei controlli Dynamic Island.
- `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart` — reconcile Flutter per completed pause/resume/stop/cancel nativi.
- `ios/Shared/WavNoteRecordingAttributes.swift` — stato serializzato Live Activity.
- `ios/Runner/WavNoteLiveActivityController.swift` — start/update/end ActivityKit.
- `Wavnotes_brain/project/tech-debt.md` — backlog actionable.

## Link caldi

- [[log/sessions/2026-04-30-hot-eviction-live-activity-waveform]]
- [[analysis/plans/2026-04-30-dynamic-island-audio-driven-waveform]]
- [[analysis/plans/2026-05-01-dynamic-island-control-latency]]
- [[analysis/plans/2026-05-03-waveform-background-native-buckets]]
- [[analysis/plans/2026-05-02-waveform-long-recording-timeline]]
- [[analysis/plans/2026-04-30-ai-context-token-efficiency]]
- [[analysis/plans/2026-04-29-waveform-background-catchup]]
- [[project/tech-debt]]
- [[_index]]
