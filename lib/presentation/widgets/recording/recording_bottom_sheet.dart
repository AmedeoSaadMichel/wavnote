// File: presentation/widgets/recording/recording_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/duration_extensions.dart';
import '../../bloc/recording/recording_bloc.dart';

import 'fullscreen_waveform.dart';
import 'record_waveform.dart';

/// Cosmic Recording Bottom Sheet with Midnight Gospel Aesthetics
///
/// This widget displays a draggable bottom sheet for recording audio with
/// cosmic theme integration. Features include:
/// - Compact and fullscreen modes with smooth animated transitions
/// - Real-time waveform visualization during recording
/// - Cosmic gradient backgrounds and ethereal effects
/// - Mystical UI elements and philosophical interactions
/// - Integration with BLoC pattern for state management
/// - Cosmic error handling and user feedback
class RecordingBottomSheet extends StatefulWidget {
  final String? title; // Recording title to display
  final String? filePath; // Path to the file being recorded
  final bool isRecording; // Whether a recording is currently in progress
  final VoidCallback onToggle; // Callback to start/stop recording
  final Duration elapsed; // Time elapsed since the recording started
  final double width; // Available screen width
  final Function(String)? onTitleChanged; // Callback for title changes
  final VoidCallback? onPause; // Callback for pause action
  final VoidCallback? onDone; // Callback for done action
  final VoidCallback? onChat; // Callback for chat/transcript action

  const RecordingBottomSheet({
    super.key,
    required this.title,
    required this.filePath,
    required this.isRecording,
    required this.onToggle,
    required this.elapsed,
    required this.width,
    this.onTitleChanged,
    this.onPause,
    this.onDone,
    this.onChat,
  });

  @override
  State<RecordingBottomSheet> createState() => _RecordingBottomSheetState();
}

