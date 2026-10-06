# Bip durante la riproduzione dopo trim

Il percorso PCM iOS in `AudioTrimmerPlugin.swift:439–470` estrae campioni senza inviluppo ai bordi. Il playback (`AudioEnginePlugin+Playback.swift`) avvia/ferma il nodo senza rampa di volume, incluso il seek. Questi punti possono introdurre discontinuità udibili come click o breve bip quando il campione al confine è diverso da zero.

È un meccanismo plausibile verificato nel codice, non una causa confermata sul segnale segnalato: manca il file dopo trim e la posizione del bip (avvio/fine/giunzione oppure durante il contenuto). Non risultano toni intenzionali nei percorsi esaminati. Nessuna modifica al motore applicata in questa analisi. Possibile intervento: micro-fade ai bordi del taglio e/o rampa del playback, scelto dopo localizzazione dell’artefatto.

## Correzione applicata

Helper condiviso `ios/Shared/PCMTrim.swift`: rampe lineari di 5 ms su inizio/fine dei segmenti, ridotte sui segmenti corti; indicizzazione assoluta tra blocchi, canali float elaborati tutti. Integrato nei plugin trimmer iOS/macOS per trim WAV/M4A e overwrite WAV (preview e giunzioni del flusso di registrazione). Durata PCM preservata; parte centrale invariata. M4A: staging PCM sfumato e export con lo stesso preset AppleM4A precedente. Scrittura temporanea e pubblicazione dopo chiusura, anche in-place. Compatibilità iOS con chiave `filePath` inviata dal servizio Flutter e `inputPath` del coordinator.

TDD: senza inviluppo 24 verifiche falliscono; test con file stereo reali a 16/44.1/48 kHz, segmenti 1/8/250 ms, blocchi multipli e due giunzioni. Test aggiuntivi per export M4A e sostituzione in-place. La causa del bip sul device resta da confermare con riascolto; seek/player non modificati.

Validazione conclusa: suite nativa completa verde, inclusi AAC e in-place; build iOS debug no-codesign e macOS debug riuscite; progetti Xcode validati con plutil e diff senza errori di whitespace. I test AAC devono accedere ai servizi encoder macOS: nel sandbox restrittivo falliscono con `fmt?`, fuori dal sandbox passano.
