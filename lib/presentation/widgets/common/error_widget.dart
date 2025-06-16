// File: presentation/widgets/common/error_widget.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'custom_button.dart';

/// Custom error widget with cosmic styling
///
/// Displays error states with appropriate messaging and
/// recovery actions based on the error type.
class CustomErrorWidget extends StatefulWidget {
  const CustomErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.type = ErrorWidgetType.general,
    this.showDetails = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final ErrorWidgetType type;
  final bool showDetails;

  @override
  State<CustomErrorWidget> createState() => _CustomErrorWidgetState();
}

class _CustomErrorWidgetState extends State<CustomErrorWidget>
    with SingleTickerProviderStateMixin {

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
    _showDetails = widget.showDetails;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _getErrorConfig();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildErrorContent(config),
          ),
        );
      },
    );
  }

  /// Build error content
  Widget _buildErrorContent(ErrorConfig config) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              config.backgroundColor.withValues(alpha: 0.9),
              config.backgroundColor.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          border: Border.all(
            color: config.borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            _buildErrorIcon(config),

            const SizedBox(height: 20),

            // Error message
            _buildErrorMessage(config),

            const SizedBox(height: 16),

            // Error description
            _buildErrorDescription(config),

            // Error details (collapsible)
            if (widget.showDetails)
              _buildErrorDetails(),

            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(config),
          ],
        ),
      ),
    );
  }

  /// Build error icon
  Widget _buildErrorIcon(ErrorConfig config) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: config.iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: config.iconColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(
        config.icon,
        size: 32,
        color: config.iconColor,
      ),
    );
  }

  /// Build error message
  Widget _buildErrorMessage(ErrorConfig config) {
    return Text(
      config.title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Build error description
  Widget _buildErrorDescription(ErrorConfig config) {
    return Text(
      config.description,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 14,
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Build collapsible error details
  Widget _buildErrorDetails() {
    return Column(
      children: [
        const SizedBox(height: 16),

        // Toggle button
        TextButton(
          onPressed: () {
            setState(() {
              _showDetails = !_showDetails;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _showDetails ? 'Hide Details' : 'Show Details',
                style: TextStyle(
                  color: AppConstants.accentCyan,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _showDetails ? Icons.expand_less : Icons.expand_more,
                color: AppConstants.accentCyan,
                size: 16,
              ),
            ],
          ),
        ),

        // Details content
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _showDetails
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Text(
              widget.error.toString(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(ErrorConfig config) {
    final buttons = <Widget>[];

    // Retry button
    if (widget.onRetry != null) {
      buttons.add(
        Expanded(
          child: CustomButton(
            text: config.retryText,
            onPressed: widget.onRetry,
            variant: ButtonVariant.primary,
            size: ButtonSize.medium,
            icon: Icons.refresh,
          ),
        ),
      );
    }

    // Dismiss button
    if (widget.onDismiss != null) {
      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(width: 12));
      }
      buttons.add(
        Expanded(
          child: CustomButton(
            text: 'Dismiss',
            onPressed: widget.onDismiss,
            variant: ButtonVariant.ghost,
            size: ButtonSize.medium,
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return CustomButton(
        text: 'OK',
        onPressed: () => Navigator.of(context).pop(),
        variant: ButtonVariant.secondary,
        size: ButtonSize.medium,
      );
    }

    return Row(children: buttons);
  }

  /// Get error configuration
  ErrorConfig _getErrorConfig() {
    switch (widget.type) {
      case ErrorWidgetType.network:
        return ErrorConfig.network();
      case ErrorWidgetType.permission:
        return ErrorConfig.permission();
      case ErrorWidgetType.storage:
        return ErrorConfig.storage();
      case ErrorWidgetType.recording:
        return ErrorConfig.recording();
      case ErrorWidgetType.playback:
        return ErrorConfig.playback();
      case ErrorWidgetType.general:
        return ErrorConfig.general();
    }
  }
}

/// Error widget types
enum ErrorWidgetType {
  network,     // Network/connectivity errors
  permission,  // Permission errors
  storage,     // Storage/file errors
  recording,   // Recording errors
  playback,    // Playback errors
  general,     // General errors
}

/// Error configuration
class ErrorConfig {
  final String title;
  final String description;
  final String retryText;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  const ErrorConfig({
    required this.title,
    required this.description,
    required this.retryText,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  /// Network error configuration
  factory ErrorConfig.network() {
    return const ErrorConfig(
      title: 'Connection Problem',
      description: 'Unable to connect to the network. Please check your internet connection and try again.',
      retryText: 'Retry',
      icon: Icons.wifi_off,
      iconColor: Colors.orange,
      backgroundColor: Color(0xFF4A1A5C),
      borderColor: Colors.orange,
    );
  }

  /// Permission error configuration
  factory ErrorConfig.permission() {
    return const ErrorConfig(
      title: 'Permission Required',
      description: 'This feature requires additional permissions to work properly. Please grant the necessary permissions.',
      retryText: 'Grant Permission',
      icon: Icons.security,
      iconColor: Colors.amber,
      backgroundColor: Color(0xFF4A1A5C),
      borderColor: Colors.amber,
    );
  }

  /// Storage error configuration
  factory ErrorConfig.storage() {
    return const ErrorConfig(
      title: 'Storage Error',
      description: 'Unable to access or write to storage. Please check available space and permissions.',
      retryText: 'Try Again',
      icon: Icons.storage,
      iconColor: Colors.red,
      backgroundColor: Color(0xFF4A1A5C),
      borderColor: Colors.red,
    );
  }

  /// Recording error configuration
  factory ErrorConfig.recording() {
    return const ErrorConfig(
      title: 'Recording Failed',
      description: 'Unable to start or continue recording. Please check microphone permissions and try again.',
      retryText: 'Start Recording',
      icon: Icons.mic_off,
      iconColor: Colors.red,
      backgroundColor: Color(0xFF4A1A5C),
      borderColor: Colors.red,
    );
  }

  /// Playback error configuration
  factory ErrorConfig.playback() {
    return const ErrorConfig(
      title: 'Playback Error',
      description: 'Unable to play the audio file. The file may be corrupted or in an unsupported format.',
      retryText: 'Try Again',
      icon: Icons.play_disabled,
      iconColor: Colors.orange,
      backgroundColor: Color(0xFF4A1A5C),
      borderColor: Colors.orange,
    );
  }

  /// General error configuration
  factory ErrorConfig.general() {
    return const ErrorConfig(
      title: 'Something Went Wrong',
      description: 'An unexpected error occurred. Please try again or contact support if the problem persists.',
      retryText: 'Try Again',
      icon: Icons.error_outline,
      iconColor: Colors.red,
      backgroundColor: Color(0xFF4A1A5C),
      borderColor: Colors.red,
    );
  }
}

/// Helper function to show error dialog
Future<void> showErrorDialog({
  required BuildContext context,
  required Object error,
  VoidCallback? onRetry,
  ErrorWidgetType type = ErrorWidgetType.general,
  bool showDetails = false,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return CustomErrorWidget(
        error: error,
        onRetry: onRetry,
        onDismiss: () => Navigator.of(context).pop(),
        type: type,
        showDetails: showDetails,
      );
    },
  );
}