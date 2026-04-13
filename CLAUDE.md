# REGOLE DEL PROGETTO FLUTTER VOICE MEMO APP

## CRITICO: Comportamento Agent

- **Non invocare mai skill o tool superpowers prima di rispondere o agire.** Rispondi e agisci direttamente senza verificare skill.
- **Non eseguire mai `git commit` o `git push` autonomamente.** Chiedi sempre esplicitamente l'autorizzazione prima di fare qualsiasi commit o push. Esegui solo se l'utente lo conferma esplicitamente.

## CRITICO: Second Brain Obsidian (Wavnotes_brain/)

**All'inizio di ogni sessione**, prima di leggere qualsiasi file di codice, leggi in questo ordine:
1. `Wavnotes_brain/_index.md` — mappa di navigazione
2. `Wavnotes_brain/project/CLAUDE.md` — stack, struttura, pattern architetturali
3. `Wavnotes_brain/project/tech-debt.md` — TODO aperti e workaround noti
4. `Wavnotes_brain/project/features.md` — solo se la sessione riguarda una feature specifica

Questo ti permette di capire il contesto del progetto senza rileggere i file sorgente.

**A fine sessione** (se la sessione dura >20 min o produce decisioni architetturali):
- Aggiorna `Wavnotes_brain/project/features.md` se hai toccato una feature
- Aggiorna `Wavnotes_brain/project/tech-debt.md` se hai aggiunto/risolto un workaround
- Crea `Wavnotes_brain/log/sessions/YYYY-MM-DD-topic.md` dal template `templates/session.md`
- Per decisioni architetturali significative, crea `Wavnotes_brain/project/adr/YYYY-MM-DD-titolo.md`

## CRITICO: Conformità alla Struttura dei File

- **Scrivi sempre in italiano.**
- **Quando chiedo di correggere gli errori, puoi cambiare la logica ma devi chiedere prima di fare qualsiasi modifica logica.**
- Non è necessario creare tutti i file in idea_project_structure.txt; servono solo quelli essenziali.
- Le modifiche alla struttura sono consentite SOLO quando è impossibile mantenere i file sotto le 800 righe
- Quando vengono apportate modifiche alla struttura a causa dei limiti di dimensione del file:
  - Spiega perché la modifica era necessaria
  - Fornisci SEMPRE il file idea_project_structure.txt aggiornato completo
  - Assicurati che la nuova struttura mantenga un'organizzazione logica

## CRITICO: Limite di Dimensione dei File

- **Obiettivo: 500 righe per file** (opzionale, da preferire quando possibile)
- **Massimo assoluto: 800 righe per file** - Se un file supera le 800 righe, DEVE essere refactorizzato
- **Eccezione: il limite può essere superato con permesso esplicito dell'utente** — in tal caso non è necessario refactorizzare
- Se il refactoring all'interno della struttura attuale è impossibile, solo allora modifica la struttura del progetto
- Suddividi i file troppo grandi in componenti più piccoli e focalizzati seguendo il principio di responsabilità singola

## CRITICO: Linee Guida per il Tema

- **Mantieni un design UI pulito e moderno** con i principi standard di Material Design
- Usa schemi di colori coerenti in tutta l'app (bianchi, grigi, colori di accento standard)
- Evita temi cosmici/mistici a favore di un design professionale e user-friendly
- Concentrati su chiarezza, usabilità ed esperienza utente intuitiva
- **NESSUN materiale protetto da copyright** - tutti gli elementi di design devono essere originali

## CRITICO: Preservazione dell'Architettura BLoC

- **NON rimuovere o modificare mai la logica BLoC** quando si apportano modifiche all'UI
- Preserva sempre i widget BlocBuilder, BlocConsumer e BlocListener
- Mantieni tutte le funzioni di callback che collegano l'UI agli eventi BLoC
- Quando si refactorizza i componenti UI, assicurati che l'integrazione BLoC rimanga intatta
- Separa le modifiche allo stile UI dalla logica di business - modifica solo gli elementi visivi

## CRITICO: Sviluppo UI Responsivo

- **USA SEMPRE widget responsivi** quando si costruiscono layout UI
- Dai priorità a Flexible, Expanded e FractionallySizedBox rispetto alle dimensioni fisse
- Usa MediaQuery per misurazioni dipendenti dallo schermo quando necessario
- Implementa valori flex appropriati nei widget Column e Row
- Evita valori in pixel hardcoded - usa dimensionamenti e spaziature relative
- Assicurati che l'UI si adatti in modo elegante a diverse dimensioni e orientamenti dello schermo
- Testa i layout su varie dimensioni di dispositivo durante lo sviluppo

## OBBLIGATORIO: Commenti sul Percorso del File

