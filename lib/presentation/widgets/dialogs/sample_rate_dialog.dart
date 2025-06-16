// File: presentation/widgets/dialogs/sample_rate_dialog.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Dialog for selecting sample rate
class SampleRateDialog extends StatelessWidget {
  const SampleRateDialog({
    super.key,
    required this.currentSampleRate,
    required this.supportedRates,
    required this.onSampleRateSelected,
  });

  final int currentSampleRate;
  final List<int> supportedRates;
  final ValueChanged<int> onSampleRateSelected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppConstants.backgroundDark,
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 20),

            // Sample rate options
            _buildSampleRateOptions(context),
            const SizedBox(height: 20),

            // Action buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  /// Build dialog header
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConstants.accentCyan.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.tune,
            color: AppConstants.accentCyan,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Sample Rate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose audio quality setting',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build sample rate options
  Widget _buildSampleRateOptions(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          children: supportedRates.map((rate) {
            final isSelected = currentSampleRate == rate;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    onSampleRateSelected(rate);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppConstants.accentCyan.withValues(alpha: 0.1)
                          : AppConstants.surfacePurple.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppConstants.accentCyan
                            : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Rate info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$rate Hz',
                                style: TextStyle(
                                  color: isSelected
                                      ? AppConstants.accentCyan
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getSampleRateDescription(rate),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Quality indicator
                        _buildQualityIndicator(rate),
                        const SizedBox(width: 12),

                        // Selection indicator
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppConstants.accentCyan,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          )
                        else
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Build quality indicator
  Widget _buildQualityIndicator(int sampleRate) {
    final qualityLevel = _getQualityLevel(sampleRate);
    final color = _getQualityColor(qualityLevel);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Container(
          margin: const EdgeInsets.only(right: 2),
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: index < qualityLevel
                ? color
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  /// Get sample rate description
  String _getSampleRateDescription(int sampleRate) {
    switch (sampleRate) {
      case 8000:
        return 'Phone quality - Basic voice calls';
      case 16000:
        return 'Voice recording - Clear speech';
      case 22050:
        return 'FM radio quality - Good balance';
      case 44100:
        return 'CD quality - Professional standard';
      case 48000:
        return 'Professional quality - Studio grade';
      case 96000:
        return 'High-end audio - Audiophile quality';
      default:
        return 'Custom quality setting';
    }
  }

  /// Get quality level (1-5 bars)
  int _getQualityLevel(int sampleRate) {
    switch (sampleRate) {
      case 8000:
        return 1;
      case 16000:
        return 2;
      case 22050:
        return 3;
      case 44100:
        return 4;
      case 48000:
      case 96000:
        return 5;
      default:
        return 3;
    }
  }

  /// Get quality color based on level
  Color _getQualityColor(int level) {
    switch (level) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return AppConstants.accentCyan;
    }
  }
}