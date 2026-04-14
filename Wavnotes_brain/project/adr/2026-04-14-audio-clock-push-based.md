# ADR-001 — AudioClock push-based nativo end-to-end

| Campo | Valore |
|-------|--------|
| **Data** | 2026-04-14 |
| **Stato** | Proposta |
| **Autore** | — |

## Decisione
Unificare la gestione del tempo audio (recording duration, playback position, amplitude) in un singolo clock **push-based** guidato dal layer nativo Swift (AVAudioEngine), eliminando tutti i `Timer.periodic` Dart-side che attualmente duplicano e desincronizzano la gestione temporale.

## Perché
- Attualmente esistono **10 timer Dart** attivi nel progetto, di cui 4 agiscono direttamente sul bottom sheet (`_waveformTimer`, `RecordingClockService._durationTimer`, `AudioEngineService._amplitudeTimer`, `AudioEngineService._positionTimer`).
- I timer sono **pull-based** (polling via MethodChannel) → jitter, latenza, drift.
- La durata recording oggi deriva da `DateTime.now()` (wall clock, soggetto a NTP) invece che dal sample count.
- La UI contiene logica di calibrazione (`_needsCalibration`, `_seekTimeOffsetMs`, `_futureBarsCount`) che esiste **solo** per compensare il disallineamento tra i vari clock.
- Il nativo è già pulito (zero timer Swift, tutto hardware-driven o on-demand) — il disordine è interamente Dart-side.

## Alternative scartate
| Alternativa | Motivo scarto |
|-------------|--------------|
| **Minimal invasive** — Stopwatch nel coordinator + riusare `_amplitudeTimer` esistente | Mantiene polling MethodChannel pull-based, drift residuo, non sample-accurate |
| **AudioClockTick con campi nullable** `{recordingPosition?, playbackPosition?}` | Ambiguità durante overdub+preview, costringe UI/BLoC a decidere priorità → sposta la gerarchia in UI |
| **Timer unico in Dart che polla tutto** | Peggiora: più hop MethodChannel, pull-based, contraddice "audio guida UI" |
| **EventChannel solo per position, amplitude via polling** | Lascia in piedi un timer Dart senza motivo tecnico |

## Architettura target
```
AVAudioEngine (Swift)
  ├─ installTap recording → RecordingTick { positionMs, amplitude }
  └─ DispatchSourceTimer playback 100ms → PlaybackTick { positionMs, durationMs }
                      │
                      ▼
        EventChannel `com.wavnote/audio_engine/clock_events`
                      │
                      ▼
  AudioEngineService (Dart) — subscriber puro
    ├─ recordingTickStream
    └─ playbackTickStream
                      │
                      ▼
  AudioServiceCoordinator
    └─ activeClockStream: Stream<ClockTick>
         [routing per AudioClockMode esplicito]
                      │
                      ▼
  RecordingBloc — _clockSubscription singola
                      │
                      ▼
  RecordingBottomSheet — cresce waveform in didUpdateWidget
```

## Principi
1. **Sorgente = AVAudioEngine**: posizione derivata da `framesWritten / sampleRate` (recording) o `lastRenderTime` (playback). Sample-exact.
2. **Push, mai pull**: nativo invia eventi via EventChannel; Dart non interroga mai.
3. **Un solo "modo" attivo**: enum `AudioClockMode { idle, recording, playback }` esplicito, no nullable fields.
4. **Amplitude + position insieme**: nello stesso tick quando generate dallo stesso buffer callback.

## Impatto

### File nuovi
- **Swift**: `EventChannel clock_events` in `AudioEnginePlugin.swift`
- **Dart**: `ClockTick` class + `AudioClockMode` enum (in `AudioServiceCoordinator`)

### File modificati
| File | Modifica |
|------|---------|
| `ios/Runner/AudioEnginePlugin.swift` | Nuovo EventChannel + `framesWritten` counter + `DispatchSourceTimer` playback |
| `lib/services/audio/audio_engine_service.dart` | Rimuove `_amplitudeTimer`, `_positionTimer`; subscribe a clock_events |
| `lib/services/audio/audio_service_coordinator.dart` | Rimuove `_calculateIosDuration`, `_iosRecordingStartTime`, `_iosPausedDuration`, `_iosPauseStartTime`, `_positionController`, `_amplitudeController`; aggiunge `activeClockStream` |
| `lib/presentation/bloc/recording/recording_bloc.dart` | Rimuove `_amplitudeSubscription`, `_durationSubscription`, `_previewPositionSubscription`, `_clockService`; aggiunge `_clockSubscription` singola |
| `lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart` | Rimuove `_waveformTimer`, `_needsCalibration`, `_seekTimeOffsetMs`, `_syncWaveformToElapsedTime()` |

### File eliminati
- `lib/services/audio/recording_clock_service.dart`

### Layer coinvolti
- iOS native (Swift)
- Data/Services (Dart)
- Presentation/BLoC
- Presentation/UI widgets

### Tech debt
- **Aggiunto:** no
- **Risolto:** proliferazione timer, drift wall-clock, logica calibrazione UI → vedi [[project/tech-debt]]

### Feature impattate
- Registrazione + overdub
- Playback preview durante pausa
- Waveform real-time
- Vedi [[project/features]]

## Ordine di esecuzione
1. **Step 1** — Swift: EventChannel `clock_events` + emissione recording/playback tick
2. **Step 2** — `AudioEngineService`: subscriber puro, rimozione timer
3. **Step 3** — `AudioServiceCoordinator`: `activeClockStream` con routing per modo
4. **Step 4** — `RecordingBloc`: subscription singola
5. **Step 5** — Eliminazione `RecordingClockService`
6. **Step 6** — UI: rimozione `_waveformTimer` e logica calibrazione
7. **Step 7** — Verifica su dispositivo (golden path + overdub + edge case)

## Verifica su dispositivo
- Registrazione 30s → esattamente 300 barre da 100ms
- Overdub a metà → allineamento perfetto barre pre-seek
- Playback preview → seekbar fluida, no jump
- Pause/resume → `framesWritten` congelato nativo, no drift

## Metriche di successo
| Metrica | Prima | Dopo |
|---|---|---|
| Timer Dart totali | 10 | 0 (solo `_clockTimer` 30s orologio) |
| Timer Dart sul bottom sheet | 4 | 0 |
| Timer nativi | 0 | 1 (DispatchSourceTimer playback) |
| MethodChannel per tick | sì | no (solo EventChannel push) |
| Sorgente verità temporale | `DateTime.now()` | `framesWritten / sampleRate` |
| Drift possibile | sì | no (sample-exact) |

## Link
- [[project/features]]
- [[project/tech-debt]]
- [[_index]]
