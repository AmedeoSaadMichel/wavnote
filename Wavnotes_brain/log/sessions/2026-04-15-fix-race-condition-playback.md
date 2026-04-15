# Session — 2026-04-15 — Fix race condition playback completion

| Campo | Valore |
|-------|--------|
| **Data** | 2026-04-15 |
| **Durata** | ~60 min |
| **Branch** | `main` |

## Task
- [x] Analisi bug: seekbar si ferma a 78/90 invece di 90/90 durante playback
- [x] Identificata race condition tra timer clock e callback nativo
- [x] Implementata soluzione unificata: timer come unica autorità
- [x] Refactor callback nativi: da fallback attivo a segnalazione passiva

## Decisioni prese
- **Decisione:** Eliminare la race condition architetturale invece di gestirla
  - Perché: Due meccanismi (timer 100ms e callback `scheduleFile`) competevano per segnalare il completamento. Il callback vinceva sempre, interrompendo il timer prima che emettesse l'ultimo tick (90/90).
  - Soluzione: Aggiunta flag `playbackFinished` che il callback setta; solo il timer controlla questa flag e decide quando completare, emettendo sempre il tick finale.
  - Vedi: Modifiche in `ios/Runner/AudioEnginePlugin.swift`

## File modificati
| File | Tipo modifica |
|------|--------------|
| `ios/Runner/AudioEnginePlugin.swift` | bugfix / refactor |

## Dettaglio tecnico

### Problema
Quando il playback arrivava alla fine del file audio:
1. Il callback nativo di `AVAudioPlayerNode.scheduleFile()` scattava immediatamente
2. Questo callback forzava `isPlaying = false` e fermava il timer
3. I tick finali (es. 79-90) non venivano mai emessi perché il timer era già fermo
4. La UI vedeva 78/90 e poi completamento, saltando l'ultimo tick

### Soluzione implementata
1. **Nuova variabile di stato:** `private var playbackFinished: Bool = false`
2. **Callback semplificati:** Ora fanno solo `self.playbackFinished = true`, senza alcuna azione diretta
3. **Timer unico autorità:** Controlla `if self.playbackFinished || totalFrames >= file.length` e solo lui gestisce il completamento
4. **Ordine garantito:** Callback → flag settata → timer al prossimo tick vede la flag → emette tick finale → completa

### Codice chiave
```swift
// Il timer è l'unica autorità per il completamento del playback.
// Controlla se il callback ha segnalato la fine O se abbiamo raggiunto la fine del file.
if self.playbackFinished || totalFrames >= file.length {
    // Tick finale con posizione esattamente alla fine
    self.clockStreamHandler.sendPlaybackTick(positionMs: durationMs, durationMs: durationMs)
    self.logger.info("🔊 [NATIVE] Playback completed via clock")
    self.isPlaying = false
    self.stopPlaybackClock()
    self.playbackStreamHandler.sendPlaybackComplete()
    return
}
```

## Next
- [ ] Test su dispositivo fisico per verificare sincronizzazione audio/UI
- [ ] Verificare che la soluzione funzioni anche con `seekTo` e segmenti parziali
- [ ] Considerare se rimuovere logging di debug nativo prima del rilascio

## Stato Sistema
- Modifiche documentate in: [[project/features]]
- Tech debt: aggiornato in [[project/tech-debt]]
- Riferimento principale: [[_index]]
