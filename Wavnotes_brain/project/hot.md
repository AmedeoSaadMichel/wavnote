# WavNote — Hot Cache

> Cache operativa breve. Lo storico va in `log/sessions/`; gli elementi aperti vanno in `project/tech-debt.md`.

## Stato corrente

- Branch attivo: `feature/ui-dynamic-island`.
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
- Fix 2026-05-03: `RecordingCancelled` ora ricarica la lista della cartella corrente come `RecordingCompleted`; dopo `x`/cancel dalla Live Activity, il rientro dall’isola non lascia più la schermata senza lista aggiornata.
- Fix 2026-05-03: dopo stop/salvataggio da Dynamic Island, il bottom sheet Flutter resettava solo con `sessionCounter`; ora azzera `_waveData` e allinea il contatore campioni quando parte una nuova registrazione reale, evitando che riusi la waveform precedente.
- Debug temporaneo Live Activity: restano log nativi `LIVE_ACTIVITY` su sample append/update request e `LIVE_ACTIVITY_CONTROLLER` su start/update ActivityKit; rimossi probe e logger waveform dalla widget extension.
- Waveform interna: rimosso floor artificiale `0.08`; sotto soglia `0.03` il segnale viene trattato come silenzio e disegnato a 1px.
- Waveform interna live: fix offset iniziale. Durante recording attivo, la barra registrata più recente viene ancorata al playhead/centro anche con waveform corta; niente più partenza dal bordo sinistro.
- Analisi 2026-05-02: individuata discrepanza waveform oltre 100s. La durata nativa/BLoC arriva correttamente a 111.3s, ma la UI clampa `expectedBars` a `_maxWavePoints=1000`; piano di fix in `analysis/plans/2026-05-02-waveform-long-recording-timeline.md`.
- Obsidian cleanup avviato: `hot.md` è working memory; storico spostato in `log/sessions/2026-04-30-hot-eviction-live-activity-waveform.md`.
- Restano modifiche locali non correlate in `.claude/settings.local.json` e `.obsidian/`.

## Prossimo step

1. Test device iOS 17+: recording → Dynamic Island/Lock Screen → background 60s → pause/resume ripetuti da Dynamic Island extended → stop/cancel → foreground → verificare stato UI, database, durata file, assenza di doppio stop e assenza di nuovi `NSOSStatusErrorDomain Code=560557684`.
2. Validare nuova registrazione dopo stop da Dynamic Island: al primo tick deve comparire `recordedBars=0/1`, non il valore della registrazione precedente.
3. Validare sul device i bucket nativi: nei log cercare `BLoC waveform buckets`, verificare che dopo foreground `pendingAmp` sia vicino a `barsToAdd` e che la waveform non venga stirata.
4. Test device iOS 16.1: controlli visuali fallback non interattivi, Live Activity start/update/end senza regressioni.
5. Applicare il piano `analysis/plans/2026-05-02-waveform-long-recording-timeline.md`: separare indici assoluti della timeline dal buffer visuale limitato a 1000 barre.
6. Raccogliere log `DEBUG file su disco` per debug preview overdub e chiudere/rimuovere log temporanei.
7. Applicare il piano `analysis/plans/2026-04-30-ai-context-token-efficiency.md`: ridurre `_index.md`, creare eventuale archivio analisi, mantenere `hot.md` sotto 900 parole.
8. Dopo validazione device, aggiornare `project/features.md` e ripulire `project/tech-debt.md`.

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
