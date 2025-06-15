// File: presentation/widgets/dialogs/create_folder_dialog.dart
import 'package:flutter/material.dart';

/// Simple dialog for creating a new custom folder
///
/// Uses callback pattern to avoid provider/bloc issues.
/// The parent widget handles the actual folder creation.
class CreateFolderDialog extends StatefulWidget {
  final Function(String name, Color color, IconData icon) onFolderCreated;

  const CreateFolderDialog({
    super.key,
    required this.onFolderCreated,
  });

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _isValidName = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() {
        _isValidName = _nameController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _createFolder() {
    if (_isValidName) {
      // Use default folder styling - orange color, folder icon
      widget.onFolderCreated(
        _nameController.text.trim(),
        Colors.orange,
        Icons.folder,
      );
      Navigator.of(context).pop(); // Close dialog
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.deepPurpleAccent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'Create New Folder',
              style: TextStyle(
                color: Colors.pinkAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Folder name input
            Text(
              'Folder name (required)',
              style: TextStyle(
                color: Colors.white.withValues( alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter folder name',
                hintStyle: TextStyle(color: Colors.white.withValues( alpha: 0.5)),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.yellowAccent),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.yellowAccent, width: 2),
                ),
              ),
              onSubmitted: (_) => _isValidName ? _createFolder() : null,
            ),
            const SizedBox(height: 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.cyanAccent.withValues( alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isValidName ? _createFolder : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValidName
                        ? Colors.transparent
                        : Colors.grey.withValues( alpha: 0.3),
                    foregroundColor: Colors.pinkAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Create',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}