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
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF6B46C1),
                    Color(0xFF9333EA),
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
    return const Text(
      'Select Recording Format',
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
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
        // Auto-select and close dialog
        widget.onFormatSelected(option.format);
        Navigator.of(context).pop();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
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

            // Selection Indicator
            _buildSelectionIndicator(isSelected),
          ],
        ),
      ),
    );
  }

  /// Build format icon with background
  Widget _buildFormatIcon(AudioFormatOption option, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: option.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        option.icon,
        color: Colors.white,
        size: 20,
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
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(
          'Cancel',
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
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