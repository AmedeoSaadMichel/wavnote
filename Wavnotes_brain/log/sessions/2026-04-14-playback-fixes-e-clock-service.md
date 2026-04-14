# Session — 2026-04-14 — Playback fixes post-completamento + RecordingClockService

| Campo | Valore |
|-------|--------|
| **Data** | 2026-04-14 |
| **Durata** | ~90 min |
| **Branch** | `main` |

## Task
- [x] Fix `_onStopRecordingPreview`: fallback path non aggiornava `finalDuration`
- [x] Fix guard in `_onUpdateSeekBarIndex`: eventi `isFromPlayback` in coda sovrascrivevano il seekBarIndex finale
- [x] Fix `_seekLabel` in fullscreen view: usava `waveData.length*100` invece di `max(waveMs, elapsedMs)`
- [x] Fix `externalSeekBarIndex`: clamp a `waveData.length - 1` per evitare playhead oltre la waveform
- [x] Aggiunto `buildWhen` al BlocBuilder del bottom sheet per ridurre rebuild inutili
- [x] Implementato `RecordingClockService` come coordinatore del timer di durata

## Decisioni prese
- **RecordingClockService come coordinatore puro**: estratto solo il `_durationTimer` dal BLoC in un servizio dedicato che espone `durationStream`. I timer di ampiezza e posizione rimangono in AudioEngineService (già ben incapsulati).
  - Perché: ridurre le responsabilità del BLoC senza rompere l'architettura esistente; single-responsibility sul lifetime del timer.
- **RecordingClockService istanziato nel BLoC (non DI)**: dipende da `IAudioServiceRepository` già iniettato; crearlo inline evita un'entrata in DI per un helper interno al BLoC.
- **Guard `isFromPlayback`**: eventi `UpdateSeekBarIndex(isFromPlayback: true)` già in coda nell'event loop venivano processati DOPO che `_onStopRecordingPreview` aveva già emesso il seekBarIndex finale corretto, sovrascrivendolo. Il guard blocca questi eventi se `!s.isPlayingPreview`.

## File modificati
| File | Tipo modifica |
|------|--------------|
| `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart` | bugfix (guard isFromPlayback + finalDuration nel fallback) |
| `lib/presentation/screens/recording/recording_list_screen.dart` | refactor (buildWhen su BlocBuilder bottom sheet) |
| `lib/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart` | bugfix (_seekLabel usa max + clamp externalSeekBarIndex) |
| `lib/presentation/bloc/recording/recording_bloc.dart` | refactor (usa RecordingClockService al posto di _durationTimer) |
| `lib/services/audio/recording_clock_service.dart` | feature (nuovo file — coordinatore timer durata) |

## Next
- [ ] Verificare comportamento seek label dopo playback su device reale
- [ ] Valutare se esporre `startAmplitudeUpdates` / `stopAmplitudeUpdates` pubblici in AudioEngineService per unificare tutti i timer nel coordinatore

## Stato Sistema
- Tech debt: nessuna nuova voce aggiunta
- Riferimento principale: [[_index]]
