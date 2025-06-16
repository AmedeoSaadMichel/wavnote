// File: presentation/widgets/common/loading_indicator.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_constants.dart';

/// Custom loading indicator with cosmic styling
///
/// Provides various loading animations with mystical themes
/// including cosmic spinner, pulsing dots, and waveform.
class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({
    super.key,
    this.type = LoadingType.cosmic,
    this.size = LoadingSize.medium,
    this.message,
    this.color,
  });

  final LoadingType type;
  final LoadingSize size;
  final String? message;
  final Color? color;

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with TickerProviderStateMixin {

  late AnimationController _primaryController;
  late AnimationController _secondaryController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _primaryController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _secondaryController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_primaryController);

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _secondaryController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizeConfig = _getSizeConfig();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Loading animation
        SizedBox(
          width: sizeConfig.size,
          height: sizeConfig.size,
          child: _buildLoadingAnimation(),
        ),

        // Message
        if (widget.message != null) ...[
          SizedBox(height: sizeConfig.messageSpacing),
          Text(
            widget.message!,
            style: TextStyle(
              color: widget.color ?? Colors.white.withValues(alpha: 0.8),
              fontSize: sizeConfig.messageSize,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Build loading animation based on type
  Widget _buildLoadingAnimation() {
    switch (widget.type) {
      case LoadingType.cosmic:
        return _buildCosmicSpinner();
      case LoadingType.dots:
        return _buildPulsingDots();
      case LoadingType.waveform:
        return _buildWaveform();
      case LoadingType.simple:
        return _buildSimpleSpinner();
    }
  }

  /// Build cosmic spinner with rings
  Widget _buildCosmicSpinner() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring
            Transform.rotate(
              angle: _rotationAnimation.value * 2 * math.pi,
              child: CustomPaint(
                size: Size(_getSizeConfig().size, _getSizeConfig().size),
                painter: CosmicRingPainter(
                  color: widget.color ?? AppConstants.primaryPink,
                  progress: _rotationAnimation.value,
                  isOuter: true,
                ),
              ),
            ),

            // Inner ring
            Transform.rotate(
              angle: -_rotationAnimation.value * 1.5 * math.pi,
              child: CustomPaint(
                size: Size(_getSizeConfig().size * 0.6, _getSizeConfig().size * 0.6),
                painter: CosmicRingPainter(
                  color: widget.color ?? AppConstants.accentCyan,
                  progress: _rotationAnimation.value,
                  isOuter: false,
                ),
              ),
            ),

            // Center dot
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: _getSizeConfig().size * 0.2,
                    height: _getSizeConfig().size * 0.2,
                    decoration: BoxDecoration(
                      color: widget.color ?? AppConstants.accentYellow,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.color ?? AppConstants.accentYellow)
                              .withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// Build pulsing dots
  Widget _buildPulsingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _secondaryController,
          builder: (context, child) {
            final delay = index * 0.3;
            final animationValue = (_secondaryController.value + delay) % 1.0;
            final scale = 0.5 + (math.sin(animationValue * 2 * math.pi) * 0.5);

            return Container(
              margin: EdgeInsets.symmetric(horizontal: _getSizeConfig().size * 0.05),
              child: Transform.scale(
                scale: scale.clamp(0.5, 1.0),
                child: Container(
                  width: _getSizeConfig().size * 0.15,
                  height: _getSizeConfig().size * 0.15,
                  decoration: BoxDecoration(
                    color: widget.color ?? AppConstants.primaryPink,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (widget.color ?? AppConstants.primaryPink)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  /// Build waveform animation
  Widget _buildWaveform() {
    return CustomPaint(
      size: Size(_getSizeConfig().size, _getSizeConfig().size * 0.6),
      painter: WaveformLoadingPainter(
        animation: _primaryController.value,
        color: widget.color ?? AppConstants.accentCyan,
      ),
    );
  }

  /// Build simple circular spinner
  Widget _buildSimpleSpinner() {
    return CircularProgressIndicator(
      strokeWidth: _getSizeConfig().size * 0.08,
      valueColor: AlwaysStoppedAnimation<Color>(
        widget.color ?? AppConstants.primaryPink,
      ),
    );
  }

  /// Get size configuration
  LoadingSizeConfig _getSizeConfig() {
    switch (widget.size) {
      case LoadingSize.small:
        return LoadingSizeConfig.small();
      case LoadingSize.medium:
        return LoadingSizeConfig.medium();
      case LoadingSize.large:
        return LoadingSizeConfig.large();
    }
  }
}

/// Loading types
enum LoadingType {
  cosmic,    // Cosmic spinner with rings
  dots,      // Pulsing dots
  waveform,  // Animated waveform
  simple,    // Simple circular spinner
}

/// Loading sizes
enum LoadingSize {
  small,
  medium,
  large,
}

/// Size configuration
class LoadingSizeConfig {
  final double size;
  final double messageSize;
  final double messageSpacing;

  const LoadingSizeConfig({
    required this.size,
    required this.messageSize,
    required this.messageSpacing,
  });

  factory LoadingSizeConfig.small() {
    return const LoadingSizeConfig(
      size: 32,
      messageSize: 12,
      messageSpacing: 8,
    );
  }

  factory LoadingSizeConfig.medium() {
    return const LoadingSizeConfig(
      size: 48,
      messageSize: 14,
      messageSpacing: 12,
    );
  }

  factory LoadingSizeConfig.large() {
    return const LoadingSizeConfig(
      size: 64,
      messageSize: 16,
      messageSpacing: 16,
    );
  }
}

/// Custom painter for cosmic rings
class CosmicRingPainter extends CustomPainter {
  final Color color;
  final double progress;
  final bool isOuter;

  CosmicRingPainter({
    required this.color,
    required this.progress,
    required this.isOuter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isOuter ? 3.0 : 2.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - paint.strokeWidth / 2;

    // Draw partial arc
    final startAngle = progress * 2 * math.pi;
    final sweepAngle = math.pi; // Half circle

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Add gradient effect
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.3),
          color,
          color.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isOuter ? 1.0 : 0.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 2),
      startAngle,
      sweepAngle,
      false,
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom painter for waveform loading
class WaveformLoadingPainter extends CustomPainter {
  final double animation;
  final Color color;

  WaveformLoadingPainter({
    required this.animation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final barCount = 8;
    final barWidth = size.width / (barCount * 2);
    final spacing = barWidth;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing);
      final animationOffset = (animation + i * 0.1) % 1.0;
      final height = size.height * (0.2 + 0.8 * math.sin(animationOffset * 2 * math.pi).abs());
      final y = (size.height - height) / 2;

      // Create gradient for each bar
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.5),
            color,
            color.withValues(alpha: 0.5),
          ],
        ).createShader(Rect.fromLTWH(x, y, barWidth, height));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, height),
          const Radius.circular(2),
        ),
        gradientPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Helper function to show loading overlay
Future<void> showLoadingOverlay({
  required BuildContext context,
  String? message,
  LoadingType type = LoadingType.cosmic,
  LoadingSize size = LoadingSize.medium,
  Color? color,
  bool isDismissible = false,
}) {
  return showDialog(
    context: context,
    barrierDismissible: isDismissible,
    barrierColor: Colors.black54,
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async => isDismissible,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppConstants.backgroundDark.withValues(alpha: 0.9),
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
            child: LoadingIndicator(
              type: type,
              size: size,
              message: message,
              color: color,
            ),
          ),
        ),
      );
    },
  );
}

/// Helper function to hide loading overlay
void hideLoadingOverlay(BuildContext context) {
  Navigator.of(context).pop();
}

/// Specialized loading widgets for common use cases
class RecordingLoadingIndicator extends StatelessWidget {
  const RecordingLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoadingIndicator(
      type: LoadingType.waveform,
      size: LoadingSize.medium,
      message: 'Processing recording...',
      color: AppConstants.primaryPink,
    );
  }
}

class PlaybackLoadingIndicator extends StatelessWidget {
  const PlaybackLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoadingIndicator(
      type: LoadingType.cosmic,
      size: LoadingSize.small,
      message: 'Loading audio...',
      color: AppConstants.accentCyan,
    );
  }
}

class SaveLoadingIndicator extends StatelessWidget {
  const SaveLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoadingIndicator(
      type: LoadingType.dots,
      size: LoadingSize.medium,
      message: 'Saving...',
      color: AppConstants.accentYellow,
    );
  }
}