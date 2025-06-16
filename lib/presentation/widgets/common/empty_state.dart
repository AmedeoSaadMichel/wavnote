// File: presentation/widgets/common/empty_state.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'custom_button.dart';

/// Empty state widget with cosmic styling
///
/// Displays when lists or collections are empty, providing
/// visual feedback and optional actions for users.
class EmptyState extends StatefulWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.illustration,
    this.actionText,
    this.onActionPressed,
    this.type = EmptyStateType.general,
    this.size = EmptyStateSize.medium,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? illustration;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final EmptyStateType type;
  final EmptyStateSize size;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _getEmptyStateConfig();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildEmptyStateContent(config),
          ),
        );
      },
    );
  }

  /// Build empty state content
  Widget _buildEmptyStateContent(EmptyStateConfig config) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(config.padding),
        constraints: BoxConstraints(
          maxWidth: config.maxWidth,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration or icon
            _buildVisual(config),

            SizedBox(height: config.spacing),

            // Title
            _buildTitle(config),

            // Subtitle
            if (widget.subtitle != null) ...[
              SizedBox(height: config.spacing * 0.5),
              _buildSubtitle(config),
            ],

            // Action button
            if (widget.actionText != null && widget.onActionPressed != null) ...[
              SizedBox(height: config.spacing * 1.5),
              _buildActionButton(config),
            ],
          ],
        ),
      ),
    );
  }

  /// Build visual element (illustration or icon)
  Widget _buildVisual(EmptyStateConfig config) {
    if (widget.illustration != null) {
      return SizedBox(
        width: config.visualSize,
        height: config.visualSize,
        child: widget.illustration!,
      );
    }

    return Container(
      width: config.visualSize,
      height: config.visualSize,
      decoration: BoxDecoration(
        color: config.iconBackgroundColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: config.iconBackgroundColor.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Icon(
        widget.icon ?? config.defaultIcon,
        size: config.iconSize,
        color: config.iconColor,
      ),
    );
  }

  /// Build title text
  Widget _buildTitle(EmptyStateConfig config) {
    return Text(
      widget.title,
      style: TextStyle(
        color: Colors.white,
        fontSize: config.titleSize,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Build subtitle text
  Widget _buildSubtitle(EmptyStateConfig config) {
    return Text(
      widget.subtitle!,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: config.subtitleSize,
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Build action button
  Widget _buildActionButton(EmptyStateConfig config) {
    return CustomButton(
      text: widget.actionText!,
      onPressed: widget.onActionPressed,
      variant: config.buttonVariant,
      size: config.buttonSize,
      icon: config.actionIcon,
    );
  }

  /// Get empty state configuration
  EmptyStateConfig _getEmptyStateConfig() {
    switch (widget.type) {
      case EmptyStateType.recordings:
        return EmptyStateConfig.recordings(widget.size);
      case EmptyStateType.folders:
        return EmptyStateConfig.folders(widget.size);
      case EmptyStateType.search:
        return EmptyStateConfig.search(widget.size);
      case EmptyStateType.error:
        return EmptyStateConfig.error(widget.size);
      case EmptyStateType.general:
        return EmptyStateConfig.general(widget.size);
    }
  }
}

/// Empty state types
enum EmptyStateType {
  recordings,  // No recordings in folder
  folders,     // No folders created
  search,      // No search results
  error,       // Error state
  general,     // General empty state
}

/// Empty state sizes
enum EmptyStateSize {
  small,
  medium,
  large,
}

/// Empty state configuration
class EmptyStateConfig {
  final double visualSize;
  final double iconSize;
  final double titleSize;
  final double subtitleSize;
  final double spacing;
  final double padding;
  final double maxWidth;
  final Color iconColor;
  final Color iconBackgroundColor;
  final IconData defaultIcon;
  final IconData? actionIcon;
  final ButtonVariant buttonVariant;
  final ButtonSize buttonSize;

  const EmptyStateConfig({
    required this.visualSize,
    required this.iconSize,
    required this.titleSize,
    required this.subtitleSize,
    required this.spacing,
    required this.padding,
    required this.maxWidth,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.defaultIcon,
    this.actionIcon,
    this.buttonVariant = ButtonVariant.primary,
    this.buttonSize = ButtonSize.medium,
  });

  /// Recordings empty state
  factory EmptyStateConfig.recordings(EmptyStateSize size) {
    final sizeMultiplier = _getSizeMultiplier(size);
    return EmptyStateConfig(
      visualSize: 120 * sizeMultiplier,
      iconSize: 60 * sizeMultiplier,
      titleSize: 24 * sizeMultiplier,
      subtitleSize: 16 * sizeMultiplier,
      spacing: 20 * sizeMultiplier,
      padding: 32 * sizeMultiplier,
      maxWidth: 300,
      iconColor: AppConstants.primaryPink,
      iconBackgroundColor: AppConstants.primaryPink,
      defaultIcon: Icons.mic_none,
      actionIcon: Icons.fiber_manual_record,
      buttonVariant: ButtonVariant.primary,
      buttonSize: size == EmptyStateSize.small ? ButtonSize.small : ButtonSize.medium,
    );
  }

  /// Folders empty state
  factory EmptyStateConfig.folders(EmptyStateSize size) {
    final sizeMultiplier = _getSizeMultiplier(size);
    return EmptyStateConfig(
      visualSize: 120 * sizeMultiplier,
      iconSize: 60 * sizeMultiplier,
      titleSize: 24 * sizeMultiplier,
      subtitleSize: 16 * sizeMultiplier,
      spacing: 20 * sizeMultiplier,
      padding: 32 * sizeMultiplier,
      maxWidth: 300,
      iconColor: AppConstants.accentYellow,
      iconBackgroundColor: AppConstants.accentYellow,
      defaultIcon: Icons.folder_outlined,
      actionIcon: Icons.add,
      buttonVariant: ButtonVariant.accent,
      buttonSize: size == EmptyStateSize.small ? ButtonSize.small : ButtonSize.medium,
    );
  }

  /// Search empty state
  factory EmptyStateConfig.search(EmptyStateSize size) {
    final sizeMultiplier = _getSizeMultiplier(size);
    return EmptyStateConfig(
      visualSize: 100 * sizeMultiplier,
      iconSize: 50 * sizeMultiplier,
      titleSize: 22 * sizeMultiplier,
      subtitleSize: 14 * sizeMultiplier,
      spacing: 16 * sizeMultiplier,
      padding: 24 * sizeMultiplier,
      maxWidth: 280,
      iconColor: AppConstants.accentCyan,
      iconBackgroundColor: AppConstants.accentCyan,
      defaultIcon: Icons.search_off,
      buttonVariant: ButtonVariant.secondary,
      buttonSize: ButtonSize.small,
    );
  }

  /// Error empty state
  factory EmptyStateConfig.error(EmptyStateSize size) {
    final sizeMultiplier = _getSizeMultiplier(size);
    return EmptyStateConfig(
      visualSize: 100 * sizeMultiplier,
      iconSize: 50 * sizeMultiplier,
      titleSize: 22 * sizeMultiplier,
      subtitleSize: 14 * sizeMultiplier,
      spacing: 16 * sizeMultiplier,
      padding: 24 * sizeMultiplier,
      maxWidth: 280,
      iconColor: Colors.red,
      iconBackgroundColor: Colors.red,
      defaultIcon: Icons.error_outline,
      actionIcon: Icons.refresh,
      buttonVariant: ButtonVariant.danger,
      buttonSize: ButtonSize.small,
    );
  }

  /// General empty state
  factory EmptyStateConfig.general(EmptyStateSize size) {
    final sizeMultiplier = _getSizeMultiplier(size);
    return EmptyStateConfig(
      visualSize: 100 * sizeMultiplier,
      iconSize: 50 * sizeMultiplier,
      titleSize: 20 * sizeMultiplier,
      subtitleSize: 14 * sizeMultiplier,
      spacing: 16 * sizeMultiplier,
      padding: 24 * sizeMultiplier,
      maxWidth: 280,
      iconColor: Colors.white.withValues(alpha: 0.6),
      iconBackgroundColor: Colors.white.withValues(alpha: 0.6),
      defaultIcon: Icons.inbox_outlined,
      buttonVariant: ButtonVariant.secondary,
      buttonSize: ButtonSize.small,
    );
  }

  /// Get size multiplier
  static double _getSizeMultiplier(EmptyStateSize size) {
    switch (size) {
      case EmptyStateSize.small:
        return 0.8;
      case EmptyStateSize.medium:
        return 1.0;
      case EmptyStateSize.large:
        return 1.2;
    }
  }
}