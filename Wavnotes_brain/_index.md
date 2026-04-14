# WavNote Brain — Mappa di navigazione

> Leggi solo questo file all'inizio di ogni sessione, poi vai diretto alla nota giusta.

## Note permanenti
| File | Contenuto |
|------|-----------|
| [[project/CLAUDE]] | Stack, struttura, convenzioni, come usare questa vault |
| [[project/features]] | Tabella feature con stato attuale |
| [[project/tech-debt]] | TODO e workaround aperti nel codice |

## Decision Records
`project/adr/` — vuoto, pronto per le prossime ADR

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

_Ultimo aggiornamento: 2026-04-14_
