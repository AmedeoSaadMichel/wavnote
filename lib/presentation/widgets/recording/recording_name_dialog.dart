// File: lib/presentation/widgets/recording/recording_name_dialog.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

Future<String?> showRecordingNameDialog(BuildContext context, String name) =>
    showDialog<String>(
      context: context,
      builder: (_) => _RenameRecordingDialog(name: name),
    );

class _RenameRecordingDialog extends StatefulWidget {
  final String name;
  const _RenameRecordingDialog({required this.name});
  @override
  State<_RenameRecordingDialog> createState() => _RenameRecordingDialogState();
}

class _RenameRecordingDialogState extends State<_RenameRecordingDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rinomina registrazione'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Nome'),
        validator: (value) => AppConstants.isValidRecordingName(value ?? '')
            ? null
            : 'Inserisci un nome valido senza caratteri / \\ : * ? " < > |.',
        onFieldSubmitted: (_) => _save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      FilledButton(onPressed: _save, child: const Text('Salva')),
    ],
  );
}
