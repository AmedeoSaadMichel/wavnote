// File: presentation/widgets/dialogs/audio_format_dialog.dart
import 'package:flutter/material.dart';
import '../../../core/enums/audio_format.dart';

/// Dialog for selecting audio recording format
///
/// Uses the centralized AudioFormat enum from core/enums
/// and follows the app's design system consistently.
class AudioFormatDialog extends StatefulWidget {
  final AudioFormat currentFormat;
  final Function(AudioFormat) onFormatSelected;

  const AudioFormatDialog({
    super.key,
    required this.currentFormat,
    required this.onFormatSelected,
  });

  @override
  State<AudioFormatDialog> createState() => _AudioFormatDialogState();
}

class _AudioFormatDialogState extends State<AudioFormatDialog>
    with SingleTickerProviderStateMixin {
  late AudioFormat _selectedFormat;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.currentFormat;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Select format and close dialog
  void _selectFormat() {
    widget.onFormatSelected(_selectedFormat);
    Navigator.of(context).pop();
  }

  /// Get all available format options
  List<AudioFormatOption> get _formatOptions {
    return AudioFormatOption.getAllOptions();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8E2DE2),
                    Color(0xFFDA22FF),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
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
                  const SizedBox(height: 24),

                  // Format Options
                  _buildFormatOptions(),
                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build dialog header with title and info
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Recording Format',
          style: TextStyle(
            color: Colors.pinkAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF5A2B8C).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: const Text(
            'Available formats for iOS',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Build list of format options
  Widget _buildFormatOptions() {
    return Column(
      children: _formatOptions.map((option) {
        final isSelected = option.format == _selectedFormat;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildFormatOptionItem(option, isSelected),
        );
      }).toList(),
    );
  }

  /// Build individual format option item
  Widget _buildFormatOptionItem(AudioFormatOption option, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFormat = option.format;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF5A2B8C).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.cyan
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.cyan.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            // Format Icon
            _buildFormatIcon(option, isSelected),
            const SizedBox(width: 16),

            // Format Details
            Expanded(
              child: _buildFormatDetails(option),
            ),

            // Quality Indicators
            _buildQualityIndicators(option),
            const SizedBox(width: 12),

            // Selection Indicator
            _buildSelectionIndicator(isSelected),
          ],
        ),
      ),
    );
  }

  /// Build format icon with background
  Widget _buildFormatIcon(AudioFormatOption option, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? option.color.withValues(alpha: 0.3)
            : option.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? option.color
              : option.color.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Icon(
        option.icon,
        color: option.color,
        size: 24,
      ),
    );
  }

  /// Build format details (name and description)
  Widget _buildFormatDetails(AudioFormatOption option) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          option.description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  /// Build quality indicators (stars for quality and file size)
  Widget _buildQualityIndicators(AudioFormatOption option) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Quality Rating
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quality',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            ...List.generate(5, (index) {
              return Icon(
                index < option.format.qualityRating
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.amber,
                size: 12,
              );
            }),
          ],
        ),
        const SizedBox(height: 4),

        // File Size Indicator
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Size',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            ...List.generate(5, (index) {
              return Icon(
                index < option.format.fileSizeRating
                    ? Icons.circle
                    : Icons.circle_outlined,
                color: Colors.orange,
                size: 8,
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Build selection indicator (radio button style)
  Widget _buildSelectionIndicator(bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.cyan : Colors.white54,
          width: 2,
        ),
        color: isSelected ? Colors.cyan : Colors.transparent,
      ),
      child: isSelected
          ? const Icon(
        Icons.check,
        color: Colors.white,
        size: 16,
      )
          : null,
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.cyanAccent.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _selectFormat,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 4,
          ),
          icon: const Icon(Icons.check, size: 18),
          label: const Text(
            'Select',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Info dialog showing format comparison
class AudioFormatInfoDialog extends StatelessWidget {
  const AudioFormatInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1B69),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Audio Format Guide',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ...AudioFormat.values.map((format) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(format.icon, color: format.color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            format.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            format.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.cyan),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}