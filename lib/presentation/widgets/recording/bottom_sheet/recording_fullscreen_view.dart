// File: presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../../../../core/extensions/duration_extensions.dart';
import 'waveform_components.dart';
import 'control_buttons.dart';

/// Fullscreen view for expanded recording bottom sheet (iOS Voice Memos style)
class RecordingFullscreenView extends StatelessWidget {
  final String? title;
  final Duration elapsed;
  final bool isRecording;
  final bool isPaused;
  final String? filePath;
  final RecorderController recorderController;
  final List<double> Function() getCapturedWaveformData;
  final VoidCallback onToggle; // Same as compact view - start/stop recording
  final VoidCallback? onPause;
  final VoidCallback? onDone;
  final VoidCallback? onChat;
  final VoidCallback? onPlay;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final Function(double)? onSeek; // Callback when user seeks to position (0.0 to 1.0)

  const RecordingFullscreenView({
    super.key,
    required this.title,
    required this.elapsed,
    required this.isRecording,
    this.isPaused = false,
    required this.filePath,
    required this.recorderController,
    required this.getCapturedWaveformData,
    required this.onToggle, // Required now
    this.onPause,
    this.onDone,
    this.onChat,
    this.onPlay,
    this.onRewind,
    this.onForward,
    this.onSeek,
  });

  /// Converts the elapsed recording time into formatted string
  String get _formattedTime {
    return elapsed.formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Handle - drag indicator (flex: 2)
            Flexible(flex: 2, child: _buildHandle()),

            // Title section - recording name (flex: 2)
            Flexible(flex: 2, child: _buildFullscreenTitle()),

            // Date and duration info - timestamp and elapsed time (flex: 1)
            Flexible(flex: 1, child: _buildFullscreenSubtitle()),

            // Large waveform visualization - main visual element (flex: 8)
            Flexible(flex: 8, child: _buildFullscreenWaveform(context)),

            // Large time display - prominent elapsed time (flex: 2)
            Flexible(flex: 2, child: _buildFullscreenTimeDisplay()),

            // Playback controls - play/pause buttons (flex: 4)
            Flexible(flex: 4, child: _buildFullscreenPlaybackControls()),

            // Main action button - pause/done controls (flex: 4)
            Flexible(flex: 4, child: _buildFullscreenActionButton()),
          ],
        ),

        // Done button in bottom right corner (show when paused or not recording)
        if (!isRecording || isPaused)
          Positioned(
            bottom: 40,
            right: 20,
            child: _buildDoneButton(),
          ),
      ],
    );
  }

  /// Build simple handle
  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 50,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  /// Build fullscreen title (iOS style)
  Widget _buildFullscreenTitle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        title ?? 'New Recording',
        style: const TextStyle(
          color: Colors.cyan,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Build fullscreen subtitle with date and duration info (iOS style)
  Widget _buildFullscreenSubtitle() {
    final now = DateTime.now();
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    return Text(
      '$timeString  $_formattedTime',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Build fullscreen waveform (iOS style)
  Widget _buildFullscreenWaveform(BuildContext context) {
    return Center(
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (!isRecording && onSeek != null) {
            // Calculate position based on drag
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPosition = box.globalToLocal(details.globalPosition);
            final width = box.size.width;
            final position = (localPosition.dx / width).clamp(0.0, 1.0);
            onSeek!(position);
          }
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: isRecording ?
            // Show real-time waveform when recording (red)
            FullscreenAudioWaveform(
              recorderController: recorderController,
              isRecording: isRecording,
            ) :
            // Show static waveform when not recording (white/grey)
            StaticWaveformDisplay(
              waveformData: getCapturedWaveformData(),
              color: Colors.white,
            ),
        ),
      ),
    );
  }

  /// Build fullscreen time display (iOS style)
  Widget _buildFullscreenTimeDisplay() {
    return Center(
      child: Text(
        _formattedTime,
        style: const TextStyle(
          color: Colors.cyan,
          fontSize: 38,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.0,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Build fullscreen playback controls (iOS style)
  Widget _buildFullscreenPlaybackControls() {
    return FullscreenPlaybackControls(
      isRecording: isRecording,
      onPlay: onPlay,
      onRewind: onRewind,
      onForward: onForward,
    );
  }

  /// Build fullscreen action button (same as compact view)
  Widget _buildFullscreenActionButton() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use 45% of available height or max 120px
          final size = (constraints.maxHeight * 0.45).clamp(70.0, 120.0);
          return GestureDetector(
            onTap: () {
              if (isRecording) {
                // If recording, call pause
                onPause?.call();
              } else if (isPaused) {
                // If paused, call play to resume
                onPlay?.call();
              } else {
                // If not recording and not paused, start recording
                onToggle();
              }
            },
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isRecording
                    ? const LinearGradient(
                        colors: [
                          Color(0xFFDC143C), // Crimson red
                          Color(0xFFB22222), // Fire brick red
                          Color(0xFF8B0000), // Dark red
                        ],
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFFFFA500), // Orange
                          Color(0xFFFFC107), // Amber/Golden yellow
                        ],
                      ),
                border: Border.all(
                  color: isRecording
                      ? const Color(0xFFFF6B6B).withValues(alpha: 0.8)
                      : Colors.cyan,
                  width: isRecording ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isRecording
                        ? const Color(0xFFDC143C).withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: isRecording ? 16 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isRecording
                      ? Icon(
                          Icons.pause,
                          key: const ValueKey('pause'),
                          color: Colors.white,
                          size: size * 0.4,
                        )
                      : isPaused
                          ? Icon(
                              Icons.play_arrow,
                              key: const ValueKey('play'),
                              color: Colors.white,
                              size: size * 0.45,
                            )
                          : Icon(
                              Icons.fiber_manual_record,
                              key: const ValueKey('rec'),
                              color: Colors.white,
                              size: size * 0.4,
                            ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build Done button for bottom right corner
  Widget _buildDoneButton() {
    return GestureDetector(
      onTap: onDone,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Done',
          style: TextStyle(
            color: Colors.cyan,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}