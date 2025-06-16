// File: presentation/widgets/common/custom_dialog.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'custom_button.dart';

/// Base custom dialog component with cosmic styling
///
/// Provides consistent dialog styling across the app with
/// flexible content and action button configuration.
class CustomDialog extends StatelessWidget {
  const CustomDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.content,
    this.icon,
    this.iconColor,
    this.actions = const [],
    this.showCloseButton = true,
    this.isDismissible = true,
    this.maxWidth = 400,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? content;
  final IconData? icon;
  final Color? iconColor;
  final List<DialogAction> actions;
  final bool showCloseButton;
  final bool isDismissible;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => isDismissible,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: _buildDialogContent(context),
        ),
      ),
    );
  }

  /// Build dialog content with cosmic styling
  Widget _buildDialogContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D1B69),
            Color(0xFF11002B),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(context),

          // Content
          if (content != null || subtitle != null)
            _buildContent(),

          // Actions
          if (actions.isNotEmpty)
            _buildActions(),
        ],
      ),
    );
  }

  /// Build dialog header
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      child: Row(
        children: [
          // Icon
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
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
          ],

          // Title
          Expanded(
            child: Text(
              title,
              style: AppConstants.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Close button
          if (showCloseButton && isDismissible) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build dialog content
  Widget _buildContent() {
    return Container(
      padding: EdgeInsets.only(
        left: padding?.left ?? 24,
        right: padding?.right ?? 24,
        bottom: actions.isNotEmpty ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: AppConstants.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            if (content != null) const SizedBox(height: 16),
          ],

          // Custom content
          if (content != null)
            content!,
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActions() {
    return Container(
      padding: EdgeInsets.only(
        left: padding?.left ?? 24,
        right: padding?.right ?? 24,
        bottom: padding?.bottom ?? 24,
      ),
      child: Column(
        children: [
          const Divider(
            color: Colors.white12,
            height: 1,
          ),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// Build action buttons layout
  Widget _buildActionButtons() {
    if (actions.length == 1) {
      return SizedBox(
        width: double.infinity,
        child: _buildActionButton(actions.first),
      );
    }

    if (actions.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildActionButton(actions.first)),
          const SizedBox(width: 12),
          Expanded(child: _buildActionButton(actions.last)),
        ],
      );
    }

    // More than 2 actions - stack vertically
    return Column(
      children: actions.map((action) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          child: _buildActionButton(action),
        );
      }).toList(),
    );
  }

  /// Build individual action button
  Widget _buildActionButton(DialogAction action) {
    return CustomButton(
      text: action.text,
      onPressed: action.onPressed,
      variant: action.variant,
      size: ButtonSize.medium,
      isEnabled: action.isEnabled,
    );
  }
}

/// Dialog action configuration
class DialogAction {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool isEnabled;

  const DialogAction({
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.secondary,
    this.isEnabled = true,
  });

  /// Create primary action
  factory DialogAction.primary({
    required String text,
    VoidCallback? onPressed,
    bool isEnabled = true,
  }) {
    return DialogAction(
      text: text,
      onPressed: onPressed,
      variant: ButtonVariant.primary,
      isEnabled: isEnabled,
    );
  }

  /// Create secondary action
  factory DialogAction.secondary({
    required String text,
    VoidCallback? onPressed,
    bool isEnabled = true,
  }) {
    return DialogAction(
      text: text,
      onPressed: onPressed,
      variant: ButtonVariant.secondary,
      isEnabled: isEnabled,
    );
  }

  /// Create danger action
  factory DialogAction.danger({
    required String text,
    VoidCallback? onPressed,
    bool isEnabled = true,
  }) {
    return DialogAction(
      text: text,
      onPressed: onPressed,
      variant: ButtonVariant.danger,
      isEnabled: isEnabled,
    );
  }

  /// Create ghost action
  factory DialogAction.ghost({
    required String text,
    VoidCallback? onPressed,
    bool isEnabled = true,
  }) {
    return DialogAction(
      text: text,
      onPressed: onPressed,
      variant: ButtonVariant.ghost,
      isEnabled: isEnabled,
    );
  }
}

/// Helper function to show custom dialog
Future<T?> showCustomDialog<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  Widget? content,
  IconData? icon,
  Color? iconColor,
  List<DialogAction> actions = const [],
  bool showCloseButton = true,
  bool isDismissible = true,
  double maxWidth = 400,
  EdgeInsets? padding,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    builder: (BuildContext context) {
      return CustomDialog(
        title: title,
        subtitle: subtitle,
        content: content,
        icon: icon,
        iconColor: iconColor,
        actions: actions,
        showCloseButton: showCloseButton,
        isDismissible: isDismissible,
        maxWidth: maxWidth,
        padding: padding,
      );
    },
  );
}