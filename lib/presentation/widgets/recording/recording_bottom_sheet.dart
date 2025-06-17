import 'package:flutter/material.dart';
import 'package:wavnote/presentation/widgets/recording/fullscreen_waveform.dart';
import 'package:wavnote/presentation/widgets/recording/record_waveform.dart';

// This widget displays a draggable bottom sheet for recording audio.
// It includes compact and fullscreen modes with animated transitions,
// and adapts depending on whether recording is in progress.

class RecordBottomSheet extends StatefulWidget {
  final String? title;              // Recording title to display
  final String? filePath;           // Path to the file being recorded
  final bool isRecording;           // Whether a recording is currently in progress
  final VoidCallback onToggle;      // Callback to start/stop recording
  final Duration elapsed;           // Time elapsed since the recording started
  final double width;               // Available screen width

  const RecordBottomSheet({
    super.key,
    required this.title,
    required this.filePath,
    required this.isRecording,
    required this.onToggle,
    required this.elapsed,
    required this.width,
  });

  @override
  State<RecordBottomSheet> createState() => _RecordBottomSheetState();
}

class _RecordBottomSheetState extends State<RecordBottomSheet> {
  // Converts the elapsed recording time into mm:ss.SS format.
  String get _formattedTime {
    final ms = widget.elapsed.inMilliseconds;
    final minutes = (ms ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final centis = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$centis';
  }

  // Bottom sheet drag state
  late double maxHeight;                       // Max expanded height (set in build)
  final double minHeight = 400;               // Compact sheet height
  double _sheetOffset = 0;                    // 0 = collapsed, 1 = fully expanded
  double _dragStartY = 0;                     // Initial Y drag position
  double _startHeight = 0;                    // Height when drag started

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
  }

  // Fullscreen view shown when user drags up or sheet is expanded
  Widget _buildFullScreenView() {
    return Column(
      key: const ValueKey('fullscreen'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Spacer(),

        // Handle at the top of the sheet
        Flexible(
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

        // Animated content
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
              children: [
                if (widget.title != null)
                  Text(widget.title!, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Flexible(child: Text(_formattedTime, style: const TextStyle(color: Colors.grey, fontSize: 18))),
                const Spacer(),
                // Pass isRecording state to waveform
                Flexible(child: FullScreenWaveform(
                  filePath: widget.filePath,
                  isRecording: widget.isRecording,
                )),
                const Spacer(),
              ],
            )
                : const SizedBox(key: ValueKey(false)),
          ),
        ),

        // Playback controls (disabled while recording)
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Flexible(
                child: IconButton(
                  onPressed: widget.isRecording ? null : () {},
                  icon: circularIcon("15", Icons.rotate_left, widget.isRecording),
                ),
              ),
              Flexible(
                child: IconButton(
                  onPressed: widget.isRecording ? null : () {},
                  icon: Icon(Icons.play_arrow, color: widget.isRecording ? Colors.grey : Colors.white, size: 40),
                ),
              ),
              Flexible(
                child: IconButton(
                  onPressed: widget.isRecording ? null : () {},
                  icon: circularIcon("15", Icons.rotate_right, widget.isRecording),
                ),
              ),
            ],
          ),
        ),

        const Spacer(flex: 2),

        // Bottom row: chat, pause, done
        Flexible(
          flex: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Flexible(
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                ),
              ),
              Flexible(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(Icons.pause, color: Colors.red, size: 28),
                ),
              ),
              Flexible(
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Done', style: TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Compact view shown when sheet is collapsed
  Widget _buildCompactView() {
    return Column(
      key: const ValueKey('compact'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Spacer(),

        // Handle at top
        Flexible(
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
              children: [
                if (widget.title != null)
                  Text(widget.title!, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Flexible(child: Text(_formattedTime, style: const TextStyle(color: Colors.grey, fontSize: 18))),
                const Spacer(),
                // Pass isRecording state to waveform
                if (widget.filePath != null)
                  Flexible(child: RecordWaveform(
                    filePath: widget.filePath!,
                    isRecording: widget.isRecording, // Pass recording state
                  )),
                const Spacer(),
              ],
            )
                : const SizedBox(key: ValueKey(false)),
          ),
        ),

        // Main record toggle button
        Flexible(
          flex: 8,
          child: GestureDetector(
            onTap: widget.onToggle,
            child: Container(
              width: 100,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isRecording ? Colors.white : Colors.red,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 1000),
                  child: widget.isRecording
                      ? const Icon(Icons.stop_rounded, key: ValueKey('stop'), color: Colors.red, size: 32)
                      : const Icon(Icons.fiber_manual_record, key: ValueKey('rec'), color: Colors.red),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    maxHeight = MediaQuery.of(context).size.height;

    // When not recording, sheet is fixed height and not draggable
    final double currentHeight = widget.isRecording
        ? minHeight + (maxHeight - minHeight) * _sheetOffset
        : 150;

    return AnimatedPositioned(
      bottom: 0,
      left: 0,
      right: 0,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutCubic,
      height: currentHeight,
      child: GestureDetector(
        onVerticalDragStart: widget.isRecording ? _onVerticalDragStart : null,
        onVerticalDragUpdate: widget.isRecording ? _onVerticalDragUpdate : null,
        onVerticalDragEnd: widget.isRecording ? _onVerticalDragEnd : null,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: child,
              ),
            ),
            child: _sheetOffset > 0.90
                ? _buildFullScreenView()
                : _buildCompactView(),
          ),
        ),
      ),
    );
  }

  // Helper widget for displaying circular icons with overlayed text
  Widget circularIcon(String text, IconData icon, bool isDisabled) {
    final Color color = isDisabled ? Colors.grey : Colors.white;
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
}