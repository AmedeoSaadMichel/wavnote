import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../domain/entities/folder_entity.dart';
import '../../../services/file/voice_memo_import_service.dart';

class VoiceMemoImportDialog extends StatefulWidget {
  final FolderEntity folder;
  final VoiceMemoImportService service;
  const VoiceMemoImportDialog({
    super.key,
    required this.folder,
    required this.service,
  });

  @override
  State<VoiceMemoImportDialog> createState() => _VoiceMemoImportDialogState();
}

class _VoiceMemoImportDialogState extends State<VoiceMemoImportDialog> {
  bool _busy = false;
  int _completed = 0;
  int _total = 0;
  VoiceMemoImportSummary? _summary;
  String? _error;

  Future<void> _import(bool folder) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.service.import(
        folder: widget.folder,
        selectFolder: folder,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _completed = completed;
              _total = total;
            });
          }
        },
      );
      if (mounted && (result.imported > 0 || result.failures.isNotEmpty)) {
        setState(() => _summary = result);
      } else if (mounted && folder) {
        setState(
          () => _error =
              'Nessuna registrazione selezionata. Scegli una cartella con file M4A, WAV o FLAC.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Impossibile aprire o importare i file. Riprova.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Importa Memo Vocali'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_summary == null) ...[
                if ((defaultTargetPlatform == TargetPlatform.iOS)) ...[
                  const Text(
                    'Apri Memo Vocali Apple dalla schermata Home.\n\n1. Tocca Modifica o Seleziona.\n2. Seleziona le registrazioni da importare.\n3. Tocca Condividi e scegli WavNote.\n4. Apri WavNote per completare l’importazione.\n\nSe WavNote non compare, scorri le app di condivisione e tocca Altro. Per audio con livelli o effetti, scegli M4A (audio renderizzato).',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gli audio condivisi vengono aggiunti a Tutte le registrazioni. Gli originali restano in Memo Vocali.',
                  ),
                  const Divider(),
                  const Text(
                    'Hai già esportato gli audio? Seleziona più file oppure una cartella, incluse le sottocartelle.',
                  ),
                ] else
                  const Text(
                    'Seleziona più file oppure una cartella per importarli tutti, incluse le sottocartelle. Gli originali vengono conservati.',
                  ),
                const SizedBox(height: 12),
                Text(
                  'Destinazione dei file selezionati: ${widget.folder.name}',
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _total > 0 ? _completed / _total : null,
                ),
                const SizedBox(height: 8),
                Text(
                  _total > 0
                      ? 'Importazione $_completed di $_total'
                      : 'Selezione e preparazione dei file…',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!),
              ],
              if (_summary != null) ...[
                Text('Registrazioni importate: ${_summary!.imported}'),
                if (_summary!.failures.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Non importate: ${_summary!.failures.length}'),
                  ..._summary!.failures.map(
                    (failure) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(failure),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(_summary == null ? 'Annulla' : 'Chiudi'),
        ),
        if (_summary == null) ...[
          TextButton(
            onPressed: _busy ? null : () => _import(true),
            child: const Text('Importa cartella'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _import(false),
            child: const Text('Seleziona file'),
          ),
        ],
      ],
    ),
  );
}
