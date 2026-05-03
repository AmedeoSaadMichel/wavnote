# WavNote — Tech Debt & TODO

_Aggiorna a fine sessione se aggiungi o risolvi un item._

## Bug confermati (da analisi 2026-04-26)

| # | Area | Descrizione sintetica | Priorità |
|---|------|-----------------------|---------|
| B1 | Fullscreen bottom sheet | **Sfarfallio play/pause preview**: multiple emissioni BLoC in cascata (`PlayRecordingPreview` → `_updateCardIds` → `UpdateSeekBarIndex` ogni 100ms) + `AnimatedSwitcher` con `FadeTransition` 400ms che risponde ad ogni rebuild. Finestra async in `_playRecordingPreview()` tra emit sincrono e start effettivo del player. | 🟡 Media |
| B2 | Overdub / seek-and-resume | **✅ Risolto 2026-04-26**: Tre fix — (1) `pathToOverwrite` ora usa `baseRecordingEntity.filePath` (WAV nativo) invece di `s.filePath` (estensione logica non esistente su disco); (2) `isSeekResume` usa `!identical` per catturare tutti i seek-resume; (3) `waveformDataForPlayer` aggiunto a `RecordingInProgress.copyWith`. Da verificare su device con M4A/FLAC. | ✅ Risolto |

## TODO aperti nel codice

| # | File | Riga | Descrizione | Priorità |
|---|------|------|-------------|---------|
| 1 | `main.dart` | 89 | `SwiftLogChannelService` attivo — rimuovere prima del rilascio in produzione | 🔴 Alta |
| 2 | `main.dart` | 258 | Bottone "Retry" nella error screen non funzionale (nessuna logica implementata) | 🟡 Media |
| 3 | `recording_list_logic.dart` | 627 | `TODO: Implement seek to position (0.0-1.0)` — seek da UI non implementato | 🟡 Media |
| 4 | `lib/presentation/bloc/recording/recording_bloc.dart` | 159 | Rimuovere log di debug `🔍 BLoC received amplitude: ...` dopo aver verificato il corretto funzionamento | 🟢 Bassa |
| 5 | `recording_compact_view.dart` / `recording_bottom_sheet_main.dart` | — | Nessun feedback visivo durante `RecordingStarting` (~3s di AVAudioSession init): l'utente ri-clicca pensando che il tap non sia stato registrato, genera registrazione 0ms e `RecordingError`. Fix: disabilitare il bottone record + mostrare spinner/pulse durante `isStarting`. | 🟡 Media |
| 6 | `lib/presentation/screens/recording/recording_list_screen.dart` | builder fallback su `RecordingStopping` | Durante lo stop della registrazione la lista passa per `RecordingStopping`, ma il builder non gestisce questo stato e mostra temporaneamente `RecordingListSkeleton`. **✅ Risolto 2026-04-24**: Preservata la lista dei file negli stati di transizione (`Starting`, `InProgress`, `Paused`, `Stopping`). | ✅ Risolto |

## Actionable usciti da `hot.md` (2026-04-30)

| # | Area | Descrizione | Priorità |
|---|------|-------------|----------|
| H1 | Live Activity / Dynamic Island | Test device fisico iOS 16.1+: avvio recording → Dynamic Island/Lock Screen → background 60s → foreground → stop. Verificare durata file, timer, controlli e waveform audio-driven. | 🔴 Alta |
| H2 | Dynamic Island audio-driven waveform | Validare che `amplitudeSamples` reagisca a silenzio/parlato e che la pausa congeli la forma senza movimento artificiale. | 🔴 Alta |
| H3 | Recording background lifecycle | Dopo il fix che evita `configureAudioSession` durante recording attivo, verificare su device che `engineRunning=true` e `framesWrittenThisSegment` crescano dopo background/foreground. | 🔴 Alta |
| H4 | Preview overdub | Raccogliere log con `DEBUG file su disco` per capire se il WAV è corto su disco o se è solo calcolo BLoC; poi applicare fix e rimuovere log temporaneo. | 🔴 Alta |
| H5 | Waveform debug temporanei | Rimuovere log `🌊 BLoC waveform buffer count=...`, `🌊 BOTTOM SHEET bloc amp sync ...` e log correlati dopo validazione background/foreground. | 🟡 Media |
| H6 | Obsidian AI context | Applicare `analysis/plans/2026-04-30-ai-context-token-efficiency.md`: `_index.md` router, `hot.md` sotto 900 parole, storico in `log/sessions/`, aperti in `tech-debt.md`. | 🟡 Media |
| H7 | `settings_bloc.dart` | File a 803 righe: supera il limite assoluto del progetto. Richiede conferma esplicita prima di refactor. | 🟡 Media |
| H8 | Test suite | Stabilizzazione completa `test/unit` seguendo `analysis/plans/2026-04-27-piano-risanamento-progetto.md`. | 🟡 Media |
| H9 | `IAudioServiceRepository` | Cleanup finale seguendo `analysis/plans/2026-04-27-cleanup-iaudioservicerepository.md`. | 🟡 Media |

## Workaround architetturali noti (post ADR-001)

