# Qualità audio e scatti — 2026-10-06

## Sintomo e perimetro

L’utente riferisce clipping frequente e qualità percepita bassa su iPhone 14, uscita normale, anche in registrazioni senza trim. Verificati acquisizione iOS/macOS, configurazione sessione, salvataggio PCM e M4A, playback nativo e collegamento impostazioni UI. Prima fase senza file reale dell’iPhone; nella seconda fase l’utente ha fornito una registrazione M4A, analizzata offline senza modificarla. I log della sessione sul dispositivo non sono disponibili.

## Bug verificato: conversione dei buffer di registrazione

`ios/Runner/AudioEnginePlugin+Recording.swift:138–143` e `macos/Runner/AudioEnginePlugin.swift:375–380` creano un buffer di uscita con la capacità del buffer di ingresso, senza adeguarla al rapporto delle frequenze. La callback restituisce sempre lo stesso buffer con `.haveData`, anche quando il convertitore lo ha già ricevuto.

Un convertitore può richiedere più input per riempire l’uscita, oppure non richiederne quando ha campioni interni residui. Il codice duplica il buffer nel primo caso e perde il nuovo buffer del tap nel secondo, poiché non conserva quello non consumato. La continuità dei campioni viene corrotta prima della scrittura del WAV. Non occorrono trim, saturazione né AAC per provocare il difetto.

### Riproduzione nativa offline

Eseguito AVAudioConverter reale su macOS con tono continuo di 997 Hz, ampiezza 0.25 (-12 dBFS), 200 blocchi da 1024 frame. Replica della capacità/callback corrente confrontata con un prototipo che fornisce ogni blocco una sola volta, poi `.noDataNow`, e dimensiona l’uscita per il rapporto delle frequenze.

| Conversione | Frame attesi | Frame codice attuale | Frame prototipo | Errore durata attuale |
|---|---:|---:|---:|---:|
| 48 → 44.1 kHz | 188160 | 204800 | 188145 | +8.84% |
| 44.1 → 48 kHz | 222911 | 204800 | 222894 | -8.13% |
| 16 → 44.1 kHz | 564480 | 204800 | 564435 | -63.72% |

A 48 → 44.1 kHz: 218 callback, 18 forniture duplicate; 19 salti tra campioni maggiori di 0.1, contro zero nel prototipo. Picco 0.277 e zero campioni saturati: la distorsione riprodotta non è hard clipping da livello eccessivo. Il residuo RMS rispetto al tono atteso è 0.1767 contro circa 0.00000145 nel prototipo; non è una misura THD.

Il prototipo non esegue il drain finale: la differenza residua di circa 15–45 frame rappresenta la coda non scaricata del resampler. È un esperimento diagnostico, non una patch pronta per produzione, né un test eseguito sull’iPhone.

Artefatti: `analysis/artifacts/2026-10-06-audio-quality/converter_probe.swift`, `signal_metrics.json`. Esecuzione: `swift -module-cache-path /private/tmp/wavnote-audio-module-cache Wavnotes_brain/analysis/artifacts/2026-10-06-audio-quality/converter_probe.swift /private/tmp/wavnote-audio-diagnosis`.

## Rilevanza per iPhone 14

Il flusso della schermata manda solo il formato in StartRecording; quindi chiede sempre 44100 Hz. `setPreferredSampleRate` è una preferenza, non prova della frequenza hardware effettiva. Il plugin legge correttamente `input.outputFormat` e crea il convertitore quando serve, ma quel percorso contiene il bug descritto. Se sull’iPhone l’input effettivo è 48 kHz e il WAV è 44.1 kHz, si attiva proprio il caso riprodotto. Senza i log `rawFormat` e `converter`, non è possibile attribuirgli con certezza il singolo caso dell’utente.

## Altri problemi confermati nel codice

1. **Impostazioni qualità non propagate:** `recording_list_logic.dart:485–490` passa solo `format`, ignorando sampleRate e bitRate configurati in SettingsLoaded. StartRecording ricade su 44100 Hz / 128000 bit/s. Il BLoC e il use case accetterebbero i valori, ma la schermata non li passa.
2. **Bitrate M4A ignorato nell’export:** requestedFormatSettings viene costruito, ma il ramo M4A chiama convertWAVToM4A senza settings. L’export usa AVAssetExportPresetAppleM4A: il bitrate richiesto non configura l’encoder. Questo non dimostra da solo la causa degli scatti.
3. **Indicatore waveform non misura il clipping:** RMS ×10, clamp a 1 (`Recording.swift:165`) serve solo al metadato UI. Non moltiplica i campioni audio scritti. Una barra piena non prova la saturazione del file.

## Rischi ulteriori, non dimostrati come causa

Nel tap avvengono allocazione buffer, conversione, scrittura sincrona su disco, logging e aggiornamenti Live Activity. Può creare ritardi e dropout sotto carico; non misurati nel presente audit. Il playback nativo non applica un guadagno aggiuntivo esplicito. L’adapter setVolume è un no-op, quindi manca un controllo del volume a livello motore. Alcuni percorsi di concatenazione ricreano il resampler per chunk o dichiarano endOfStream per chunk: da coprire separatamente, non necessari per il sintomo senza trim.

## Verifica della registrazione dell’iPhone fornita dall’utente

