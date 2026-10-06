# Qualità audio: analisi e fix — 2026-10-06

Analizzato il file AAC fornito dall’utente (iPhone 14): 20 coppie di blocchi consecutivi da 100 ms quasi identici, picco -1.64 dBFS, nessun campione a fondo scala. Riprodotto il bug in AVAudioConverter con segnale sintetico e codice precedente; TDD nativo RED → GREEN.

Applicato `RecordingPCMConverter` condiviso, registrato nei due progetti Xcode, integrato nel tap e nel flush/reset a pausa/stop/interruzione. Test nativo e job CI macOS aggiunti. Plugin macOS separato per responsabilità (main 771 righe) in conformità al limite CLAUDE; metodi estratti identici al precedente sorgente. Build iOS no-codesign e macOS debug riuscite, 275 test Flutter verdi.

Non modificate impostazioni qualità/BLoC/encoder M4A; rimangono aperte in tech-debt. Nessun commit/push di questo fix. Prossimo passo: registrazione nuova con app ricompilata su iPhone 14.

## Collegamenti

- [[project/features]]
- [[project/tech-debt]]
- [[project/hot]]
- [[project/adr/2026-10-06-native-pcm-conversion]]
- [[analysis/2026-10-06-audio-quality]]
- [[_index]]