| Area | Workaround | Motivazione / Note |
|------|-----------|-------------------|
| Waveform background/foreground | Buffer ampiezze BLoC + UI `_pendingAmplitudeSamples` | iOS può sospendere il rendering Flutter in background; la UI non può disegnare live, quindi recupera al foreground usando le ampiezze ricevute nel BLoC. Il buffer viene preservato anche attraverso pausa/resume per evitare `pendingAmp=0` nei catch-up successivi. Da validare su device: nei log `catchUp=true pendingAmp` dovrebbe essere alto quando `barsToAdd` è alto. |
| Waveform debug temporaneo | Log `🌊 BLoC waveform buffer count=...` e `🌊 BOTTOM SHEET bloc amp sync ...` | Aggiunti per verificare che il fix BLoC sia effettivamente in esecuzione e che il bottom sheet accodi i campioni arrivati in background. Rimuovere dopo validazione. |
| `PlaybackClockTick.totalDuration` su just_audio | Emesso come `Duration.zero` da `_setupPlaybackStreams()` nel coordinator | just_audio non fornisce durata nel position stream; il BLoC attualmente non usa `totalDuration` da `activeClockStream`, ma se UI futura la consuma deve fare workaround. Da risolvere espando l'interfaccia playback. 🟡 Media |
| Posizione cumulativa al resume semplice | `_seekTimeOffsetMs = 0` in bottom sheet: assume che il clock nativo emetta posizioni cumulative dopo pausa/resume | Coerente con l'implementazione Swift (`framesInPreviousSegments` accumulati). Da verificare su dispositivo prima di ritenere chiuso. 🟡 Media — da Step 7 |
| Audio iOS/macOS | `AudioRecorderService` (package `record`) mantenuto commentato come fallback | AVAudioEngine nativo preferito; il codice record è documentato con `// mantenuto come fallback` |
| Playback durante overdub | ~~`_nativePlaybackActive` + `_nativeCompletionTimer`~~ `EventChannel` nativo | ~~Gestione manuale con polling~~ → Sostituito con notifica precisa dal player |
| ID recording | `DateTime.now().millisecondsSinceEpoch.toString()` | Nessun UUID — rischio collisione in scenari ad alta frequenza teoricamente possibile |
| Router asincrono | `FutureBuilder<GoRouter>` in `WavNoteApp.build()` | GoRouter creato async; stato stored in `_routerFuture` per evitare ricreazione |
| Tag UI | Modello `RecordingEntity.tags` completo, UI da verificare | Entity e DB pronti, non verificato se l'UI espone i tag all'utente |
| UI/BLoC | `BlocBuilder` in `RecordingListScreen` con `buildWhen` potenzialmente restrittivo | La condizione `buildWhen` potrebbe bloccare aggiornamenti necessari per il `BottomSheet` (es. `seekBarIndex`). Da raffinare se si ripresentano problemi di UI non reattiva. |
| Logging | Logging di debug in `AudioEnginePlugin.swift` | Aggiunto per diagnosticare il bug del playback. Dovrebbe essere rimosso o reso configurabile prima del rilascio. |
| ~~Timer hierarchy~~ | ~~10 timer Dart concorrenti sul bottom sheet~~ | **✅ Risolto 2026-04-14** via ADR-001: clock push-based nativo end-to-end. `_waveformTimer`, `RecordingClockService`, `_amplitudeTimer`, `_positionTimer` eliminati. `_needsCalibration`/`_seekTimeOffsetMs` (calibrazione wall-clock) rimossi. Da Step 7: verifica posizione cumulativa su dispositivo. |
| Stream Ampiezza (iOS) | Inoltro manuale stream `_engineService` in `AudioServiceCoordinator` | Necessario per collegare il motore nativo AVAudioEngine al BLoC |

## Dead code eliminato (2026-04-14)

| File | Motivo |
|------|--------|
| `lib/presentation/bloc/recording_lifecycle/` (intera cartella) | `RecordingLifecycleBloc` non istanziato da nessuna parte — residuo di refactoring precedente, sostituito da `RecordingBloc` |
| `lib/domain/usecases/recording/recording_lifecycle_usecase.dart` | Referenziato solo dal BLoC morto |
| `test/unit/blocs/recording_lifecycle_bloc_test.dart` | Test del BLoC eliminato |
| `test/unit/usecases/recording_lifecycle_usecase_test.dart` | Test del use case eliminato |

## Nuovi servizi introdotti da refactor `77a722a` (non ancora integrati nel BLoC)

| Area | Nota | Priorità |
|------|------|---------|
| `IAudioPlaybackEngine` / `AudioPlaybackEngineImpl` | **Parzialmente integrato 2026-04-23**: usato da `AudioServiceCoordinator`, `RecordingListScreen` e `PlaybackScreen`. Il BLoC continua comunque a passare da `IAudioServiceRepository`, che ora delega all'engine condiviso. Verificare con test/device il comportamento multi-schermata. | 🟡 Media |
| `IAudioPreparationService` / `AudioPreparationService` | **Parzialmente integrato 2026-04-23**: consumato dal `RecordingPlaybackCoordinator` per list/player/preview bottom sheet. Mancano ancora test unitari dedicati. | 🟡 Media |
| `RecordingPlaybackCoordinator` | **Integrato 2026-04-23** in `RecordingListScreen`, `PlaybackScreen` e preview bottom sheet. Resta da validare manualmente il comportamento quando due schermate osservano lo stesso engine singleton. | 🟡 Media |
| `IAudioServiceRepository` | Contratto ancora “misto”: contiene API playback legacy, ma `RecordingServiceRepository` le espone come non supportate per impedire nuovi usi. Valutare split formale dell'interfaccia in sessione dedicata. | 🟡 Media |

## File uncommitted (da git status)

| File | Stato | Note |
|------|-------|------|
| `ios/Runner.xcodeproj/project.pbxproj` | Modificato | Probabilmente legate al setup AVAudioEngine / SwiftLogPlugin |
| `ios/SwiftLogPlugin.swift` | Eliminato | Bridge Swift era nativo, ora gestito diversamente |
| `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart` | Modificato | Fix playback rotto dopo refactor 2026-04-17 |
| `lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart` | Modificato | UI bottom sheet con sessionCounter |