File M4A AAC mono, 44100 Hz, durata container 25.147211 s, bitrate stream 223752 bit/s. La decodifica FFmpeg produce 1106880 campioni (25.0993 s); differenza container/PCM dovuta a metadati/padding AAC, non conteggiata come prova di duplicazione. Picco PCM -1.644 dBFS, RMS -21.388 dBFS, zero campioni con ampiezza assoluta >= 0.999. Nessuna evidenza di hard clipping a fondo scala nel PCM decodificato; questo non esclude in assoluto distorsioni analogiche avvenute prima dell’encoding.

**Evidenza specifica:** 20 coppie di finestre consecutive di 4410 campioni (100 ms) hanno correlazione oltre 0.99 e RMS sufficiente per escludere il silenzio numerico. Tutte superano 0.9987; 19 superano 0.999. Le duplicazioni interessano anche tratti con livelli consistenti, non solo silenzi. Esempi:

| Primo tratto | Tratto ripetuto | Correlazione |
|---|---|---:|
| 2.4–2.5 s | 2.5–2.6 s | 0.999799 |
| 5.6–5.7 s | 5.7–5.8 s | 0.999759 |
| 6.8–6.9 s | 6.9–7.0 s | 0.999864 |
| 14.2–14.3 s | 14.3–14.4 s | 0.999698 |
| 16.7–16.8 s | 16.8–16.9 s | 0.999791 |

Le ripetizioni ricorrono perlopiù a intervalli di circa 1.2–1.3 s, compatibili con l’accumulo di differenza tra 48 e 44.1 kHz. Una scansione di controllo con finestre da 2048 frame mostra correlazione massima 0.999929 al ritardo esatto di 4410 campioni, contro <0.981 ai ritardi di controllo 2205, 3763, 4096, 4800 e 8820 campioni. Le differenze residue tra blocchi sono compatibili con l’encoding AAC; non sono copie bit-per-bit del PCM decodificato.

**Conclusione:** il difetto è incorporato nel file, quindi non è soltanto un artefatto del player o dell’altoparlante. La firma di duplicazioni da 100 ms supporta fortemente il bug del convertitore trovato nel sorgente e riprodotto con AVAudioConverter reale. La frequenza hardware effettiva 48 kHz rimane un’inferenza, non un valore misurato sul dispositivo. L’AAC di questo file è circa 224 kbps, perciò 128 kbps non descrive il bitrate effettivo: conferma che il preset di export determina autonomamente l’encoding.

Metriche: `analysis/artifacts/2026-10-06-audio-quality/recording_metrics.json`. La registrazione originale e il PCM decodificato non sono copiati nel repository; sono conservati soltanto i risultati numerici dell’analisi.

## Prossimo passo

Il file esportato conferma già la duplicazione. Acquisire la frequenza reale dell’input e il conteggio dei frame sul dispositivo per completare la verifica del percorso hardware. Correggere il resampler con test di continuità/durata, capacità corretta, input fornito una volta, drain e gestione errori. Poi collegare qualità e bitrate realmente all’encoder. Non mascherare il problema con un limiter o abbassando il volume: il difetto riprodotto riguarda la continuità dei campioni.

## Correzione applicata su richiesta dell’utente

`ios/Shared/RecordingPCMConverter.swift` è compilato da entrambi i target Xcode. Fornisce ciascun buffer una volta, restituisce noDataNow quando è esaurito, dimensiona l’uscita su frameLength (non capacità inutilizzata) e rapporto delle frequenze, riutilizza il buffer di uscita e scarica tutte le uscite disponibili. A pausa/stop finish invia endOfStream, scrive la coda e resetta il convertitore per il segmento successivo. Contatore frame aggiornato anche con la coda; cancel scarta lo stato. Il flush avviene anche nell’interruzione iOS. NSLock serializza conversione e flush.

Test nativo del componente di produzione: `test/native/run_pcm_tests.sh`. 16 segmenti (4 conversioni × 2 dimensioni di blocco × 2 segmenti consecutivi), durata entro 1 frame, zero salti >0.1, residuo del tono <0.0001; verificati buffer vuoto e propagazione errori del consumer. La replica del vecchio percorso falliva 46 verifiche prima della correzione. Test aggiunto alla CI macOS con AVAudioConverter reale. Il plugin macOS superava il limite delle 800 righe: separati playback e conversione in due extension, mantenendo identico il corpo dei metodi (confronto col codice precedente); main a 771 righe, Playback a 357, Conversion a 174. La deroga inizialmente richiesta non è più necessaria.

Build iOS debug senza firma e macOS debug riuscite; suite Flutter completa 275 verdi. Nessuna verifica fisica sull’iPhone ancora effettuata: occorre ricompilare l’app e registrare un nuovo file. La registrazione originaria è rimasta invariata. Settings sampleRate/bitRate e bitrate export M4A restano aperti separatamente. Nessun commit/push del fix audio.

## Fonti primarie

- [Apple TN3136 — conversione sample rate](https://developer.apple.com/documentation/technotes/tn3136-avaudioconverter-performing-sample-rate-conversions)
- [Apple — AVAudioConverterInputStatus](https://developer.apple.com/documentation/avfaudio/avaudioconverterinputstatus)
- [Apple QA1631 — preferenze e frequenza reale della sessione](https://developer.apple.com/library/archive/qa/qa1631/_index.html)

## Collegamenti

- [[project/hot]]
- [[project/tech-debt]]
- [[project/features]]
- [[_index]]
