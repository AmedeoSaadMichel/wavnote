# Logica di Sovraincisione (Overdub) — Specifiche

## Panoramica

Questa documento descrive la logica di sovraincisione (overdub) durante una sessione di registrazione audio. L'obiettivo è permettere all'utente di sovrascrivere porzioni di una registrazione in modo non distruttivo e visivamente tracciabile tramite la colorazione della waveform.

---

## Stati della sessione

```
IDLE → RECORDING → PAUSED → RECORDING (loop)
RECORDING | PAUSED → SAVED (fine sessione)
```

| Stato | Descrizione |
|---|---|
| `IDLE` | Nessuna registrazione attiva |
| `RECORDING` | Registrazione in corso, cursore avanza in tempo reale |
| `PAUSED` | Registrazione ferma, cursore immobile |
| `SAVED` | Sessione conclusa, segmenti consolidati |

---

## Comportamento passo per passo

### 1. Avvio — Premi Registra
- Parte la registrazione dal punto corrente del cursore.
- Si crea il **segmento iniziale** con **colore A** (indice 0).
- Il cursore avanza in tempo reale mentre la waveform cresce.

### 2. Pausa
- La registrazione si interrompe.
- Il cursore rimane nella posizione corrente.
- Il segmento corrente si chiude in quel punto.

### 3. Ripresa — due casi distinti

#### Caso A — Cursore alla fine del recording
- Si riprende con lo **stesso colore** del segmento precedente.
- Nessun nuovo overdub viene creato.
- Il segmento corrente si estende in avanti.

#### Caso B — Cursore in un punto interno (≠ fine)
- Si assegna un **nuovo colore** (B, C, D… incrementale).
- Il nuovo audio **sovrascrive** il tratto da quel punto in avanti.
- La sovrascrittura termina alla prossima Pausa o Salva.
- I tratti prima e dopo il range di overdub **mantengono il loro colore originale**.

### 4. Salva / Stop
- Termina la sessione.
- I segmenti vengono consolidati nella loro forma finale.

---

## Regola dei colori — Overdub su overdub

> **Regola universale:** ogni volta che si riprende da un punto interno, indipendentemente da quale colore era presente in quel tratto (A, B, C o qualsiasi altro), si crea sempre un nuovo colore con indice N+1.

Il colore dipende **esclusivamente dall'ordine cronologico** della registrazione, non dal contenuto preesistente.

| Azione | Risultato |
|---|---|
| Primo avvio | Colore A (indice 0) |
| Overdub su A | Colore B (indice 1) |
| Overdub su B | Colore C (indice 2) |
| Overdub su C | Colore D (indice 3) |
| Overdub su A che copre anche B e C | Colore D — sovrascrive tutto il range |

---

## Esempi visivi

### Esempio 1 — Registra → pausa → riprendi dalla fine → pausa
```
|----A----|----A----|
```
Un solo colore: cursore era alla fine, nessun overdub.

### Esempio 2 — Registra → pausa → riprendi dalla fine → pausa → sposta cursore → riprendi → pausa
```
|--A--|----B----|--A--|
```
B sovrascrive solo il tratto dal punto di resume alla nuova pausa. A rimane intatto fuori da quel range.

### Esempio 3 — Come sopra + secondo overdub in altro punto
```
|--A--|--B--|--A--|--C--|--A--|
```
Due overdub in posizioni diverse. A sopravvive nei tratti non toccati.

### Esempio 4 — Overdub su un tratto già overdub (B → D)
```
Stato prima:  |--A--|----B----|--A--|
Dopo overdub su B:  |--A--|--B--|--D--|--B--|--A--|
```
D sovrascrive la porzione centrale di B. Il colore preesistente non conta.

---

## Struttura dati

```typescript
type Segment = {
  startSample: number;
  endSample:   number;
  colorIndex:  number;  // 0 = A, 1 = B, 2 = C, ...
};

type Session = {
  segments:       Segment[];
  overdubCounter: number;   // sale solo a ogni ripresa da punto interno
  cursorPosition: number;
  state:          'IDLE' | 'RECORDING' | 'PAUSED' | 'SAVED';
};
```

---

## Pseudocodice — `onResume(cursorPosition)`

```typescript
function onResume(cursorPosition: number): void {
  const endOfRecording = getEndOfRecording();

  if (cursorPosition === endOfRecording) {
    // Caso A: continua con colore corrente
    extendLastSegment();
  } else {
    // Caso B: nuovo overdub
    session.overdubCounter++;
    const newColorIndex = session.overdubCounter;

    // Spezza i segmenti esistenti nel punto di inizio overdub
    splitSegmentsAt(cursorPosition);

    // Crea il nuovo segmento overdub (endSample verrà aggiornato a ogni frame)
    session.segments.push({
      startSample: cursorPosition,
      endSample:   cursorPosition,
      colorIndex:  newColorIndex,
    });
  }

  session.state = 'RECORDING';
}

function onPause(): void {
  // Chiude il segmento corrente alla posizione attuale del cursore
  closeCurrentSegment(session.cursorPosition);
  session.state = 'PAUSED';
}

function splitSegmentsAt(position: number): void {
  // Trova il segmento che contiene `position` e lo divide in due,
  // mantenendo il colorIndex originale per entrambe le parti.
  // I segmenti successivi a `position` verranno sovrascritti
  // dal nuovo segmento overdub durante il recording.
}
```

---

## Regola visiva finale

> Il **numero di colori distinti** visibili sulla waveform al termine della sessione corrisponde esattamente al **numero di overdub effettuati** (più 1 per la registrazione originale A).  
> Il colore mostra **quale incisione è attiva** in quel preciso punto temporale, non quando è stata registrata.

---

*Documento generato per la specifica della funzionalità overdub in sessione di registrazione.*
