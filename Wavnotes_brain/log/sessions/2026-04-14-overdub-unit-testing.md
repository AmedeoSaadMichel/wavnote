# Session — 2026-04-14 — Unit Test Overdub e Fix Durata

| Campo | Valore |
|-------|--------|
| **Data** | 2026-04-14 |
| **Durata** | ~45 min |
| **Branch** | `main` |

## Task
- [x] Unit test per overdubbing e playback (playback_logic.md / overdub_logic.md)
- [x] Fix bug: overdub parte dalla posizione errata dopo seek
- [x] Test unitari per il salvataggio (Done)

## Decisioni prese
- **Correzione calcolo durata:** Aggiornata la logica in `RecordingBloc` per calcolare `totalDurationMs` considerando sia il file base originale che l'inserimento, evitando che il sistema pensasse di essere "alla fine" della traccia anche durante l'overdub interno.
  - Perché: Il file base era ignorato nel calcolo, bloccando l'overdub in punti intermedi.

## File modificati
| File | Tipo modifica |
|------|--------------|
| `test/unit/overdub_logic_test.dart` | Nuovi test unitari (scenari overdub + save) |
| `test/unit/playback_logic_test.dart` | Test logica playback |
| `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart` | Bugfix durata totale overdub |

## Next
- [ ] Verificare il PathNotFoundException su dispositivo reale (se persiste).

## Stato Sistema
- Modifiche documentate in: [[project/features]]
- Tech debt: aggiornato in [[project/tech-debt]]
- Riferimento principale: [[_index]]
