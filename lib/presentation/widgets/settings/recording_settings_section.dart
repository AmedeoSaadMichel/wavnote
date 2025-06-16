// File: presentation/widgets/settings/recording_settings_section.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Recording settings section widget
///
/// Manages recording-specific configuration options including
/// location recording, waveform visualization, quality presets,
/// auto-stop settings, and background recording permissions.
class RecordingSettingsSection extends StatelessWidget {
  const RecordingSettingsSection({
    super.key,
    required this.enableLocationRecording,
    required this.enableWaveformVisualization,
    required this.onLocationChanged,
    required this.onWaveformChanged,
  });

  // Current settings values
  final bool enableLocationRecording;
  final bool enableWaveformVisualization;

  // Callback functions
  final ValueChanged<bool> onLocationChanged;
  final ValueChanged<bool> onWaveformChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        _buildSectionHeader(),

        // Location recording toggle
        _buildToggleItem(
          title: 'Location Recording',
          subtitle: 'Add GPS coordinates to recordings',
          value: enableLocationRecording,
          onChanged: onLocationChanged,
          icon: Icons.location_on,
          iconColor: Colors.green,
        ),

        // Waveform visualization toggle
        _buildToggleItem(
          title: 'Waveform Visualization',
          subtitle: 'Show real-time audio waveforms',
          value: enableWaveformVisualization,
          onChanged: onWaveformChanged,
          icon: Icons.graphic_eq,
          iconColor: AppConstants.primaryPink,
        ),
      ],
    );
  }

  /// Build section header
  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.mic,
              color: Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recording Settings',
                  style: AppConstants.titleMedium.copyWith(
                    color: AppConstants.accentYellow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure recording behavior and features',
                  style: AppConstants.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build toggle setting item
  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppConstants.surfacePurple.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppConstants.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppConstants.bodyMedium,
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppConstants.accentYellow,
            activeTrackColor: AppConstants.accentYellow.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}