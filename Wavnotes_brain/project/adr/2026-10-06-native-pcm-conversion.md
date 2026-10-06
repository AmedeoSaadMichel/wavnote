# Convertitore PCM nativo condiviso — 2026-10-06

## Contesto

La callback del tap duplicava/perdeva buffer su iOS/macOS quando serviva AVAudioConverter. Il file dell’iPhone mostrava ripetizioni da 100 ms. Test Flutter del contratto non possono verificare la continuità PCM.

## Decisione

Isolare conversione incrementale e flush/reset in `ios/Shared/RecordingPCMConverter.swift`, compilato da entrambi i target. Testare lo stesso sorgente con swiftc e AVFoundation su macOS, senza dipendenza da Flutter. Aggiungere il test nativo alla CI macOS.

## Conseguenze

Plugin macOS separato in file principale, playback e conversione per rispettare il limite delle 800 righe, senza modificare il corpo dei metodi estratti. Nessuna duplicazione dell’algoritmo tra piattaforme. Test di durata/continuità e segmentazione sul componente effettivamente usato dall’app. La validazione di route/hardware iPhone resta necessaria.

- [[analysis/2026-10-06-audio-quality]]
- [[project/tech-debt]]
- [[_index]]

## Estensione: trim senza discontinuità

`PCMTrim.swift` condivide estrazione e overwrite WAV tra i due plugin. L'inviluppo opera su campioni PCM prima dell'eventuale export AppleM4A, senza cambiare la durata; lo stesso codice viene esercitato dai test nativi su file reali. Il file destinazione viene pubblicato solo dopo la chiusura del writer.
