// File: presentation/widgets/recording/recording_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:audio_waveforms/audio_waveforms.dart';
import '../../../core/extensions/duration_extensions.dart';
import '../../bloc/recording/recording_bloc.dart';

import 'fullscreen_waveform.dart';

/// Recording Bottom Sheet
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
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _sheetAnimationController;
  
  // Audio waveforms controller (for visualization only)
  late RecorderController _recorderController;

  late Animation<double> _pulseAnimation;

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
    _initializeWaveformController();
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

  void _initializeWaveformController() {
    _recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
  }

  @override
  void didUpdateWidget(RecordingBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Control pulse animation based on recording state
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
        _startWaveformRecording();
      } else {
        _pulseController.stop();
        _pulseController.reset();
        _stopWaveformRecording();
      }
    }
  }

  /// Start waveform recording for visualization
  void _startWaveformRecording() async {
    try {
      if (await _recorderController.checkPermission()) {
        // Start recording for waveform visualization only
        await _recorderController.record();
      }
    } catch (e) {
      print('Error starting waveform recording: $e');
    }
  }

  /// Stop waveform recording
  void _stopWaveformRecording() async {
    try {
      await _recorderController.stop();
    } catch (e) {
      print('Error stopping waveform recording: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheetAnimationController.dispose();
    _recorderController.dispose();
    super.dispose();
  }

  /// Converts the elapsed recording time into formatted string
  String get _formattedTime {
    return widget.elapsed.formatted;
  }

  /// Get recording description
  String get _recordingDescription {
    if (!widget.isRecording) return 'Ready to start recording';

    final minutes = widget.elapsed.inMinutes;
    if (minutes < 1) {
      return 'Recording in progress...';
    } else if (minutes < 5) {
      return 'Recording your audio...';
    } else {
      return 'Long recording in progress...';
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
        child: _buildContainer(),
      ),
    );
  }

  /// Build container with clean design
  Widget _buildContainer() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        color: Colors.grey[900]?.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
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
            ? _buildFullScreenView()
            : _buildCompactView(),
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
        const Flexible(flex: 1, child: SizedBox(height: 10)),

        // Handle - flexible
        Flexible(flex: 1, child: _buildHandle()),

        // Spacing after handle - flexible
        const Flexible(flex: 1, child: SizedBox(height: 10)),

        // Recording info section - flexible
        Flexible(flex: 4, child: _buildRecordingInfo(isFullscreen: true)),

        // Spacing after info - flexible
        const Flexible(flex: 1, child: SizedBox(height: 10)),

        // Fullscreen waveform - conditional flexible
        if (widget.isRecording)
          Flexible(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: FullScreenWaveform(
                filePath: widget.filePath,
                isRecording: widget.isRecording,
                amplitude: 0.5, // Default amplitude for fullscreen waveform
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
        // Top spacer
        const Flexible(flex: 1, child: SizedBox(height: 10)),

        // Handle at top
        Flexible(
          flex: 1,
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Compact animated content
        Flexible(
          flex: 8,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 100),
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1.0,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: widget.isRecording
                ? Column(
              key: const ValueKey(true),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.title != null)
                  Flexible(
                    flex: 2,
                    child: Text(
                      widget.title!, 
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 22, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Flexible(flex: 1, child: SizedBox(height: 6)),
                Flexible(
                  flex: 2,
                  child: Text(
                    _formattedTime, 
                    style: const TextStyle(
                      color: Colors.grey, 
                      fontSize: 18,
                    ),
                  ),
                ),
                const Flexible(flex: 1, child: SizedBox(height: 12)),
                if (widget.filePath != null) 
                  Flexible(
                    flex: 4,
                    child: Container(
                      height: 50,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildAudioWaveform(),
                    ),
                  ),
                const Flexible(flex: 1, child: SizedBox(height: 12)),
              ],
            )
                : const SizedBox(key: ValueKey(false)),
          ),
        ),

        // Main record toggle button - centered
        Flexible(
          flex: 6,
          child: Center(
            child: GestureDetector(
              onTap: widget.onToggle,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isRecording ? Colors.white : Colors.red,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 1000),
                        child: widget.isRecording
                            ? const Icon(
                                Icons.stop_rounded, 
                                key: ValueKey('stop'), 
                                color: Colors.red, 
                                size: 32,
                              )
                            : const Icon(
                                Icons.fiber_manual_record, 
                                key: ValueKey('rec'), 
                                color: Colors.red,
                                size: 35,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Bottom spacer
        const Flexible(flex: 2, child: SizedBox(height: 20)),
      ],
    );
  }

  /// Build simple handle
  Widget _buildHandle() {
    return Container(
      width: 50,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(3),
      ),
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
                color: Colors.white,
                fontSize: isFullscreen ? 28 : 22,
                fontWeight: FontWeight.bold,
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
                color: Colors.grey,
                fontSize: isFullscreen ? 24 : 18,
                fontWeight: FontWeight.w600,
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
              _recordingDescription,
              style: TextStyle(
                color: Colors.grey[400],
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
              'Ready to start recording',
              style: TextStyle(
                color: Colors.grey[400],
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
                  ? Colors.grey
                  : Colors.white,
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
            color: Colors.blue,
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
            child: _buildActionButton(
              icon: Icons.pause,
              label: 'Pause',
              color: Colors.orange,
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
            color: Colors.green,
            onPressed: widget.onDone ?? () {},
            label: 'Done',
          ),
        ),
      ],
    );
  }


  /// Build control button
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
            ? Colors.grey[800]?.withValues(alpha: 0.6)
            : Colors.grey[800]?.withValues(alpha: 0.3),
        border: Border.all(
          color: enabled
              ? Colors.grey[400]?.withValues(alpha: 0.5) ?? Colors.grey
              : Colors.grey[600]?.withValues(alpha: 0.3) ?? Colors.grey,
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


  /// Build circular icon with text overlay
  Widget _buildCircularIcon(String text, IconData icon) {
    final bool isEnabled = !widget.isRecording;
    final Color color = isEnabled
        ? Colors.white
        : Colors.grey;

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

  /// Build audio waveform using audio_waveforms library
  Widget _buildAudioWaveform() {
    return AudioWaveforms(
      enableGesture: false,
      size: const Size(double.infinity, 50),
      recorderController: _recorderController,
      waveStyle: WaveStyle(
        waveColor: Colors.yellow,
        showDurationLabel: false,
        spacing: 4.0,
        showBottom: true, // Show bottom half of waveform
        extendWaveform: true,
        showMiddleLine: false,
        scaleFactor: 100, // Increased scale factor
        waveThickness: 2.0,
        gradient: LinearGradient(
          colors: [
            Colors.yellow,
            Colors.yellow.withOpacity(0.8),
            Colors.green.withOpacity(0.8),
            Colors.green,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(const Rect.fromLTWH(0, 0, 200, 50)),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