class _RecordingBottomSheetState extends State<RecordingBottomSheet>
    with TickerProviderStateMixin {
  // Animation controllers for cosmic effects
  late AnimationController _pulseController;
  late AnimationController _cosmicFlowController;
  late AnimationController _sheetAnimationController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _cosmicFlowAnimation;
  late Animation<double> _sheetAnimation;

  // Bottom sheet drag state
  late double maxHeight; // Max expanded height (set in build)
  final double minHeight = 400; // Compact sheet height
  double _sheetOffset = 0; // 0 = collapsed, 1 = fully expanded
  double _dragStartY = 0; // Initial Y drag position
  double _startHeight = 0; // Height when drag started

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Pulse animation for record button and cosmic effects
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Cosmic flow animation for background effects
    _cosmicFlowController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    // Sheet transition animation
    _sheetAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _cosmicFlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cosmicFlowController, curve: Curves.linear),
    );

    _sheetAnimation = CurvedAnimation(
      parent: _sheetAnimationController,
      curve: Curves.easeInOutCubic,
    );

    // Start cosmic animations
    _cosmicFlowController.repeat();
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RecordingBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Control pulse animation based on recording state
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cosmicFlowController.dispose();
    _sheetAnimationController.dispose();
    super.dispose();
  }

  /// Converts the elapsed recording time into cosmic time format
  String get _formattedTime {
    return widget.elapsed.formatted;
  }

  /// Get mystical recording description
  String get _mysticalDescription {
    if (!widget.isRecording) return 'Cosmic energy awaits your transmission';

    final minutes = widget.elapsed.inMinutes;
    if (minutes < 1) {
      return 'Capturing ethereal vibrations...';
    } else if (minutes < 5) {
      return 'Weaving your cosmic narrative...';
    } else {
      return 'Transcending temporal boundaries...';
    }
  }

  // Called when drag starts
  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _startHeight = minHeight + (maxHeight - minHeight) * _sheetOffset;
  }

  // Called when user drags vertically; calculates new height and updates offset
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    double delta = _dragStartY - details.globalPosition.dy;
    double newHeight = (_startHeight + delta).clamp(minHeight, maxHeight);
    setState(() {
      _sheetOffset = (newHeight - minHeight) / (maxHeight - minHeight);
    });
  }

  // Called when drag ends; snaps to open or closed based on current position
  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _sheetOffset = _sheetOffset > 0.5 ? 1 : 0;
    });

    // Animate sheet to final position
    _sheetAnimationController.animateTo(_sheetOffset);
  }

  @override
  Widget build(BuildContext context) {
    maxHeight = MediaQuery.of(context).size.height * 0.9;

    // When not recording, sheet is fixed height and not draggable
    final double currentHeight = widget.isRecording
        ? minHeight + (maxHeight - minHeight) * _sheetOffset
        : 180;

    return AnimatedPositioned(
      bottom: 0,
      left: 0,
      right: 0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      height: currentHeight,
      child: GestureDetector(
        onVerticalDragStart: widget.isRecording ? _onVerticalDragStart : null,
        onVerticalDragUpdate: widget.isRecording ? _onVerticalDragUpdate : null,
        onVerticalDragEnd: widget.isRecording ? _onVerticalDragEnd : null,
        child: _buildCosmicContainer(),
      ),
    );
  }

  /// Build cosmic-themed container with ethereal effects
  Widget _buildCosmicContainer() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _cosmicFlowAnimation]),
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppConstants.backgroundSpace.withValues(alpha: 0.95),
                AppConstants.surfaceCard.withValues(alpha: 0.9),
                AppConstants.backgroundDark.withValues(alpha: 0.95),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppConstants.primaryPink.withValues(
                  alpha: 0.1 * _pulseAnimation.value,
                ),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppConstants.primaryBlue.withValues(alpha: 0.08),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
            border: Border.all(
              color: AppConstants.accentCyan.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Cosmic background effects
              _buildCosmicBackground(),

              // Main content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                ),
                child: _sheetOffset > 0.7
                    ? _buildFullScreenView()
                    : _buildCompactView(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build cosmic background with flowing particles and gradients
  Widget _buildCosmicBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _cosmicFlowAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: CosmicBackgroundPainter(
              flowValue: _cosmicFlowAnimation.value,
              pulseValue: _pulseAnimation.value,
              isRecording: widget.isRecording,
            ),
          );
        },
      ),
    );
  }

  /// Build fullscreen view for expanded sheet
  Widget _buildFullScreenView() {
    return Column(
      key: const ValueKey('fullscreen'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top spacer - flexible
        Spacer(),

        // Cosmic handle - flexible
        Flexible(flex: 1, child: _buildCosmicHandle()),

        // Spacing after handle - flexible
        Spacer(),

        // Recording info section - flexible
        Flexible(flex: 4, child: _buildRecordingInfo(isFullscreen: true)),

        // Spacing after info - flexible
        Spacer(),

        // Fullscreen waveform - conditional flexible
        if (widget.isRecording)
          Flexible(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: FullScreenWaveform(
                filePath: widget.filePath,
                isRecording: widget.isRecording,
                amplitude: _getCurrentAmplitude(),
              ),
            ),
          ),

        // Spacing after waveform - flexible
        const Flexible(flex: 1, child: SizedBox(height: 20)),

        // Playback controls (disabled while recording) - flexible
        Flexible(flex: 3, child: _buildPlaybackControls()),

        // Spacing after controls - flexible
        const Flexible(flex: 1, child: SizedBox(height: 20)),

        // Action buttons row - flexible
        Flexible(flex: 3, child: _buildActionButtons()),

        // Bottom spacing - flexible
        const Flexible(flex: 1, child: SizedBox(height: 20)),
      ],
    );
  }

  /// Build compact view for collapsed sheet
  Widget _buildCompactView() {
    return Column(
      key: const ValueKey('compact'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top spacing - flexible
        const Flexible(flex: 1, child: SizedBox(height: 12)),

        // Cosmic handle - flexible
        Flexible(flex: 1, child: _buildCosmicHandle()),

        // Spacing after handle - flexible
        const Flexible(flex: 1, child: SizedBox(height: 16)),

        // Compact recording info - conditional flexible
        if (widget.isRecording)
          Flexible(flex: 3, child: _buildRecordingInfo(isFullscreen: false)),

        // Spacing between info and waveform - flexible
        if (widget.isRecording)
          const Flexible(flex: 1, child: SizedBox(height: 12)),

        // Compact waveform - conditional flexible
        if (widget.isRecording && widget.filePath != null)
          Flexible(
            flex: 3,
            child: RecordWaveform(
              filePath: widget.filePath!,
              isRecording: widget.isRecording,
              amplitude: _getCurrentAmplitude(),
            ),
          ),

        // Spacing before button - flexible
        const Flexible(flex: 1, child: SizedBox(height: 16)),

        // Main cosmic record button - centered and flexible
        Flexible(flex: 4, child: Center(child: _buildCosmicRecordButton())),

        // Bottom spacing - flexible
        const Flexible(flex: 1, child: SizedBox(height: 20)),
      ],
    );
  }

  /// Build cosmic handle with ethereal glow
  Widget _buildCosmicHandle() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 50,
          height: 5,
          decoration: BoxDecoration(
            color: AppConstants.accentCyan.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: AppConstants.accentCyan.withValues(
                  alpha: 0.3 * _pulseAnimation.value,
                ),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build recording information display
  Widget _buildRecordingInfo({required bool isFullscreen}) {
    return Column(
      children: [
        // Title - flexible
        if (widget.title != null)
          Flexible(
            flex: 3,
            child: Text(
              widget.title!,
              style: TextStyle(
                color: AppConstants.textPrimary,
                fontSize: isFullscreen ? 28 : 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // Spacing after title - flexible
        const Flexible(
          flex: 1,
          child: SizedBox(height: 8),
        ),

        // Recording content - flexible
        if (widget.isRecording) ...[
          // Time display - flexible
          Flexible(
            flex: 3,
            child: Text(
              _formattedTime,
              style: TextStyle(
                color: AppConstants.primaryPink,
                fontSize: isFullscreen ? 24 : 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // Spacing between time and description - flexible
          const Flexible(
            flex: 1,
            child: SizedBox(height: 4),
          ),

          // Description - flexible
          Flexible(
            flex: 2,
            child: Text(
              _mysticalDescription,
              style: TextStyle(
                color: AppConstants.textSecondary,
                fontSize: isFullscreen ? 16 : 14,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ] else ...[
          // Ready message - flexible
          Flexible(
            flex: 3,
            child: Text(
              'Ready to capture cosmic vibrations',
              style: TextStyle(
                color: AppConstants.textSecondary,
                fontSize: isFullscreen ? 18 : 16,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  /// Build playback controls (disabled during recording)
  Widget _buildPlaybackControls() {
    return Row(
      children: [
        // Left control button (rewind) - flexible
        Flexible(
          flex: 2,
          child: _buildControlButton(
            icon: _buildCircularIcon("15", Icons.rotate_left),
            onPressed: widget.isRecording ? null : () {},
            enabled: !widget.isRecording,
          ),
        ),

        // Spacing - flexible
        const Flexible(
          flex: 1,
          child: SizedBox(),
        ),

        // Center play button - flexible (larger)
        Flexible(
          flex: 3,
          child: _buildControlButton(
            icon: Icon(
              Icons.play_arrow,
              color: widget.isRecording
                  ? AppConstants.textMuted
                  : AppConstants.textPrimary,
              size: 40,
            ),
            onPressed: widget.isRecording ? null : () {},
            enabled: !widget.isRecording,
          ),
        ),

        // Spacing - flexible
        const Flexible(
          flex: 1,
          child: SizedBox(),
        ),

        // Right control button (forward) - flexible
        Flexible(
          flex: 2,
          child: _buildControlButton(
            icon: _buildCircularIcon("15", Icons.rotate_right),
            onPressed: widget.isRecording ? null : () {},
            enabled: !widget.isRecording,
          ),
        ),
      ],
    );
  }

  /// Build action buttons row
  Widget _buildActionButtons() {
    return Row(
      children: [
        // Chat/Transcript button - flexible
        Flexible(
          flex: 2,
          child: _buildActionButton(
            icon: Icons.chat_bubble_outline,
            color: AppConstants.accentCyan,
            onPressed: widget.onChat ?? () {},
          ),
        ),

        // Spacing before pause button - flexible
        const Flexible(
          flex: 1,
          child: SizedBox(),
        ),

        // Pause button (main action) - flexible
        Flexible(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildCosmicActionButton(
              icon: Icons.pause,
              label: 'Pause',
              color: AppConstants.primaryOrange,
              onPressed: widget.onPause ?? () {},
            ),
          ),
        ),

        // Spacing before done button - flexible
        const Flexible(
          flex: 1,
          child: SizedBox(),
        ),

        // Done button - flexible
        Flexible(
          flex: 2,
          child: _buildActionButton(
            icon: Icons.check,
            color: AppConstants.accentCyan,
            onPressed: widget.onDone ?? () {},
            label: 'Done',
          ),
        ),
      ],
    );
  }

  /// Build main cosmic record button
  Widget _buildCosmicRecordButton() {
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, state) {
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                width: 100 * _pulseAnimation.value,
                height: 100 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.isRecording
                      ? LinearGradient(
                          colors: [
                            AppConstants.primaryOrange,
                            AppConstants.primaryPink,
                          ],
                        )
                      : LinearGradient(
                          colors: [
                            AppConstants.primaryPink,
                            AppConstants.primaryPurple,
                          ],
                        ),
                  border: Border.all(color: AppConstants.textPrimary, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isRecording
                          ? AppConstants.primaryOrange.withValues(alpha: 0.4)
                          : AppConstants.primaryPink.withValues(alpha: 0.3),
                      blurRadius: 20 * _pulseAnimation.value,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: widget.isRecording
                        ? const Icon(
                            Icons.stop_rounded,
                            key: ValueKey('stop'),
                            color: AppConstants.textPrimary,
                            size: 40,
                          )
                        : const Icon(
                            Icons.fiber_manual_record,
                            key: ValueKey('record'),
                            color: AppConstants.textPrimary,
                            size: 35,
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Build control button with cosmic styling
  Widget _buildControlButton({
    required Widget icon,
    required VoidCallback? onPressed,
    required bool enabled,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled
            ? AppConstants.surfaceCard.withValues(alpha: 0.6)
            : AppConstants.surfaceCard.withValues(alpha: 0.3),
        border: Border.all(
          color: enabled
              ? AppConstants.accentCyan.withValues(alpha: 0.5)
              : AppConstants.textMuted.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: IconButton(onPressed: onPressed, icon: icon),
    );
  }

  /// Build action button
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color, size: 28),
        ),
        if (label != null)
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  /// Build cosmic action button with gradient
  Widget _buildCosmicActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
        ),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build circular icon with text overlay
  Widget _buildCircularIcon(String text, IconData icon) {
    final bool isEnabled = !widget.isRecording;
    final Color color = isEnabled
        ? AppConstants.textPrimary
        : AppConstants.textMuted;

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: color, size: 35),
        Text(
          text,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Get current amplitude for waveform (mock implementation)
  double _getCurrentAmplitude() {
    if (!widget.isRecording) return 0.0;

    // In a real implementation, this would come from the audio recorder
    return 0.3 +
        (math.sin(DateTime.now().millisecondsSinceEpoch / 100) * 0.4).abs();
  }
}

/// Custom painter for cosmic background effects
class CosmicBackgroundPainter extends CustomPainter {
  final double flowValue;
  final double pulseValue;
  final bool isRecording;

  CosmicBackgroundPainter({
    required this.flowValue,
    required this.pulseValue,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw flowing cosmic particles
    _drawCosmicParticles(canvas, size);

    // Draw ethereal glow effects
    if (isRecording) {
      _drawRecordingAura(canvas, size);
    }
  }

  void _drawCosmicParticles(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw floating particles
    for (int i = 0; i < 20; i++) {
      final x = (size.width * flowValue + i * size.width / 10) % size.width;
      final y =
          size.height * 0.2 +
          math.sin(flowValue * 2 * math.pi + i * 0.5) * size.height * 0.3;

      final opacity = (0.1 + math.sin(flowValue * math.pi + i) * 0.1).abs();
      paint.color = AppConstants.accentCyan.withValues(alpha: opacity);

      canvas.drawCircle(
        Offset(x, y),
        1 + math.sin(flowValue * 2 * math.pi + i) * 1.5,
        paint,
      );
    }
  }

  void _drawRecordingAura(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final maxRadius = size.width * 0.3 * pulseValue;

    final gradient = RadialGradient(
      colors: [
        AppConstants.primaryPink.withValues(alpha: 0.1),
        AppConstants.primaryOrange.withValues(alpha: 0.05),
        Colors.transparent,
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: maxRadius),
      );

    canvas.drawCircle(center, maxRadius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
