// File: presentation/widgets/common/custom_button.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Custom button component with cosmic styling
///
/// Provides consistent button styling across the app with
/// multiple variants for different use cases.
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.width,
    this.height,
  });

  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isLoading;
  final bool isEnabled;
  final IconData? icon;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final buttonConfig = _getButtonConfig();
    final sizeConfig = _getSizeConfig();

    return Container(
      width: width ?? sizeConfig.width,
      height: height ?? sizeConfig.height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (isEnabled && !isLoading) ? onPressed : null,
          borderRadius: BorderRadius.circular(sizeConfig.borderRadius),
          child: Container(
            decoration: BoxDecoration(
              gradient: buttonConfig.gradient,
              color: buttonConfig.backgroundColor,
              borderRadius: BorderRadius.circular(sizeConfig.borderRadius),
              border: buttonConfig.border,
              boxShadow: (isEnabled && !isLoading) ? buttonConfig.boxShadow : null,
            ),
            child: Center(
              child: isLoading
                  ? _buildLoadingIndicator(buttonConfig)
                  : _buildButtonContent(buttonConfig, sizeConfig),
            ),
          ),
        ),
      ),
    );
  }

  /// Build button content with text and optional icon
  Widget _buildButtonContent(ButtonConfig config, SizeConfig sizeConfig) {
    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: config.textColor,
            size: sizeConfig.iconSize,
          ),
          SizedBox(width: sizeConfig.spacing),
          Text(
            text,
            style: TextStyle(
              color: config.textColor,
              fontSize: sizeConfig.fontSize,
              fontWeight: config.fontWeight,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        color: config.textColor,
        fontSize: sizeConfig.fontSize,
        fontWeight: config.fontWeight,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Build loading indicator
  Widget _buildLoadingIndicator(ButtonConfig config) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(config.textColor),
      ),
    );
  }

  /// Get button configuration based on variant
  ButtonConfig _getButtonConfig() {
    if (!isEnabled) {
      return ButtonConfig.disabled();
    }

    switch (variant) {
      case ButtonVariant.primary:
        return ButtonConfig.primary();
      case ButtonVariant.secondary:
        return ButtonConfig.secondary();
      case ButtonVariant.accent:
        return ButtonConfig.accent();
      case ButtonVariant.danger:
        return ButtonConfig.danger();
      case ButtonVariant.ghost:
        return ButtonConfig.ghost();
      case ButtonVariant.cosmic:
        return ButtonConfig.cosmic();
    }
  }

  /// Get size configuration
  SizeConfig _getSizeConfig() {
    switch (size) {
      case ButtonSize.small:
        return SizeConfig.small();
      case ButtonSize.medium:
        return SizeConfig.medium();
      case ButtonSize.large:
        return SizeConfig.large();
    }
  }
}

/// Button variants for different use cases
enum ButtonVariant {
  primary,   // Main action buttons
  secondary, // Secondary actions
  accent,    // Highlighted actions
  danger,    // Destructive actions
  ghost,     // Subtle actions
  cosmic,    // Special cosmic theme
}

/// Button sizes
enum ButtonSize {
  small,
  medium,
  large,
}

/// Button configuration class
class ButtonConfig {
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color textColor;
  final FontWeight fontWeight;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const ButtonConfig({
    this.backgroundColor,
    this.gradient,
    required this.textColor,
    this.fontWeight = FontWeight.w600,
    this.border,
    this.boxShadow,
  });

  /// Primary button configuration
  factory ButtonConfig.primary() {
    return ButtonConfig(
      gradient: AppConstants.primaryGradient,
      textColor: Colors.white,
      fontWeight: FontWeight.bold,
      boxShadow: [
        BoxShadow(
          color: AppConstants.primaryPink.withValues(alpha: 0.3),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  /// Secondary button configuration
  factory ButtonConfig.secondary() {
    return ButtonConfig(
      backgroundColor: AppConstants.surfacePurple.withValues(alpha: 0.8),
      textColor: Colors.white,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.2),
        width: 1,
      ),
    );
  }

  /// Accent button configuration
  factory ButtonConfig.accent() {
    return ButtonConfig(
      backgroundColor: AppConstants.accentYellow,
      textColor: AppConstants.backgroundDark,
      fontWeight: FontWeight.bold,
      boxShadow: [
        BoxShadow(
          color: AppConstants.accentYellow.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Danger button configuration
  factory ButtonConfig.danger() {
    return ButtonConfig(
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontWeight: FontWeight.bold,
      boxShadow: [
        BoxShadow(
          color: Colors.red.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Ghost button configuration
  factory ButtonConfig.ghost() {
    return ButtonConfig(
      backgroundColor: Colors.transparent,
      textColor: Colors.white.withValues(alpha: 0.8),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.3),
        width: 1,
      ),
    );
  }

  /// Cosmic button configuration
  factory ButtonConfig.cosmic() {
    return ButtonConfig(
      gradient: const LinearGradient(
        colors: [
          Color(0xFF8E2DE2),
          Color(0xFF4A00E0),
          Color(0xFF00C9FF),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
      fontWeight: FontWeight.bold,
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF8E2DE2).withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Disabled button configuration
  factory ButtonConfig.disabled() {
    return ButtonConfig(
      backgroundColor: Colors.grey.withValues(alpha: 0.3),
      textColor: Colors.white.withValues(alpha: 0.5),
    );
  }
}

/// Size configuration class
class SizeConfig {
  final double? width;
  final double height;
  final double fontSize;
  final double borderRadius;
  final double iconSize;
  final double spacing;

  const SizeConfig({
    this.width,
    required this.height,
    required this.fontSize,
    required this.borderRadius,
    required this.iconSize,
    required this.spacing,
  });

  /// Small button size
  factory SizeConfig.small() {
    return const SizeConfig(
      height: 36,
      fontSize: 14,
      borderRadius: 8,
      iconSize: 16,
      spacing: 6,
    );
  }

  /// Medium button size
  factory SizeConfig.medium() {
    return const SizeConfig(
      height: 48,
      fontSize: 16,
      borderRadius: 12,
      iconSize: 20,
      spacing: 8,
    );
  }

  /// Large button size
  factory SizeConfig.large() {
    return const SizeConfig(
      height: 56,
      fontSize: 18,
      borderRadius: 16,
      iconSize: 24,
      spacing: 10,
    );
  }
}