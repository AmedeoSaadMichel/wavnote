# WavNote Brain — Mappa di navigazione

> Leggi solo questo file all'inizio di ogni sessione, poi vai diretto alla nota giusta.

## Sequenza di lettura obbligatoria

```
1. _index.md  (questo file)
2. project/hot.md  ← contesto recente in ~500 token, sempre
3. [file specifici per il task — vedi context budget sotto]
```

### Context budget per tipo di task
| Task | File da leggere dopo hot.md |
|------|-----------------------------|
| Bug fix | `tech-debt.md` |
| Nuova feature | `features.md` + analisi recente in `analysis/` |
| Refactoring | `project/CLAUDE.md` + `adr/` |
| Analisi generale | `features.md` + `tech-debt.md` + `analysis/` recente |
| Termine sconosciuto | `project/glossary.md` |

## Note permanenti
| File | Contenuto |
|------|-----------|
| [[project/hot]] | **Hot cache** — backlog prioritizzato, cosa c'è da fare |
| [[project/architecture]] | **Architettura** — ogni modulo e cartella spiegati |
| [[project/CLAUDE]] | Stack, struttura, convenzioni, come usare questa vault |
| [[project/features]] | Tabella feature con stato attuale |
| [[project/tech-debt]] | TODO e workaround aperti nel codice |
| [[project/glossary]] | Glossario termini non ovvi del progetto |

## Analisi
| File | Topic |
|------|-------|
| [[analysis/2026-04-26-bug-sfarfallio-overdub]] | Root cause sfarfallio play/pause (B1) + overdub error (B2) — analisi completa |
| [[analysis/plans/2026-04-26-fix-b2-overdub]] | Piano di fix B2 — tre task chirurgici (completato) |
| [[analysis/plans/2026-04-28-background-audio-recording]] | Piano feature registrazione audio in background — iOS first + Android foreground service |
| [[analysis/plans/2026-04-28-live-activity-dynamic-island]] | Piano Live Activity / Dynamic Island per registrazione in background |
| [[analysis/2026-04-23-post-refactor-improvements]] | Migliorie codice post-refactor — audio playback/preparation layer, top 10 azioni |
| [[analysis/2026-04-23-project-state]] | Stato generale progetto — architettura audio, waveform, fullscreen player |

> **Regola:** ogni analisi fornita in sessione va qui, con link interni a features/tech-debt.  
> Template: [[templates/analysis]]

## Logiche di sistema
| File | Contenuto |
|------|-----------|
| [[logics/overdub_logic]] | Diagramma di flusso e spiegazione della logica di overdub |
| [[logics/playback_logic]] | Diagramma di flusso e spiegazione della logica di playback |

> **Regola:** Se la logica di uno strumento o funzionalità non è chiara, consulta prima il file `.md` corrispondente qui.

## Decision Records
| File | Topic |
|------|-------|
| [[project/adr/2026-04-14-audio-clock-push-based]] | ADR-001 — AudioClock push-based nativo end-to-end |
| [[project/adr/2026-04-28-presentation-file-splitting]] | ADR-002 — Split chirurgico dei file presentation troppo grandi |

## Log
| Cartella | Scopo |
|----------|-------|
| `log/sessions/` | Session note (solo se sessione > 20 min o decisioni architetturali) |
| `log/daily/` | Daily log opzionali |

## Templates
- [[templates/adr]] — template ADR
- [[templates/session]] — template session note

## Regola d'uso
1. Apri `_index.md` → identifica la nota giusta → aprila
2. Non esplorare liberamente il vault
3. Aggiorna `features.md` e `tech-debt.md` a fine sessione se li hai toccati
4. Crea session note solo se la sessione dura >20 min o produce decisioni architetturali. **Regola fondamentale**: ogni file di sessione creato DEVE contenere alla fine della pagina dei link espliciti (es. `[[project/features]]`, `[[project/tech-debt]]` e `[[_index]]`) in modo da mantenere il Graph View di Obsidian sempre connesso.

_Ultimo aggiornamento: 2026-04-26_
