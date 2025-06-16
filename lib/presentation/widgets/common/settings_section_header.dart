// File: presentation/widgets/common/settings_section_header.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Section header widget for settings
///
/// Provides consistent styling for section headers across
/// all settings screens with optional icons and descriptions.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.showDivider = false,
    this.padding,
  });

  /// The main title text for the section
  final String title;

  /// Optional subtitle text for additional context
  final String? subtitle;

  /// Optional icon to display before the title
  final IconData? icon;

  /// Color for the icon (defaults to accent yellow)
  final Color? iconColor;

  /// Whether to show a divider line above the header
  final bool showDivider;

  /// Custom padding (defaults to standard bottom padding)
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Optional divider
          if (showDivider) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],

          // Header content
          Row(
            children: [
              // Optional icon
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppConstants.accentYellow)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? AppConstants.accentYellow,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main title
                    Text(
                      title,
                      style: AppConstants.titleMedium.copyWith(
                        color: AppConstants.accentYellow,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // Optional subtitle
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: AppConstants.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Specialized header for audio settings sections
class AudioSettingsHeader extends StatelessWidget {
  const AudioSettingsHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionHeader(
      title: title,
      subtitle: subtitle,
      icon: Icons.audiotrack,
      iconColor: AppConstants.primaryPink,
    );
  }
}

/// Specialized header for recording settings sections
class RecordingSettingsHeader extends StatelessWidget {
  const RecordingSettingsHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionHeader(
      title: title,
      subtitle: subtitle,
      icon: Icons.mic,
      iconColor: Colors.red,
    );
  }
}

/// Specialized header for storage settings sections
class StorageSettingsHeader extends StatelessWidget {
  const StorageSettingsHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionHeader(
      title: title,
      subtitle: subtitle,
      icon: Icons.storage,
      iconColor: Colors.teal,
    );
  }
}

/// Specialized header for app settings sections
class AppSettingsHeader extends StatelessWidget {
  const AppSettingsHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionHeader(
      title: title,
      subtitle: subtitle,
      icon: Icons.settings,
      iconColor: Colors.blue,
    );
  }
}