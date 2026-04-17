# Session — 2026-04-16 — Debug Audio Waveform

| Campo | Valore |
|-------|--------|
| **Data** | 2026-04-16 |
| **Durata** | ~60 min |
| **Branch** | `main` |

## Task
- [x] Debug del mancato aggiornamento della waveform durante la registrazione (UI vs Engine)
- [x] Implementazione logging nel BLoC per tracking ampiezza
- [x] Identificazione disallineamento stream tra Engine nativo e Coordinator
- [x] Fix: Aggiunta sottoscrizione clock engine in AudioServiceCoordinator

## Decisioni prese
- **Decisione:** Correzione del flusso dati dell'ampiezza in `AudioServiceCoordinator`
  - Perché: Il servizio `AudioServiceCoordinator` non inoltrava i tick provenienti dall'engine nativo quando `_useNativeEngine` era attivo, ignorando lo stream di `_engineService` durante la registrazione.

## File modificati
| File | Tipo modifica |
|------|--------------|
| `lib/presentation/bloc/recording/recording_bloc.dart` | Debugging (aggiunta log) |
| `lib/services/audio/audio_service_coordinator.dart` | Bugfix (inoltro stream engine) |

## Next
- [ ] Verificare se l'aggiornamento della waveform è fluido dopo il fix
- [ ] Pulire i log di debug aggiunti nel BLoC

## Stato Sistema
- Modifiche documentate in: [[project/features]]
- Tech debt: aggiornato in [[project/tech-debt]] (fix temporaneo/necessario inoltro stream)
- Riferimento principale: [[_index]]
