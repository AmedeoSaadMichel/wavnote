# wavnote

Voice memo app for ios

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Importare Memo Vocali Apple

### Da Memo Vocali su iPhone

Aprire una cartella di registrazioni in WavNote e premere **Importa Memo Vocali**
(icona di importazione nella barra superiore). Aprire quindi Memo Vocali Apple
manualmente dalla schermata Home, come indicato nella guida.

1. In Memo Vocali toccare **Modifica/Seleziona** e selezionare una o più registrazioni.
2. Toccare **Condividi → WavNote**. Se WavNote non compare, cercarla sotto **Altro**.
3. Per registrazioni con livelli o effetti, scegliere **M4A/audio renderizzato**
   nelle opzioni di condivisione.
4. Attendere la ricezione nell’estensione, toccare **Fine** e aprire WavNote.

Gli audio condivisi vengono importati automaticamente in **Tutte le registrazioni**
alla prima apertura o al ritorno in primo piano. Se è in corso una registrazione,
l’importazione attende la fine della sessione. Una coda persistente conserva i file
fino al salvataggio nel database; il recupero dopo un’interruzione non crea duplicati.
Condividere nuovamente lo stesso memo crea invece una nuova copia.
L’utente deve selezionare gli audio e avviare la condivisione nell’app Apple.

### Da file esportati su iPhone o Mac

Scegliere **Seleziona file** per una selezione multipla, oppure **Importa cartella**
per tutti i file M4A, WAV e FLAC, incluse le sottocartelle. I file selezionati vengono
salvati nella cartella di WavNote aperta al momento dell’importazione.

WavNote conserva i nomi, legge durata e frequenza di campionamento dall’audio,
usa la data di creazione del file ricevuto/esportato e conserva gli originali.
Un file non valido non interrompe gli altri import. Gli audio condivisi non salvati
rimangono nella coda e vengono ritentati alla successiva apertura.

### Configurazione iOS e verifica

Il target **WavNoteShareExtension** è incluso nella build di Runner. Runner e
l’estensione usano l’App Group `group.com.amedeosaadmichel.wavnote`.
Per una build su iPhone, registrare/abilitare questo gruppo per entrambi gli App ID
nel team Apple Developer, oppure lasciare che Xcode gestisca i profili tramite firma
automatica. Il gruppo condiviso è separato da quelli Apple di Memo Vocali.
La guida richiede l’apertura manuale di Memo Vocali: il collegamento provato non
funziona sul dispositivo reale.

Controlli mirati:

```sh
flutter test test/unit/services/voice_memo_import_service_test.dart test/unit/widgets/voice_memo_import_dialog_test.dart test/unit/widgets/shared_audio_import_listener_test.dart
flutter build ios --simulator --debug --no-pub
xcrun swiftc ios/Shared/SharedAudioInbox.swift test/native/share_import/main.swift -o /tmp/wavnote-share-inbox-test
/tmp/wavnote-share-inbox-test
```

Sul dispositivo verificare anche: visibilità di WavNote nel menu Condividi di Memo
Vocali, selezione multipla, riapertura a processo terminato e conservazione degli
originali. Il simulatore e i test della coda non sostituiscono questa prova con Memo
Vocali Apple su un iPhone reale.
