// File: presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart
import 'package:flutter/material.dart';
import '../../../../core/extensions/duration_extensions.dart';
import 'control_buttons.dart';
import '../custom_waveform/flutter_sound_waveform.dart';

/// Fullscreen view for expanded recording bottom sheet (iOS Voice Memos style)
class RecordingFullscreenView extends StatelessWidget {
  final String? title;
  final Duration elapsed;
  final bool isRecording;
  final bool isPaused;
  final String? filePath;
  final double amplitude;
  final List<double> waveData;
  final VoidCallback onToggle;
  final VoidCallback? onPause;
  final VoidCallback? onDone;
  final VoidCallback? onChat;
  final VoidCallback? onPlay;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final Function(int seekBarIndex)? onSeekBarIndexChanged;
  final int seekBarIndex;
  /// Versione del seek: incrementata ad ogni seek-and-resume per segnalare a
  /// RecordingWaveform di riposizionare la waveform sulla bacchetta.
  final int seekVersion;

  const RecordingFullscreenView({
    super.key,
    required this.title,
    required this.elapsed,
    required this.isRecording,
    this.isPaused = false,
    required this.filePath,
    required this.amplitude,
    required this.waveData,
    required this.onToggle,
    this.onPause,
    this.onDone,
    this.onChat,
    this.onPlay,
    this.onRewind,
    this.onForward,
    this.onSeekBarIndexChanged,
    this.seekBarIndex = 0,
    this.seekVersion = 0,
  });

  String get _formattedTime => elapsed.formatted;

  /// Label seek: "← 00:03 / 00:07 →"
  String _seekLabel(int barIndex) {
    final seekMs = barIndex * 50;
    final totalMs = waveData.length * 50;
    String fmt(int ms) {
      final d = Duration(milliseconds: ms);
      final m = d.inMinutes.toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    return '← ${fmt(seekMs)} / ${fmt(totalMs)} →';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(flex: 2, child: _buildHandle()),
            Flexible(flex: 2, child: _buildFullscreenTitle()),
            Flexible(flex: 1, child: _buildFullscreenSubtitle()),
            Flexible(flex: 8, child: _buildFullscreenWaveform(context)),
            Flexible(
              flex: 2,
              child: _buildSeekLabel(),
            ),
            Flexible(flex: 4, child: _buildFullscreenPlaybackControls()),
            Flexible(flex: 4, child: _buildFullscreenActionButton()),
          ],
        ),
        if (!isRecording || isPaused)
          Positioned(
            bottom: 40,
            right: 20,
            child: _buildDoneButton(),
          ),
      ],
    );
  }

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

  Widget _buildFullscreenSubtitle() {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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

  Widget _buildFullscreenWaveform(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(
        heightFactor: 0.65,
        widthFactor: 1.0,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildWaveformWidget(),
        ),
      ),
    );
  }

  Widget _buildWaveformWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RecordingWaveform(
          amplitude: amplitude,
          waveData: waveData,
          size: Size(constraints.maxWidth, constraints.maxHeight),
          waveColor: Colors.cyan,
          spacing: 2.0,
          waveThickness: 2.5,
          scaleFactor: 80.0,
          currentDuration: elapsed,
          isPaused: isPaused,
          showPlayhead: true,
          onSeekBarIndexChanged: onSeekBarIndexChanged,
          seekVersion: seekVersion,
        );
      },
    );
  }

  Widget _buildSeekLabel() {
    return Center(
      child: Text(
        _seekLabel(seekBarIndex),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

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

  Widget _buildFullscreenPlaybackControls() {
    return FullscreenPlaybackControls(
      isRecording: isRecording,
      onPlay: onPlay,
      onRewind: onRewind,
      onForward: onForward,
    );
  }

  Widget _buildFullscreenActionButton() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = (constraints.maxHeight * 0.45).clamp(70.0, 120.0);
          return GestureDetector(
            onTap: () {
              if (isRecording) {
                onPause?.call();
              } else if (isPaused) {
                onPlay?.call();
              } else {
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
                          Color(0xFFDC143C),
                          Color(0xFFB22222),
                          Color(0xFF8B0000),
                        ],
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFFFFA500),
                          Color(0xFFFFC107),
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
