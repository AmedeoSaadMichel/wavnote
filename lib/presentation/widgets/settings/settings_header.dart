// File: presentation/widgets/settings/settings_header.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Header widget for the settings screen
class SettingsHeader extends StatelessWidget {
  const SettingsHeader({
    super.key,
    required this.onSave,
  });

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Settings',
            style: AppConstants.titleLarge,
          ),
          const Spacer(),
          IconButton(
            onPressed: onSave,
            icon: const Icon(
              Icons.check,
              color: AppConstants.accentYellow,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}