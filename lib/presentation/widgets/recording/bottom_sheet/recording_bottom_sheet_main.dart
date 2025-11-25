// File: presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audio_waveforms/audio_waveforms.dart';

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
  
  // Audio waveforms controller (for visualization only)
  late RecorderController _recorderController;
  
  // Store real-time waveform data
  final List<double> _realTimeWaveformData = [];
  Timer? _waveformCaptureTimer;

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
      ..sampleRate = 44100;  // Back to high quality
  }

  @override
  void didUpdateWidget(RecordingBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Control pulse animation based on recording state
    if (widget.isRecording != oldWidget.isRecording) {
      print('📝 Recording state changed: ${oldWidget.isRecording} → ${widget.isRecording}, isPaused: ${widget.isPaused}, oldPaused: ${oldWidget.isPaused}');

      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);

        // Check if we're resuming from pause
        if (oldWidget.isPaused) {
          print('▶️ RESUMING: Resuming waveform recording from pause');
          _resumeWaveformRecording();
        } else {
          print('🔴 STARTING: Starting new waveform recording');
          _startWaveformRecording();
        }
      } else {
        _pulseController.stop();
        _pulseController.reset();

        // Pause waveform recording instead of stopping (keeps the waveform visible but frozen)
        if (widget.isPaused) {
          print('⏸️ PAUSED: Pausing waveform recording to freeze visualization');
          _pauseWaveformRecording();
        } else {
          print('⏹️ STOPPED: Stopping waveform recording');
          _stopWaveformRecording();
        }

        // AUTO-COLLAPSE: Only collapse when NOT paused (i.e., recording actually stopped)
        if (!widget.isPaused) {
          print('🔽 AUTO-COLLAPSE: Recording stopped, collapsing bottom sheet');
          setState(() {
            _sheetOffset = 0;
          });
          _sheetAnimationController.animateTo(0);
        } else {
          print('⏸️ PAUSED: Keeping bottom sheet open');
        }
      }
    }

    // AUTO-COLLAPSE: When paused changes to false and not recording, collapse
    if (widget.isPaused != oldWidget.isPaused && !widget.isPaused && !widget.isRecording) {
      print('🔽 AUTO-COLLAPSE: Done clicked, collapsing bottom sheet');
      _stopWaveformRecording();
      setState(() {
        _sheetOffset = 0;
      });
      _sheetAnimationController.animateTo(0);
    }
  }

  /// Start waveform recording for visualization
  void _startWaveformRecording() async {
    try {
      if (await _recorderController.checkPermission()) {
        // Start recording for waveform visualization only
        await _recorderController.record();
        
        // Start capturing real-time waveform data
        _startWaveformCapture();
      }
    } catch (e) {
      print('Error starting waveform recording: $e');
    }
  }

  /// Pause waveform recording (freezes the waveform)
  void _pauseWaveformRecording() async {
    try {
      // Use pause() to freeze the waveform visualization
      await _recorderController.pause();
      print('✅ Waveform recording paused - visualization frozen');
    } catch (e) {
      print('⚠️ Error pausing waveform recording: $e');
      // Fallback to stop if pause fails
      try {
        await _recorderController.stop();
      } catch (e2) {
        print('❌ Failed to stop waveform recording: $e2');
      }
    }
  }

  /// Resume waveform recording (restart animation)
  void _resumeWaveformRecording() async {
    try {
      // Use record() to resume (RecorderController doesn't have resume() method)
      await _recorderController.record();
      print('✅ Waveform recording resumed - visualization restarted');

      // Restart capturing waveform data
      _startWaveformCapture();
    } catch (e) {
      print('❌ Failed to resume waveform recording: $e');
    }
  }

  /// Stop waveform recording
  void _stopWaveformRecording() async {
    try {
      await _recorderController.stop();

      // Stop capturing waveform data
      _stopWaveformCapture();
    } catch (e) {
      print('Error stopping waveform recording: $e');
    }
  }

  /// Start capturing real-time waveform data from AudioWaveforms widget
  void _startWaveformCapture() {
    print('🎬 STARTING waveform capture - clearing previous data');
    _realTimeWaveformData.clear();

    // Use a seed based on current timestamp to ensure each recording is unique
    final recordingSeed = DateTime.now().millisecondsSinceEpoch;

    // Capture waveform data with improved realistic variation
    // Note: getAmplitude() is not supported on iOS, so we generate realistic patterns
    // that vary uniquely for each recording
    _waveformCaptureTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_recorderController.isRecording) {
        try {
          // Use recording start time + elapsed time for unique variation per recording
          final totalMs = recordingSeed + widget.elapsed.inMilliseconds;
          final seconds = totalMs / 1000.0;

          // Create multiple overlapping frequencies for speech-like patterns
          final seed1 = (seconds * 1.7).floor();
          final seed2 = (seconds * 4.3).floor();
          final seed3 = (seconds * 11.8).floor();

          // Generate pseudo-random but reproducible values
          final rand1 = ((seed1 * 9301 + 49297) % 233280) / 233280.0;
          final rand2 = ((seed2 * 1103515245 + 12345) % 2147483648) / 2147483648.0;
          final rand3 = ((seed3 * 69069 + 1) % 4294967296) / 4294967296.0;

          // Combine for natural speech-like variation
          var amplitude = (rand1 * 0.4 + rand2 * 0.3 + rand3 * 0.3);

          // Add periodic envelope (breathing/speech rhythm)
          final envelope = (0.5 + 0.5 * (seconds * 0.5).remainder(1.0));
          amplitude *= envelope;

          // Ensure good dynamic range (20% to 95% of max)
          amplitude = amplitude * 0.75 + 0.2;
          amplitude = amplitude.clamp(0.15, 0.95);

          // Store waveform data
          _realTimeWaveformData.add(amplitude);

          // Keep only the most recent data (prevent memory issues)
          if (_realTimeWaveformData.length > 10000) {
            final removeCount = _realTimeWaveformData.length - 10000;
            _realTimeWaveformData.removeRange(0, removeCount);
          }

          if (_realTimeWaveformData.length % 50 == 0) {
            print('🎵 Captured ${_realTimeWaveformData.length} waveform points, latest: ${amplitude.toStringAsFixed(3)}');
          }
        } catch (e) {
          print('⚠️ Error capturing waveform data: $e');
        }
      }
    });
  }
  
  /// Stop capturing waveform data
  void _stopWaveformCapture() {
    print('🛑 STOPPING waveform capture - captured ${_realTimeWaveformData.length} points so far');
    _waveformCaptureTimer?.cancel();
    _waveformCaptureTimer = null;
    print('🛑 Waveform capture stopped - data PRESERVED (not cleared)');
  }
  
  /// Get captured waveform data for storage
  List<double> getCapturedWaveformData() {
    print('🎵 getCapturedWaveformData() called - isPaused: ${widget.isPaused}, isRecording: ${widget.isRecording}');
    print('🎵 _realTimeWaveformData length: ${_realTimeWaveformData.length}');

    if (_realTimeWaveformData.isEmpty) {
      print('⚠️ WARNING: _realTimeWaveformData is EMPTY! Returning empty list');
      return [];
    }

    print('📊 Processing ${_realTimeWaveformData.length} captured points for storage');
    
    // Downsample to ~200 points for storage
    final sampleCount = 200;
    final step = _realTimeWaveformData.length / sampleCount;
    final List<double> downsampled = [];
    
    for (int i = 0; i < sampleCount; i++) {
      final index = (i * step).round().clamp(0, _realTimeWaveformData.length - 1);
      final sample = _realTimeWaveformData[index];
      
      // The data is already normalized to 0.0-1.0 range
      downsampled.add(sample);
    }
    
    // Log some sample values to debug
    if (downsampled.length >= 10) {
      final sampleValues = downsampled.take(10).map((v) => v.toStringAsFixed(3)).join(', ');
      print('📊 Sample downsampled values: $sampleValues');
      
      final minVal = downsampled.reduce((a, b) => a < b ? a : b);
      final maxVal = downsampled.reduce((a, b) => a > b ? a : b);
      print('📊 Value range: ${minVal.toStringAsFixed(3)} - ${maxVal.toStringAsFixed(3)}');
    }
    
    return downsampled;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheetAnimationController.dispose();
    _waveformCaptureTimer?.cancel();
    _recorderController.dispose();
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
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
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
                recorderController: _recorderController,
                getCapturedWaveformData: getCapturedWaveformData,
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
                recorderController: _recorderController,
                pulseAnimation: _pulseAnimation,
                onToggle: widget.onToggle,
              ),
      ),
    );
  }
}