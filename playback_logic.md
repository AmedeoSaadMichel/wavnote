# Logica di Playback in Sessione di Registrazione — Specifiche

## Panoramica

Questo documento descrive la logica di playback (anteprima) durante una sessione di registrazione audio attiva. L'obiettivo è permettere all'utente di riascoltare il registrato corrente — inclusi gli overdub — direttamente dalla bottomsheet fullscreen, senza uscire dalla sessione.

**Regola fondamentale**: il file preview è **identico** al file che verrà salvato. Non esiste distinzione tra "audio di anteprima" e "audio finale".

---

## Quando il playback è disponibile

Il playback è disponibile **esclusivamente in stato `PAUSED`**.

| Stato BLoC | Playback |
|---|---|
| `IDLE` | — |
| `RECORDING` | ❌ impossibile (limite hardware AVAudioEngine) |
| `PAUSED` | ✅ disponibile |
| `RecordingStarting` (transizione seek-and-resume) | ❌ bloccato |
| `SAVED` | N/A (sessione chiusa) |

> AVAudioEngine non può registrare e riprodurre in simultanea sulla stessa sessione audio. Il playback è quindi strutturalmente vincolato allo stato di pausa.

---

## Comportamento dei controlli

In stato `PAUSED`, la bottomsheet fullscreen espone:

- Waveform con playhead
- Seek label `← MM:SS / MM:SS →`
- `FullscreenPlaybackControls`: ⏪ — ▶/⏹ — ⏩
- `RecordPupilButton` con overlay ▶

| Controllo | In pausa (non playing) | Durante playback |
|---|---|---|
| `RecordPupilButton` (▶) | → riprende registrazione | ferma preview → riprende registrazione |
| ▶/⏹ (play centrale) | → avvia preview da `seekBarIndex` | → ferma preview, `seekBarIndex` rimane |
| ⏪ (rewind 10s) | `seekBarIndex -= 10` | seek audio −10 bar (senza stop) |
| ⏩ (forward 10s) | `seekBarIndex += 10` | seek audio +10 bar (senza stop) |
| Drag waveform | sposta `seekBarIndex` | ferma preview + sposta `seekBarIndex` |
| Done | salva e chiude | ferma preview → salva e chiude |

### Nota sul `RecordPupilButton` durante playback

Il tap esegue **auto-stop + resume** in sequenza:
1. `StopRecordingPreview`
2. Valuta `seekBarIndex` → resume semplice o seek-and-resume (overdub)
3. Avvia la registrazione

L'icona overlay cambia da ▶ a ⏹ durante il playback per segnalare il comportamento.

---

## Mappatura bar → posizione audio

```
posizione_audio_ms = seekBarIndex × 100
```

La mappatura è **lineare e invariante** rispetto al numero di overdub effettuati. Il file audio assemblato rispecchia sempre la waveform visiva: la barra N corrisponde ai millisecondi N×100 nell'audio assemblato.

---

## Regola della durata

La durata del file assemblato dipende da dove termina l'overdub rispetto alla fine della registrazione originale:

```
Caso B — overdub interno che NON supera la fine originale:
|--A--|--B--|--B--|--B--|--A--|--A--|   durata = 60s (invariata)
0    20               35           60

Caso D — overdub che SUPERA la fine originale:
|--A--|--B--|--B--|--C--|--C--|--D--|--D--|--D--|--D--|   durata = 75s (estesa)
0    20         35         50      60                75
```

| Condizione | Coda (tail) | Durata finale |
|---|---|---|
| `overwriteEnd < originalEnd` | ✅ preservata | invariata |
| `overwriteEnd == originalEnd` | nessuna (fine esatta) | invariata |
| `overwriteEnd > originalEnd` | nessuna (estende oltre) | aumentata |

---

## Assembly audio per il preview

L'audio del preview viene assemblato dinamicamente prima di avviare `just_audio`. Esistono quattro casi.

### Caso 1 — Registrazione semplice (nessun overdub)

```
seekBasePath == null

preview  = filePath
seek     = seekBarIndex × 100ms
durata   = filePath.duration
```

Nessun assembly: il file corrente viene riprodotto direttamente dalla posizione di seek.

---

### Caso 2 — Overdub con resume dalla fine

```
seekBasePath != null
overwriteStartTime == durata(seekBasePath)

preview  = concat(seekBasePath, filePath)
seek     = seekBarIndex × 100ms
durata   = durata(seekBasePath) + durata(filePath)
```

Il nuovo segmento è stato registrato dopo la fine del base: semplice concatenazione, durata aumentata.

---

### Caso 3 — Overdub interno che NON supera la fine originale

```
seekBasePath != null
overwriteStartTime + durata(filePath) <= durata(seekBasePath)

baseTrimmed = trim(seekBasePath, 0, overwriteStartTime)
tail        = trim(seekBasePath, overwriteStartTime + durata(filePath), durata(seekBasePath))
preview     = concat(baseTrimmed, filePath, tail)
seek        = seekBarIndex × 100ms
durata      = durata(seekBasePath)   ← invariata
```

La coda originale viene **preservata**: la durata totale non cambia.

Esempio: registrazione 60s, overdub da 20s a 35s → preview = A(0→20) + B(20→35) + A(35→60) = 60s

---

### Caso 4 — Overdub interno che SUPERA la fine originale