- **OGNI file modificato DEVE includere un commento di percorso all'inizio**
- Formato: `// File: [percorso/esatto/del/file.dart]`
- Esempio: `// File: presentation/screens/recording/recording_entry_screen.dart`
- Questo commento è richiesto per TUTTI i file di codice senza eccezioni

## OBBLIGATORIO: Aggiornamenti dei File di Struttura

- **OGNI volta che viene aggiunto un file al progetto, fornisci ENTRAMBI i file aggiornati:**
  - idea_project_structure.txt aggiornato completo
  - project_structure.txt aggiornato completo
- **OGNI volta che idea_project_structure.txt viene modificato, fornisci il file aggiornato completo**
- Nessuna eccezione - entrambi i file di struttura devono essere sempre consegnati quando si aggiungono file
- Indica chiaramente quali modifiche sono state apportate e perché

## PRIMARIO: Requisiti di Coerenza

- Mantieni pattern di codice coerenti in tutto il progetto
- Segui le convenzioni di denominazione stabilite dai file esistenti
- Mantieni i pattern architetturali uniformi in tutti i componenti
- Garantisci coerenza UI/UX in tutte le schermate e i widget
- Mantieni la coerenza tematica in tutti gli elementi rivolti all'utente

## SECONDARIO: Approccio allo Sviluppo

- Fai sempre riferimento alla struttura del progetto prima di apportare modifiche
- Verifica che il posizionamento dei file corrisponda all'architettura definita
- Mantieni la separazione delle responsabilità come delineato nella struttura
- Segui le best practice di Flutter per la gestione dello stato e l'organizzazione dei widget
- Considera gli elementi tematici nella denominazione di variabili, classi e componenti UI

## CRITICO: Unica Fonte di Verità

- Ogni servizio deve essere inizializzato in UN SOLO posto (`dependency_injection.dart`)
- NON inizializzare mai un servizio sia in `main.dart` che in un costruttore BLoC
- NON avere mai due sistemi paralleli per la stessa responsabilità (es. due database helper)
- Tutti i singleton globali devono essere registrati tramite GetIt, non come variabili `late final` in `main.dart`

## CRITICO: Pattern di Gestione degli Errori

- USA SEMPRE `Either<Failure, Success>` da dartz nei repository e nei use case
- NON mischiare mai ritorni booleani, eccezioni lanciate e oggetti Result nello stesso layer
- I repository restituiscono `Either`, i BLoC consumano `.fold()` — nessuna eccezione deve risalire fino all'UI
- Definisci tutti i tipi di Failure in `core/errors/failures.dart`

## CRITICO: Gestione delle Dipendenze

- NON aggiungere mai una dipendenza senza usarla — rimuovi gli import inutilizzati da `pubspec.yaml`
- Controlla lo stato di manutenzione su pub.dev prima di aggiungere nuovi package (preferisci package con aggiornamenti recenti)
- Per la registrazione audio: usa solo il package `record`
- Per la riproduzione audio: usa solo `just_audio`
- NON aggiungere mai un package che duplica funzionalità già coperte da una dipendenza esistente

## CRITICO: Inizializzazione Idempotente

- TUTTI i metodi `initialize()` devono essere idempotenti (sicuri da chiamare più volte)
- Aggiungi un guard `_isInitialized` a ogni servizio che ha un metodo `initialize()`
- Documenta l'ordine di chiamata previsto se l'ordine di inizializzazione è importante

## WORKFLOW: Prima di Ogni Modifica al Codice

1. Controlla idea_project_structure.txt per il corretto posizionamento dei file
2. Aggiungi il commento obbligatorio sul percorso del file
3. Verifica che il file non superi le 500 righe dopo le modifiche
4. Se si aggiungono nuovi file, prepara idea_project_structure.txt E project_structure.txt aggiornati
5. Se 400+ righe sono inevitabili, ristruttura e fornisci i file di struttura aggiornati
6. Assicurati che le modifiche siano allineate con i pattern esistenti del progetto
7. Verifica che non venga referenziato materiale protetto da copyright

---

## CONTESTO DEL PROGETTO

**WavNote** è un'applicazione Flutter per memo vocali. L'app si concentra sulla creazione di un'esperienza user-friendly per la registrazione e l'organizzazione audio.

### Architettura
- **Clean Architecture** con chiara separazione delle responsabilità
- **Pattern BLoC** per la gestione dello stato
- **Pattern Repository** per l'accesso ai dati
- **Pattern Use Case** per la logica di business

### Funzionalità Principali
- Registrazione audio con denominazione basata sulla geolocalizzazione
- Organizzazione basata su cartelle
- Ricerca e filtri avanzati
- UI pulita con animazioni fluide
- Funzionalità di export e condivisione

### Stato di Sviluppo
- Funzionalità core di registrazione/riproduzione completate
- Servizi di gestione file implementati
- Denominazione delle registrazioni basata sulla geolocalizzazione
- Sistema avanzato di ricerca e filtri
