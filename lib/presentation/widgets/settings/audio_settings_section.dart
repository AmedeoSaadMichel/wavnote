// File: presentation/widgets/settings/audio_settings_section.dart
import 'package:flutter/material.dart';
import '../../../core/enums/audio_format.dart';
import '../../../core/constants/app_constants.dart';
import '../dialogs/audio_format_dialog.dart';

/// Audio settings section widget
class AudioSettingsSection extends StatelessWidget {
  const AudioSettingsSection({
    super.key,
    required this.selectedFormat,
    required this.selectedSampleRate,
    required this.selectedBitRate,
    required this.onFormatChanged,
    required this.onSampleRateChanged,
    required this.onBitRateChanged,
  });

  final AudioFormat selectedFormat;
  final int selectedSampleRate;
  final int selectedBitRate;
  final ValueChanged<AudioFormat> onFormatChanged;
  final ValueChanged<int> onSampleRateChanged;
  final ValueChanged<int> onBitRateChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        _buildSectionHeader(),

        // Audio format setting
        _buildSettingItem(
          title: 'Audio Format',
          subtitle: selectedFormat.description,
          value: selectedFormat.name,
          icon: selectedFormat.icon,
          iconColor: selectedFormat.color,
          onTap: () => _showAudioFormatDialog(context),
        ),

        // Sample rate setting
        _buildSettingItem(
          title: 'Sample Rate',
          subtitle: 'Audio quality setting',
          value: '$selectedSampleRate Hz',
          icon: Icons.tune,
          iconColor: AppConstants.accentCyan,
          onTap: () => _showSampleRateDialog(context),
        ),

        // Bit rate setting
        _buildSettingItem(
          title: 'Bit Rate',
          subtitle: 'Audio compression setting',
          value: '${selectedBitRate ~/ 1000}k',
          icon: Icons.compress,
          iconColor: Colors.orange,
          onTap: () => _showBitRateDialog(context),
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
              color: AppConstants.primaryPink.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.audiotrack,
              color: AppConstants.primaryPink,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio Settings',
                  style: AppConstants.titleMedium.copyWith(
                    color: AppConstants.accentYellow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure audio format and quality',
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

  /// Build individual setting item
  Widget _buildSettingItem({
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          child: Container(
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
                if (value.isNotEmpty) ...[
                  Text(
                    value,
                    style: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.accentCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show audio format dialog
  void _showAudioFormatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AudioFormatDialog(
          currentFormat: selectedFormat,
          onFormatSelected: (format) {
            onFormatChanged(format);
          },
        );
      },
    );
  }

  /// Show sample rate dialog
  void _showSampleRateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _buildSampleRateDialog(context);
      },
    );
  }

  /// Show bit rate dialog
  void _showBitRateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _buildBitRateDialog(context);
      },
    );
  }

  /// Build sample rate selection dialog
  Widget _buildSampleRateDialog(BuildContext context) {
    final sampleRates = selectedFormat.supportedSampleRates;

    return AlertDialog(
      backgroundColor: AppConstants.backgroundDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      title: Row(
        children: [
          Icon(Icons.tune, color: AppConstants.accentCyan),
          const SizedBox(width: 12),
          const Text(
            'Select Sample Rate',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: sampleRates.map((rate) {
          return ListTile(
            title: Text(
              '$rate Hz',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              _getSampleRateDescription(rate),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            trailing: selectedSampleRate == rate
                ? Icon(Icons.check, color: AppConstants.accentYellow)
                : null,
            onTap: () {
              onSampleRateChanged(rate);
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      ),
    );
  }

  /// Build bit rate selection dialog
  Widget _buildBitRateDialog(BuildContext context) {
    final bitRates = [64000, 128000, 192000, 256000, 320000];

    return AlertDialog(
      backgroundColor: AppConstants.backgroundDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      title: Row(
        children: [
          Icon(Icons.compress, color: Colors.orange),
          const SizedBox(width: 12),
          const Text(
            'Select Bit Rate',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: bitRates.map((rate) {
          return ListTile(
            title: Text(
              '${rate ~/ 1000}k',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              _getBitRateDescription(rate),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            trailing: selectedBitRate == rate
                ? Icon(Icons.check, color: AppConstants.accentYellow)
                : null,
            onTap: () {
              onBitRateChanged(rate);
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      ),
    );
  }

  /// Get sample rate description
  String _getSampleRateDescription(int sampleRate) {
    switch (sampleRate) {
      case 8000:
        return 'Phone quality';
      case 16000:
        return 'Voice recording';
      case 22050:
        return 'FM radio quality';
      case 44100:
        return 'CD quality';
      case 48000:
        return 'Professional quality';
      case 96000:
        return 'High-end audio';
      default:
        return 'Custom quality';
    }
  }

  /// Get bit rate description
  String _getBitRateDescription(int bitRate) {
    switch (bitRate) {
      case 64000:
        return 'Voice, small files';
      case 128000:
        return 'Good quality, balanced';
      case 192000:
        return 'High quality';
      case 256000:
        return 'Very high quality';
      case 320000:
        return 'Maximum quality';
      default:
        return 'Custom quality';
    }
  }
}