// File: lib/presentation/widgets/recording/editable_recording_title.dart
import 'package:flutter/material.dart';
import 'recording_name_dialog.dart';

class EditableRecordingTitle extends StatelessWidget {
  final String title;
  final Widget child;
  final ValueChanged<String>? onChanged;
  const EditableRecordingTitle({
    super.key,
    required this.title,
    required this.child,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: onChanged != null,
    hint: onChanged != null ? 'Tocca per rinominare la registrazione' : null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null
          ? null
          : () async {
              final name = await showRecordingNameDialog(context, title);
              if (context.mounted && name != null && name != title) {
                onChanged?.call(name);
              }
            },
      child: child,
    ),
  );
}
