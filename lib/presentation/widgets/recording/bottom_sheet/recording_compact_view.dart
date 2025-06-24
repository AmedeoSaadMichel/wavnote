// File: presentation/widgets/recording/bottom_sheet/recording_compact_view.dart
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../../../../core/extensions/duration_extensions.dart';
import 'waveform_components.dart';

/// Compact view for collapsed recording bottom sheet
class RecordingCompactView extends StatelessWidget {
  final String? title;
  final Duration elapsed;
  final bool isRecording;
  final String? filePath;
  final RecorderController recorderController;
  final Animation<double> pulseAnimation;
  final VoidCallback onToggle;

  const RecordingCompactView({
    super.key,
    required this.title,
    required this.elapsed,
    required this.isRecording,
    required this.filePath,
    required this.recorderController,
    required this.pulseAnimation,
    required this.onToggle,
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
        // Top spacer
        const Spacer(),
        
        // Handle at top
        Flexible(
          flex: 1,
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
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
            child: isRecording
                ? _buildRecordingContent()
                : const SizedBox(key: ValueKey(false)),
          ),
        ),

        // Main record toggle button - centered
        Flexible(
          flex: 8,
          child: Center(
            child: _buildRecordButton(),
          ),
        ),

        // Bottom spacer
        const Spacer(),
      ],
    );
  }

  /// Build recording content when recording is active
  Widget _buildRecordingContent() {
    return Column(
      key: const ValueKey(true),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (title != null)
          Flexible(
            flex: 4,
            child: Text(
              title!, 
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 22, 
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const Spacer(flex: 1),
        Flexible(
          flex: 4,
          child: Text(
            _formattedTime, 
            style: const TextStyle(
              color: Colors.grey, 
              fontSize: 18,
            ),
          ),
        ),
        const Spacer(flex: 2),
        if (filePath != null) 
          Flexible(
            flex: 10,
            child: Center(
              child: Container(
                height: 120,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: CompactAudioWaveform(
                  recorderController: recorderController,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build record button with pulse animation
  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording ? Colors.white : Colors.red,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 1000),
                child: isRecording
                    ? const Icon(
                        Icons.stop_rounded, 
                        key: ValueKey('stop'), 
                        color: Colors.red, 
                        size: 28,
                      )
                    : const Icon(
                        Icons.fiber_manual_record, 
                        key: ValueKey('rec'), 
                        color: Colors.red,
                        size: 30,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}