// File: presentation/widgets/recording/waveform_widget.dart
import 'package:flutter/material.dart';

/// A pure visual waveform slider that can be dragged left to right
/// No audio logic - just a visual component with drag interaction
class WaveformWidget extends StatefulWidget {
  /// Array of amplitude values representing the waveform visualization (values between 0.0 and 1.0)
  final List<double> amplitudes;

  /// Initial position as a percentage (0.0 = start, 1.0 = end)
  final double initialProgress;

  /// Callback function triggered when user drags the waveform
  /// Returns the current position as a percentage (0.0-1.0)
  final Function(double position)? onPositionChanged;

  const WaveformWidget({
    super.key,
    required this.amplitudes,
    this.initialProgress = 0.0,
    this.onPositionChanged,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget> {
  late double _currentPosition;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialProgress.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(WaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update position if there's a significant change to prevent flutter from excessive rebuilds
    const positionThreshold = 0.001; // 0.1% threshold
    final positionDifference = (oldWidget.initialProgress - widget.initialProgress).abs();
    
    if (positionDifference > positionThreshold) {
      _currentPosition = widget.initialProgress.clamp(0.0, 1.0);
    }
  }

  /// Handle position change and notify parent
  void _updatePosition(double newPosition) {
    setState(() {
      _currentPosition = newPosition.clamp(0.0, 1.0);
    });
    
    // Notify parent of position change
    widget.onPositionChanged?.call(_currentPosition);
    print('🎯 WaveformPosition: $_currentPosition (${(_currentPosition * 100).toStringAsFixed(1)}%)');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Handle single tap on waveform - jump to tapped position
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        final tappedPercent = (local.dx / box.size.width).clamp(0.0, 1.0);
        print('🎯 WaveformTap: Moving to $tappedPercent');
        _updatePosition(tappedPercent);
      },

      // Handle horizontal drag - continuous position updates
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        final draggedPercent = (local.dx / box.size.width).clamp(0.0, 1.0);
        print('🎯 WaveformDrag: Dragging to $draggedPercent');
        _updatePosition(draggedPercent);
      },

      onHorizontalDragStart: (details) {
        print('🎯 WaveformDrag: Started dragging');
      },

      onHorizontalDragEnd: (details) {
        print('🎯 WaveformDrag: Finished dragging at $_currentPosition');
      },

      // Custom painter widget to draw the waveform and progress indicator
      child: CustomPaint(
        painter: _WaveformPainter(
          amplitudes: widget.amplitudes,
          progress: _currentPosition,
        ),
        // Fixed height of 48 pixels, full width available
        size: const Size(double.infinity, 48),
      ),
    );
  }
}

/// Custom painter class responsible for drawing the waveform visualization
class _WaveformPainter extends CustomPainter {
  /// Audio amplitude data for each waveform bar
  final List<double> amplitudes;

  /// Current playback progress (0.0-1.0) for visual feedback
  final double progress;

