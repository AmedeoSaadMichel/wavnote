# WavNote — CLAUDE.md

> Regole ordinate per priorità. In conflitto, vince la regola più in alto.
> "STOP" = blocca, chiedi conferma esplicita. "MAI" = non negoziabile.

---

## STOP-THE-LINE

Non eseguire mai queste azioni senza conferma esplicita dell'utente:

- **Git**: `commit`, `push`, `reset --hard`, `rebase`, qualsiasi comando che modifica history o remote. Proponi il comando, aspetta "sì".
- **Logica di business**: modifiche a BLoC, use case, repository. Le modifiche *solo UI* non richiedono conferma.
- **Dipendenze**: aggiunta/rimozione di package in `pubspec.yaml`.
- **Struttura**: modifiche a `idea_project_structure.txt`.

---

## LINGUA

Italiano in tutto: risposte, commenti nel codice, commit proposti.
Eccezione: termini tecnici standard (BLoC, widget, repository, ecc.) restano in inglese.

---

## SECOND BRAIN — LEGGI ALL'INIZIO DI OGNI SESSIONE

**Sequenza obbligatoria** (prima di toccare qualsiasi file di codice):

1. `Wavnotes_brain/_index.md` — mappa + context budget
2. `Wavnotes_brain/project/hot.md` — **sempre**, contesto recente in ~500 token
3. File specifici in base al tipo di task:

| Task | File aggiuntivi |
|------|----------------|
| Bug fix | `project/tech-debt.md` |
| Nuova feature | `project/features.md` + analisi recente in `analysis/` |
| Refactoring | `project/CLAUDE.md` + `project/adr/` |
| Termine sconosciuto | `project/glossary.md` |
| Analisi generale | `project/features.md` + `project/tech-debt.md` |

**A fine sessione (SEMPRE):**
- Aggiorna `Wavnotes_brain/project/hot.md` con stato corrente, file toccati, decisioni, prossimo step.
- Se sessione >20 min o decisioni architetturali: crea `Wavnotes_brain/log/sessions/YYYY-MM-DD-topic.md`.
- Aggiorna `features.md` e/o `tech-debt.md` se toccati.
- Per decisioni architetturali: crea `Wavnotes_brain/project/adr/YYYY-MM-DD-titolo.md`.
- Analisi richiesta dall'utente: salva in `Wavnotes_brain/analysis/YYYY-MM-DD-topic.md`.

**Routine giornaliera (se sessione dura più giorni):**
- Una volta al giorno aggiorna `project/hot.md` anche senza chiudere la sessione.

---

## DIMENSIONE DEI FILE

| Soglia | Azione |
|--------|--------|
| ≤500 righe | Obiettivo. |
| 501–800 righe | Accettabile, nessuna azione. |
| >800 righe | **Refactor obbligatorio** — o chiedi deroga esplicita. |

Refactoring segue responsabilità singola: separa widget, logica, helper.

---

## INTESTAZIONE FILE

Ogni file `.dart` creato o modificato inizia con:

```dart
// File: lib/path/esatto/del/file.dart
```

---

## ARCHITETTURA

### Layer
```
domain/        → entità, use case, interfacce repository. Zero dipendenze Flutter.
data/          → implementazioni repository, data source, modelli.
presentation/  → BLoC, schermate, widget. Zero logica di business.
core/          → DI, errori, tema, utility condivise.
```

### Regole non negoziabili

**Dependency Injection**
- Ogni servizio/repository/use case si registra **solo** in `core/di/dependency_injection.dart` via GetIt.
- MAI `late final` globali in `main.dart`. MAI istanziazione in costruttori BLoC.

**Error handling**
- Repository e use case → `Either<Failure, T>` (dartz).
- BLoC → consuma con `.fold()`.
- Nessuna eccezione risale all'UI.
- Tutti i tipi `Failure` vivono in `core/errors/failures.dart`.

**Inizializzazione**
- Ogni `initialize()` è idempotente: guard `_isInitialized` obbligatorio.
- Se l'ordine di init conta, documentalo nel file stesso.

**Single source of truth**
- MAI due istanze della stessa responsabilità (due DB helper, due audio service, ecc.).
- Se ne trovi due: segnala, non unificare senza conferma.

### BLoC — regola durante modifiche UI
- MAI toccare `BlocBuilder`, `BlocConsumer`, `BlocListener` o le callback che emettono eventi.
- Se serve cambiare la logica collegata → STOP, descrivi, chiedi conferma.

---


## COMPORTAMENTO

### Pensa prima di scrivere
- Dichiara le assunzioni prima di implementare.
- Se esistono più interpretazioni plausibili, elencale — non scegliere in silenzio.
- Se vedi un approccio più semplice, proponilo prima.
- Se la richiesta è ambigua: fermati, nomina cosa non è chiaro, chiedi.

### Semplicità
- Minimo codice che risolve il problema. Zero "per il futuro".
- Zero astrazioni per codice usato una sola volta.
- Zero configurabilità non richiesta.
- Se scrivi 200 righe dove ne bastavano 50: riscrivi.

### Modifiche chirurgiche
- Tocca solo ciò che la richiesta richiede.
- MAI "migliorare" formattazione, commenti o stile di codice adiacente.
- MAI refactoring di codice non rotto.
- Rimuovi **solo** gli orfani creati dalle *tue* modifiche (import, variabili, funzioni).
- Codice morto preesistente: segnalalo, non cancellarlo.

### Quando chiedere vs procedere

| Situazione | Azione |
|------------|--------|
| Modifica solo UI, stile, layout | Procedi |
| Fix typo, rinomina locale a uno scope | Procedi |
| Logica business, BLoC, use case | STOP — chiedi |
| Nuovo package, modifica `pubspec.yaml` | STOP — chiedi |
| Trade-off non banale con più opzioni | Elenca opzioni — chiedi |
| Comportamento richiesto ambiguo | Fermati — chiedi |

---



