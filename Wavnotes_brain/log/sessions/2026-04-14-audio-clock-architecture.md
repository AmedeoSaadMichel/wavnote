# Session — 2026-04-14 — AudioClock architecture & timer cleanup

| Campo | Valore |
|-------|--------|
| **Data** | 2026-04-14 |
| **Durata** | ~90 min |
| **Branch** | `main` |

## Task
- [x] Analisi gerarchia timer attuale (recording + playback + UI)
- [x] Censimento di tutti i `Timer.periodic` Dart e nativi
- [x] Identificazione dead code (`RecordingLifecycleBloc`)
- [x] Eliminazione dead code
- [x] Brainstorming architettura `AudioClock` push-based
- [x] Scrittura ADR definitivo
- [ ] Implementazione Step 1 (Swift EventChannel) — prossima sessione

## Decisioni prese

### 1. Eliminazione `RecordingLifecycleBloc` e relativi file
- **Decisione:** rimossa intera cartella `lib/presentation/bloc/recording_lifecycle/` + use case + test
- **Perché:** dead code — non istanziato in `dependency_injection.dart`, non montato in `main.dart`, zero riferimenti in produzione. Residuo di refactoring precedente da cui è stato estratto `RecordingBloc`.
- **Timer eliminato:** `RecordingLifecycleBloc._durationTimer` (100ms)

### 2. Architettura `AudioClock` push-based nativo end-to-end
- **Decisione:** unificare la gestione temporale audio in un singolo clock guidato da AVAudioEngine, con emissione push via EventChannel. Zero timer Dart.
- **Perché:** l'attuale gerarchia di 10 timer Dart con polling MethodChannel è la causa del drift, della logica di calibrazione UI (`_needsCalibration`, `_seekTimeOffsetMs`) e della complessità del `_waveformTimer`.
- **Dettagli:** vedi [[project/adr/2026-04-14-audio-clock-push-based]]

### 3. Scartata la "minimal invasive" con Stopwatch nel coordinator
- **Decisione:** non si usa `Stopwatch` nel coordinator né si riusa `_amplitudeTimer` esistente
- **Perché:** entrambe le soluzioni mantengono polling MethodChannel pull-based. Il nativo deve essere il clock, non un sottoprodotto del polling Dart. Sample-accurate da `framesWritten / sampleRate`.

## Censimento timer iniziale (pre-cleanup)

| # | Timer | Freq | Layer | Destino |
|---|-------|------|-------|---------|
| 1 | `AudioEngineService._amplitudeTimer` | 50ms | Service | ❌ eliminato (Step 2) |
| 2 | `AudioEngineService._positionTimer` | 100ms | Service | ❌ eliminato (Step 2) |
| 3 | `RecordingClockService._durationTimer` | 100ms | Service | ❌ eliminato (Step 5) |
| 4 | `RecordingLifecycleBloc._durationTimer` | 100ms | BLoC | ✅ **eliminato oggi** (dead code) |
| 5 | `recording_bottom_sheet_main._waveformTimer` | 100ms | UI | ❌ eliminato (Step 6) |
| 6 | `AudioRecorderService._amplitudeMonitoringTimer` | — | Service (fallback) | Mantenuto (non-iOS) |
| 7 | `AudioRecorderService._durationMonitoringTimer` | — | Service (fallback) | Mantenuto (non-iOS) |
| 8 | `AudioMonitoringService._amplitudeTimer` | — | Service impl | Da verificare utilizzo |
| 9 | `AudioMonitoringService._durationTimer` | 1s | Service impl | Da verificare utilizzo |
| 10 | `AudioPlayerService._amplitudeSimulationTimer` | 100ms | Service | Mantenuto (just_audio) |

**Timer che agiscono sul bottom sheet:** 4 (#1, #2, #3, #5) → target finale: 0

**Layer nativo Swift:** zero timer. `installTap` è hardware-driven, `getPlaybackPosition` è on-demand, `scheduleFile` completion è push via EventChannel.

## File modificati (questa sessione)

| File | Tipo modifica |
|------|--------------|
| `lib/presentation/bloc/recording_lifecycle/recording_lifecycle_bloc.dart` | 🗑 eliminato |
| `lib/presentation/bloc/recording_lifecycle/recording_lifecycle_event.dart` | 🗑 eliminato |
| `lib/presentation/bloc/recording_lifecycle/recording_lifecycle_state.dart` | 🗑 eliminato |
| `lib/domain/usecases/recording/recording_lifecycle_usecase.dart` | 🗑 eliminato |
| `test/unit/blocs/recording_lifecycle_bloc_test.dart` | 🗑 eliminato |
| `test/unit/usecases/recording_lifecycle_usecase_test.dart` | 🗑 eliminato |
| `Wavnotes_brain/project/adr/2026-04-14-audio-clock-push-based.md` | ✨ nuovo ADR |
| `Wavnotes_brain/project/tech-debt.md` | aggiornato |

## Next
- [ ] **Step 1** — `ios/Runner/AudioEnginePlugin.swift`: nuovo EventChannel `com.wavnote/audio_engine/clock_events`, emissione recording/playback tick con `framesWritten` counter
- [ ] **Step 2** — `AudioEngineService`: rimozione `_amplitudeTimer` e `_positionTimer`, subscribe a clock_events
- [ ] **Step 3** — `AudioServiceCoordinator`: `activeClockStream` con routing per `AudioClockMode`
- [ ] **Step 4** — `RecordingBloc`: subscription singola
- [ ] **Step 5** — eliminazione `RecordingClockService`
- [ ] **Step 6** — rimozione `_waveformTimer` e logica calibrazione UI
- [ ] **Step 7** — verifica su dispositivo (30s recording, overdub, preview)
- [ ] Verificare se `AudioMonitoringService` è ancora usato (potenziale altro dead code)

## Stato Sistema
- Decisione architetturale documentata in: [[project/adr/2026-04-14-audio-clock-push-based]]
- Tech debt aggiornato in: [[project/tech-debt]]
- Dead code rimosso: `RecordingLifecycleBloc` + use case + test (6 file)
- Riferimento principale: [[_index]]