  _WaveformPainter({required this.amplitudes, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Debug: Log amplitude statistics for initial paint
    if (amplitudes.isNotEmpty && amplitudes.length == 200) {
      final minAmp = amplitudes.reduce((a, b) => a < b ? a : b);
      final maxAmp = amplitudes.reduce((a, b) => a > b ? a : b);
      final avgAmp = amplitudes.reduce((a, b) => a + b) / amplitudes.length;
      print('🎨 Waveform paint - Min: ${minAmp.toStringAsFixed(3)}, Max: ${maxAmp.toStringAsFixed(3)}, Avg: ${avgAmp.toStringAsFixed(3)}, Count: ${amplitudes.length}');
    }
    
    // Paint object for played/active portion of waveform (red color like in the image)
    final Paint active = Paint()
      ..color = Colors.red
      ..strokeCap = StrokeCap.round;

    // Paint object for unplayed/inactive portion of waveform (darker grey color)
    final Paint inactive = Paint()
      ..color = Colors.grey[800]!
      ..strokeCap = StrokeCap.round;

    // Calculate spacing and bar width to match the image style
    final double totalBars = 200; // More bars for finer detail
    final double barSpacing = 2.0; // Space between bars
    final double availableWidth = size.width - (totalBars - 1) * barSpacing;
    final double barWidth = availableWidth / totalBars;

    // Calculate vertical center line of the waveform
    final double centerY = size.height / 2;

    // Use fewer samples by sampling the amplitudes array
    final int sampleStep = (amplitudes.length / totalBars).ceil().clamp(1, amplitudes.length);

    // Draw each waveform bar
    for (int i = 0; i < totalBars && i * sampleStep < amplitudes.length; i++) {
      // Calculate horizontal position for this amplitude bar
      final double x = i * (barWidth + barSpacing) + barWidth / 2;

      // Get amplitude value (sample from the amplitudes array)
      final int sampleIndex = (i * sampleStep).clamp(0, amplitudes.length - 1);
      final double amplitude = amplitudes[sampleIndex];

      // Scale amplitude to fit widget height with better visibility
      // Ensure minimum height for very quiet parts and enhance variation
      final double minHeight = size.height * 0.1; // Minimum 10% height
      final double maxHeight = size.height * 0.9; // Maximum 90% height
      final double height = minHeight + (amplitude * (maxHeight - minHeight));

      // Determine color: red if played, grey if not yet played
      final Paint paint = (i / totalBars) < progress
          ? active  // This bar has been played - use red
          : inactive; // This bar hasn't been played yet - use grey

      // Draw vertical line representing this amplitude value
      canvas.drawLine(
        Offset(x, centerY - height / 2), // Top of the bar
        Offset(x, centerY + height / 2), // Bottom of the bar
        paint..strokeWidth = barWidth.clamp(1.0, 2.0), // Adjust bar width
      );
    }

    // Draw the progress indicator line (vertical red line like in the image)
    final double dotX = size.width * progress;

    final Paint progressPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Draw vertical progress line
    canvas.drawLine(
      Offset(dotX, 0),
      Offset(dotX, size.height),
      progressPaint,
    );
  }

  @override
  // Determine when the painter needs to redraw
  // Repaints when amplitude data or progress position changes
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.amplitudes != amplitudes || oldDelegate.progress != progress;
}

/// Simple waveform visualization for recording (like iOS Voice Memos)
/// 
/// This widget shows real-time waveform during recording without interaction.
class RecordingWaveformWidget extends StatelessWidget {
  final List<double> amplitudes;
  final Color waveColor;
  final Color backgroundColor;
  final double height;
  final bool animated;

  const RecordingWaveformWidget({
    Key? key,
    required this.amplitudes,
    this.waveColor = Colors.red,
    this.backgroundColor = Colors.transparent,
    this.height = 40.0,
    this.animated = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: RecordingWaveformPainter(
          amplitudes: amplitudes,
          waveColor: waveColor,
          animated: animated,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Custom painter for recording waveform
class RecordingWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color waveColor;
  final bool animated;

  RecordingWaveformPainter({
    required this.amplitudes,
    required this.waveColor,
    this.animated = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    // Calculate spacing and bar width to match the playback waveform style
    final double totalBars = amplitudes.length.clamp(50, 200).toDouble();
    final double barSpacing = 1.0; // Thin spacing between bars
    final double availableWidth = size.width - (totalBars - 1) * barSpacing;
    final double barWidth = (availableWidth / totalBars).clamp(0.5, 1.5);
    
    final centerY = size.height / 2;

    // Draw waveform bars with gradient effect
    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * (barWidth + barSpacing) + barWidth / 2;
      final amplitude = amplitudes[i];
      final barHeight = amplitude * size.height * 0.8; // Use 80% of height
      final halfBarHeight = barHeight / 2;

      // Create gradient color based on position
      final double positionRatio = i / amplitudes.length;
      final Color barColor = Color.lerp(
        const Color(0xFFFFFF00), // Yellow
        const Color(0xFF00FF00), // Green
        positionRatio,
      )!;

      // Add slight opacity variation for depth - latest bar is brightest
      final opacity = animated && i == amplitudes.length - 1 ? 1.0 : 0.8;
      final currentPaint = Paint()
        ..color = barColor.withOpacity(opacity)
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;

      // Draw the bar
      canvas.drawLine(
        Offset(x, centerY - halfBarHeight),
        Offset(x, centerY + halfBarHeight),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RecordingWaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
           oldDelegate.waveColor != waveColor ||
           oldDelegate.animated != animated;
  }
}