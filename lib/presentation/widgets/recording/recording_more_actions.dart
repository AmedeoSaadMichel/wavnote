// File: lib/presentation/widgets/recording/recording_more_actions.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'recording_name_dialog.dart';
import '../../../domain/entities/recording_entity.dart';
import '../../../services/file/recording_file_actions_service.dart';

enum RecordingMoreAction { rename, reveal, share }

class RecordingMoreActions extends StatelessWidget {
  final String name;
  const RecordingMoreActions({super.key, required this.name});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Rinomina'),
          onTap: () => Navigator.pop(context, RecordingMoreAction.rename),
        ),
        ListTile(
          leading: const Icon(Icons.folder_open),
          title: Text(
            defaultTargetPlatform == TargetPlatform.macOS
                ? 'Mostra nel Finder'
                : 'Mostra file',
          ),
          onTap: () => Navigator.pop(context, RecordingMoreAction.reveal),
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text('Condividi'),
          onTap: () => Navigator.pop(context, RecordingMoreAction.share),
        ),
      ],
    ),
  );
}

Future<void> showRecordingMoreActions(
  BuildContext context,
  RecordingEntity recording, {
  required RecordingFileActionsService fileActions,
  required ValueChanged<String> onRename,
}) async {
  final action = await showModalBottomSheet<RecordingMoreAction>(
    context: context,
    builder: (_) => RecordingMoreActions(name: recording.name),
  );
  if (!context.mounted || action == null) return;
  if (action == RecordingMoreAction.rename) {
    final name = await showRecordingNameDialog(context, recording.name);
    if (context.mounted && name != null && name != recording.name) {
      onRename(name);
    }
    return;
  }
  final result = action == RecordingMoreAction.reveal
      ? await fileActions.reveal(recording.filePath)
      : await fileActions.share(recording.filePath);
  if (!context.mounted) return;
  result.fold(
    (failure) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.userMessage))),
    (_) {},
  );
}
