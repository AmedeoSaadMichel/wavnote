# Trim: ridisegno della UI — 2026-10-06

## Difetti riprodotti

Il test precedente verificava barre, colori e stato del widget, ma non geometria e titolo nei frame intermedi. La precedente conclusione di risoluzione era incompleta.

In RecordingStarting la schermata passa isPaused=false, isRecording=false, titolo predefinito e durata zero. RecordingFullscreenView sostituiva i controlli da 80 px con SizedBox.shrink. Dopo la transizione di 300 ms cambiavano i vincoli dei Flexible: nei widget test la waveform passava da 193.7 a 227.4 px e la scala verticale da 96.8 a 113.7. Le barre restavano presenti ma si spostavano e venivano riscalate. Il titolo personalizzato diventava temporaneamente New Recording.

## Correzione

- `lib/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart`: conserva lo slot da 80 px con controlli nascosti, mantenendo la transizione.
- `lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart`: conserva il titolo precedente all’ingresso in Starting durante la transizione della sessione esistente.
- `test/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_trim_test.dart`: due nuove regressioni con i parametri passati dalla schermata, verificando titolo, rettangolo waveform, offset painter, barre e identità dello stato a intervalli da 16/150/400 ms durante Starting e dopo la ripresa.

Preservati i fix precedenti su barre/colori già presenti. Nessuna modifica a BLoC, callback che emettono eventi, use case o plugin audio.

## Validazione

TDD sul codice locale: test precedente verde e due nuove regressioni rosse prima del fix; tutti verdi dopo. Suite correlata presentation/widget/workflow/overwrite/preview: 66 verdi. Analyzer sui tre file modificati: nessuna issue. Commit e push del fix autorizzati dall’utente sul branch `fix/macos-recording-status-frames`; escluse le modifiche non correlate a icone, asset e lockfile.

Verifica visiva su dispositivo ancora da eseguire: i test provano questi due difetti UI, ma non escludono altri sintomi specifici della piattaforma.

## Collegamenti

- [[project/hot]]
- [[project/tech-debt]]
- [[project/features]]
- [[_index]]
