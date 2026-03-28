// File: presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart
import 'package:flutter/material.dart';

import 'recording_compact_view.dart';
import 'recording_fullscreen_view.dart';

/// Recording Bottom Sheet Main Container
///
/// This widget displays a draggable bottom sheet for recording audio.
/// Features include:
/// - Compact and fullscreen modes with smooth animated transitions
/// - Real-time waveform visualization during recording
/// - Clean UI with modern design
/// - Integration with BLoC pattern for state management
/// - Proper error handling and user feedback
class RecordingBottomSheet extends StatefulWidget {
  final String? title; // Recording title to display
  final String? filePath; // Path to the file being recorded
  final bool isRecording; // Whether a recording is currently in progress
  final bool isPaused; // Whether the recording is paused
  final VoidCallback onToggle; // Callback to start/stop recording
  final Duration elapsed; // Time elapsed since the recording started
  final double amplitude; // Current amplitude from AudioRecorderService (0.0-1.0)
  final double width; // Available screen width
  final Function(String)? onTitleChanged; // Callback for title changes
  final VoidCallback? onPause; // Callback for pause action
  final VoidCallback? onDone; // Callback for done action
  final VoidCallback? onChat; // Callback for chat/transcript action
  final VoidCallback? onPlay; // Callback for play action
  final VoidCallback? onRewind; // Callback for rewind action
  final VoidCallback? onForward; // Callback for forward action
  final Function(double)? onSeek; // Callback for seek action

  const RecordingBottomSheet({
    super.key,
    required this.title,
    required this.filePath,
    required this.isRecording,
    this.isPaused = false,
    required this.onToggle,
    required this.elapsed,
    required this.amplitude,
    required this.width,
    this.onTitleChanged,
    this.onPause,
    this.onDone,
    this.onChat,
    this.onPlay,
    this.onRewind,
    this.onForward,
    this.onSeek,
  });

  @override
  State<RecordingBottomSheet> createState() => _RecordingBottomSheetState();
}

class _RecordingBottomSheetState extends State<RecordingBottomSheet>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _sheetAnimationController;

  late Animation<double> _pulseAnimation;

  // Bottom sheet drag state
  late double maxHeight; // Max expanded height (set in build)
  final double minHeight = 400; // Compact sheet height
  double _sheetOffset = 0; // 0 = collapsed, 1 = fully expanded
  double _dragStartY = 0; // Initial Y drag position
  double _startHeight = 0; // Height when drag started

  // Waveform data shared between compact and fullscreen views
  final List<double> _waveData = [];
  static const int _maxWavePoints = 1000;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Pulse animation for record button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Sheet transition animation
    _sheetAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start pulse animation when recording
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }


  @override
  void didUpdateWidget(RecordingBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update waveform data ALWAYS when recording (even if amplitude doesn't change)
    // This ensures continuous waveform scroll every 150ms
    if (widget.isRecording) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final changed = widget.amplitude != oldWidget.amplitude;
      print('⏱️ [$timestamp] didUpdateWidget: Amplitude ${oldWidget.amplitude.toStringAsFixed(3)} → ${widget.amplitude.toStringAsFixed(3)} (changed: $changed)');
      _addWavePoint(widget.amplitude, timestamp);
    }

    // Clear waveform data when starting a new recording
    if (widget.isRecording && !oldWidget.isRecording && !oldWidget.isPaused) {
      setState(() {
        _waveData.clear();
      });
    }

    // Control pulse animation based on recording state
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();

        // AUTO-COLLAPSE: Only collapse when NOT paused (i.e., recording actually stopped)
        if (!widget.isPaused) {
          setState(() {
            _sheetOffset = 0;
          });
          _sheetAnimationController.animateTo(0);
        }
      }
    }

    // AUTO-COLLAPSE: When paused changes to false and not recording, collapse
    if (widget.isPaused != oldWidget.isPaused && !widget.isPaused && !widget.isRecording) {
      setState(() {
        _sheetOffset = 0;
      });
      _sheetAnimationController.animateTo(0);
    }
  }

  /// Add waveform data point
  void _addWavePoint(double amplitude, int receiveTimestamp) {
    final setStateTimestamp = DateTime.now().millisecondsSinceEpoch;
    final delay = setStateTimestamp - receiveTimestamp;

    setState(() {
      _waveData.add(amplitude);

      // Limit memory usage
      if (_waveData.length > _maxWavePoints) {
        _waveData.removeAt(0);
      }

      // Debug log with timing
      if (_waveData.length % 5 == 0) {
        final afterSetStateTimestamp = DateTime.now().millisecondsSinceEpoch;
        final setStateDelay = afterSetStateTimestamp - setStateTimestamp;
        print('⏱️ [$afterSetStateTimestamp] _addWavePoint: length=${_waveData.length}, amplitude=${amplitude.toStringAsFixed(3)}, delay=${delay}ms, setState=${setStateDelay}ms');
      }
    });
  }



  @override
  void dispose() {
    _pulseController.dispose();
    _sheetAnimationController.dispose();
    super.dispose();
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

    // When recording or paused, sheet is draggable and can be expanded
    // When not recording and not paused, sheet is fixed height
    final bool canExpand = widget.isRecording || widget.isPaused;

    final double currentHeight = canExpand
        ? minHeight + (maxHeight - minHeight) * _sheetOffset + MediaQuery.of(context).padding.bottom
        : 180 + MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: currentHeight,
        child: GestureDetector(
          onVerticalDragStart: canExpand ? _onVerticalDragStart : null,
          onVerticalDragUpdate: canExpand ? _onVerticalDragUpdate : null,
          onVerticalDragEnd: canExpand ? _onVerticalDragEnd : null,
          child: _buildContainer(),
        ),
      ),
    );
  }

  /// Build container with clean design
  Widget _buildContainer() {
    return Container(
      width: double.infinity,
      // Add bottom padding to extend beyond safe area
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8E2DE2), // Main screen purple
            Color(0xFFDA22FF), // Main screen magenta
            Color(0xFFFF4E50), // Main screen coral
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: AnimatedSwitcher(
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
            ? RecordingFullscreenView(
                key: const ValueKey('fullscreen'),
                title: widget.title,
                elapsed: widget.elapsed,
                isRecording: widget.isRecording,
                isPaused: widget.isPaused,
                filePath: widget.filePath,
                amplitude: widget.amplitude,
                waveData: _waveData,
                onToggle: widget.onToggle, // Same as compact view
                onPause: widget.onPause,
                onDone: widget.onDone,
                onChat: widget.onChat,
                onPlay: widget.onPlay,
                onRewind: widget.onRewind,
                onForward: widget.onForward,
                onSeek: widget.onSeek,
              )
            : RecordingCompactView(
                key: const ValueKey('compact'),
                title: widget.title,
                elapsed: widget.elapsed,
                isRecording: widget.isRecording,
                filePath: widget.filePath,
                amplitude: widget.amplitude,
                waveData: _waveData,
                pulseAnimation: _pulseAnimation,
                onToggle: widget.onToggle,
              ),
      ),
    );
  }
}