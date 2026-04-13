# WavNote — Tech Debt & TODO

_Aggiorna a fine sessione se aggiungi o risolvi un item._

## TODO aperti nel codice

| # | File | Riga | Descrizione | Priorità |
|---|------|------|-------------|---------|
| 1 | `main.dart` | 89 | `SwiftLogChannelService` attivo — rimuovere prima del rilascio in produzione | 🔴 Alta |
| 2 | `main.dart` | 258 | Bottone "Retry" nella error screen non funzionale (nessuna logica implementata) | 🟡 Media |
| 3 | `recording_list_logic.dart` | 617 | `TODO: Implement rewind 10 seconds` — funzione non implementata | 🟡 Media |
| 4 | `recording_list_logic.dart` | 622 | `TODO: Implement forward 10 seconds` — funzione non implementata | 🟡 Media |
| 5 | `recording_list_logic.dart` | 627 | `TODO: Implement seek to position (0.0-1.0)` — seek da UI non implementato | 🟡 Media |

## Workaround architetturali noti

| Area | Workaround | Motivazione / Note |
|------|-----------|-------------------|
| Audio iOS/macOS | `AudioRecorderService` (package `record`) mantenuto commentato come fallback | AVAudioEngine nativo preferito; il codice record è documentato con `// mantenuto come fallback` |
| Playback durante overdub | `_nativePlaybackActive` + `_nativeCompletionTimer` nel coordinator | Gestione manuale del completamento playback durante registrazione in pausa |
| ID recording | `DateTime.now().millisecondsSinceEpoch.toString()` | Nessun UUID — rischio collisione in scenari ad alta frequenza teoricamente possibile |
| Router asincrono | `FutureBuilder<GoRouter>` in `WavNoteApp.build()` | GoRouter creato async; stato stored in `_routerFuture` per evitare ricreazione |
| Tag UI | Modello `RecordingEntity.tags` completo, UI da verificare | Entity e DB pronti, non verificato se l'UI espone i tag all'utente |

## File uncommitted (da git status)

| File | Stato | Note |
|------|-------|------|
| `ios/Runner.xcodeproj/project.pbxproj` | Modificato | Probabilmente legate al setup AVAudioEngine / SwiftLogPlugin |
| `ios/SwiftLogPlugin.swift` | Eliminato | Bridge Swift era nativo, ora gestito diversamente |
| `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart` | Modificato | Refactoring lifecycle in corso |
| `lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart` | Modificato | UI bottom sheet in corso |
