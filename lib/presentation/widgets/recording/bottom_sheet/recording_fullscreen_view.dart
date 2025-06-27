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
  final String? filePath;
  final RecorderController recorderController;
  final List<double> Function() getCapturedWaveformData;
  final VoidCallback? onPause;
  final VoidCallback? onDone;
  final VoidCallback? onChat;

  const RecordingFullscreenView({
    super.key,
    required this.title,
    required this.elapsed,
    required this.isRecording,
    required this.filePath,
    required this.recorderController,
    required this.getCapturedWaveformData,
    this.onPause,
    this.onDone,
    this.onChat,
  });

  /// Converts the elapsed recording time into formatted string
  String get _formattedTime {
    return elapsed.formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top spacer - flexible
        const Flexible(flex: 1, child: SizedBox(height: 10)),

        // Handle - flexible
        Flexible(flex: 1, child: _buildHandle()),

        // Spacing after handle - flexible
        const Flexible(flex: 1, child: SizedBox(height: 20)),

        // Title section (iOS style) - flexible
        Flexible(flex: 2, child: _buildFullscreenTitle()),

        // Date and duration info - flexible
        Flexible(flex: 1, child: _buildFullscreenSubtitle()),

        // Spacing before waveform - flexible
        const Flexible(flex: 1, child: SizedBox(height: 30)),

        // Large waveform visualization (iOS style) - flexible
        Flexible(flex: 8, child: _buildFullscreenWaveform(context)),

        // Spacing after waveform - flexible
        const Flexible(flex: 1, child: SizedBox(height: 20)),

        // Large time display (iOS style) - flexible
        Flexible(flex: 2, child: _buildFullscreenTimeDisplay()),

        // Spacing before controls - flexible
        const Flexible(flex: 1, child: SizedBox(height: 20)),

        // Playback controls (iOS style) - flexible
        Flexible(flex: 2, child: _buildFullscreenPlaybackControls()),

        // Spacing before action button - flexible
        const Flexible(flex: 2, child: SizedBox(height: 40)),

        // Main action button (Pause/Replace) - flexible
        Flexible(flex: 2, child: _buildFullscreenActionButton()),

        // Bottom spacing - flexible
        const Flexible(flex: 1, child: SizedBox(height: 40)),
      ],
    );
  }

  /// Build simple handle
  Widget _buildHandle() {
    return Container(
      width: 50,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  /// Build fullscreen title (iOS style)
  Widget _buildFullscreenTitle() {
    return Text(
      title ?? 'New Recording',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
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
    return Container(
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
    );
  }

  /// Build fullscreen time display (iOS style)
  Widget _buildFullscreenTimeDisplay() {
    return Text(
      _formattedTime,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 48,
        fontWeight: FontWeight.w300,
        letterSpacing: 1.0,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Build fullscreen playback controls (iOS style)
  Widget _buildFullscreenPlaybackControls() {
    return FullscreenPlaybackControls(
      isRecording: isRecording,
    );
  }

  /// Build fullscreen action button (Pause/Replace)
  Widget _buildFullscreenActionButton() {
    return FullscreenActionButton(
      isRecording: isRecording,
      onPause: onPause,
      onDone: onDone,
    );
  }
}