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
- Debug temporaneo Dynamic Island waveform: log `LIVE_ACTIVITY` su sample append/update request, `LIVE_ACTIVITY_CONTROLLER` su start/update ActivityKit, `LIVE_ACTIVITY_WIDGET` su render/change della widget extension. Probe visibile attivo nella waveform (`showWaveformRevisionProbe = true`): piccolo numero giallo = `waveformRevision`.
- Waveform interna: rimosso floor artificiale `0.08`; sotto soglia `0.03` il segnale viene trattato come silenzio e disegnato a 1px.
- Waveform interna live: fix offset iniziale. Durante recording attivo, la barra registrata più recente viene ancorata al playhead/centro anche con waveform corta; niente più partenza dal bordo sinistro.
- Obsidian cleanup avviato: `hot.md` è working memory; storico spostato in `log/sessions/2026-04-30-hot-eviction-live-activity-waveform.md`.
- Restano modifiche locali non correlate in `.claude/settings.local.json` e `.obsidian/`.

## Prossimo step

1. Test device iOS 16.1+: recording → Dynamic Island/Lock Screen → background 60s → foreground → stop → verificare durata file e waveform audio-driven.
2. Validare pause/resume: waveform Live Activity congelata in pausa e di nuovo reattiva al resume.
3. Raccogliere log `DEBUG file su disco` per debug preview overdub e chiudere/rimuovere log temporanei.
4. Applicare il piano `analysis/plans/2026-04-30-ai-context-token-efficiency.md`: ridurre `_index.md`, creare eventuale archivio analisi, mantenere `hot.md` sotto 900 parole.
5. Dopo validazione device, aggiornare `project/features.md` e ripulire `project/tech-debt.md`.

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
- `ios/Shared/WavNoteRecordingAttributes.swift` — stato serializzato Live Activity.
- `ios/Runner/WavNoteLiveActivityController.swift` — start/update/end ActivityKit.
- `Wavnotes_brain/project/tech-debt.md` — backlog actionable.

## Link caldi

- [[log/sessions/2026-04-30-hot-eviction-live-activity-waveform]]
- [[analysis/plans/2026-04-30-dynamic-island-audio-driven-waveform]]
- [[analysis/plans/2026-05-01-dynamic-island-control-latency]]
- [[analysis/plans/2026-04-30-ai-context-token-efficiency]]
- [[analysis/plans/2026-04-29-waveform-background-catchup]]
- [[project/tech-debt]]
- [[_index]]