```
seekBasePath != null
overwriteStartTime + durata(filePath) > durata(seekBasePath)

baseTrimmed = trim(seekBasePath, 0, overwriteStartTime)
preview     = concat(baseTrimmed, filePath)
seek        = seekBarIndex × 100ms
durata      = overwriteStartTime + durata(filePath)   ← aumentata
```

Il nuovo segmento supera la fine originale: nessuna coda da preservare, durata estesa.

Esempio: registrazione 60s, overdub da 50s a 75s → preview = A(0→50) + D(50→75) = 75s

---

### Caso 5 — Overdub su overdub (N livelli)

`seekBasePath` contiene già il risultato dell'overwrite precedente applicato da `_onStartOverwrite`. Si applica la stessa logica di Caso 2, 3 o 4 a seconda di `overwriteStartTime` rispetto alla nuova durata di `seekBasePath`.

Esempio con quattro overdub progressivi:
```
Stato iniziale:   |--A--|--A--|--A--|--A--|--A--|--A--|              60s
Dopo overdub B:   |--A--|--B--|--B--|--B--|--A--|--A--|              60s  (Caso 3: B non supera la fine)
Dopo overdub C:   |--A--|--B--|--B--|--C--|--C--|--A--|              60s  (Caso 3: C non supera la fine)
Dopo overdub D:   |--A--|--B--|--B--|--C--|--C--|--D--|--D--|--D--|  75s  (Caso 4: D supera la fine → estende)
```

`seekBasePath` al momento di ogni overdub contiene il risultato assemblato di tutti gli overdub precedenti. La logica di Caso 2/3/4 si applica identica a ogni livello.

---

## Pseudocodice — `assemblePreview(state)`

```typescript
async function assemblePreview(state: RecordingPaused): Promise<string> {
  // Caso 1: nessun overdub
  if (state.seekBasePath == null) {
    return state.filePath;
  }

  const baseDurationMs    = await getAudioDuration(state.seekBasePath);
  const overwriteMs       = state.overwriteStartTime?.ms ?? 0;
  const newSegmentMs      = await getAudioDuration(state.filePath);
  const overwriteEndMs    = overwriteMs + newSegmentMs;
  const isSimpleConcat    = overwriteMs === baseDurationMs;

  const tempPath = generateTempPath('preview');

  if (isSimpleConcat) {
    // Caso 2: resume dalla fine — concatenazione semplice
    await concatenate(state.seekBasePath, state.filePath, tempPath);

  } else if (overwriteEndMs < baseDurationMs) {
    // Caso 3: overdub interno — la coda viene preservata
    // NOTA: overwriteEndMs == baseDurationMs è escluso (tail di durata zero)
    //       e viene gestito dal ramo successivo come Caso 4 (no tail).
    const trimmedBase = generateTempPath('base_trimmed');
    const tail        = generateTempPath('tail');

    await trim(state.seekBasePath, Duration.zero,
               Duration(ms: overwriteMs), trimmedBase);
    await trim(state.seekBasePath, Duration(ms: overwriteEndMs),
               Duration(ms: baseDurationMs), tail);
    await concatenate3(trimmedBase, state.filePath, tail, tempPath);

    await cleanup(trimmedBase);
    await cleanup(tail);

  } else {
    // Caso 4: overdub che supera la fine O arriva esattamente alla fine — nessuna coda
    const trimmedBase = generateTempPath('base_trimmed');

    await trim(state.seekBasePath, Duration.zero,
               Duration(ms: overwriteMs), trimmedBase);
    await concatenate(trimmedBase, state.filePath, tempPath);

    await cleanup(trimmedBase);
  }

  return tempPath;
}

async function startPreview(state: RecordingPaused): void {
  const previewPath  = await assemblePreview(state);
  const seekPosition = Duration(milliseconds: state.seekBarIndex * 100);
  await audioService.startPlaying(previewPath, initialPosition: seekPosition);
  emit(state.copyWith(isPlayingPreview: true));
}
```

---

## Edge cases

| Situazione | Comportamento |
|---|---|
| `seekBarIndex` oltre la durata del preview assemblato | Clamp all'ultima barra disponibile |
| `_futureBarsCount > 0` all'ingresso in pausa | Azzerato automaticamente in `didUpdateWidget` → sempre 0 al momento del play |
| File temporanei `_preview_*.wav` | Cleanup al `StopRecordingPreview` |
| Stop preview + tap `Done` immediato | `Done` chiama `StopRecordingPreview` prima di salvare |
| `overwriteEndMs == baseDurationMs` (esattamente alla fine) | Trattato come Caso 4 (nessuna tail): il branch usa `<` non `<=` |

---

## Collegamento con StopRecording

`assemblePreview` e `StopRecording` devono produrre **lo stesso risultato audio**. La differenza è solo nella destinazione:

| Operazione | Output | Quando |
|---|---|---|
| `assemblePreview` | file temporaneo `_preview_*.wav` | al tap ▶, viene eliminato dopo il playback |
| `StopRecording` | file finale nel path definitivo | al tap Done / salvataggio |

`StopRecording` deve usare la **stessa logica di branching** (Caso 1/2/3/4) con gli stessi parametri. Qualsiasi differenza tra i due produce un file salvato diverso da quello ascoltato in anteprima — comportamento vietato.

---

## Regola finale

> Il file preview e il file salvato sono **identici**. La durata della registrazione rimane invariata se l'overdub non supera la fine originale; si estende solo se il nuovo segmento va oltre.

---

*Documento generato per la specifica del playback in sessione di registrazione — WavNote.*
