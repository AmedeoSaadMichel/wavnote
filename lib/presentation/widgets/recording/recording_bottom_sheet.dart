// File: presentation/widgets/recording/recording_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/recording/recording_bloc.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../../core/enums/audio_format.dart';
import 'record_waveform.dart';
import 'fullscreen_waveform.dart';

/// Bottom sheet widget for recording interface
///
/// Integrates with RecordingBloc and follows the same visual theme
/// as the rest of the WavNote app. Provides expandable interface
/// similar to iOS Voice Memos.
class RecordingBottomSheet extends StatefulWidget {
  final FolderEntity? selectedFolder;
  final AudioFormat? selectedFormat;
  final VoidCallback? onComplete;

  const RecordingBottomSheet({
    super.key,
    this.selectedFolder,
    this.selectedFormat,
    this.onComplete,
  });

  @override
  State<RecordingBottomSheet> createState() => _RecordingBottomSheetState();
}

class _RecordingBottomSheetState extends State<RecordingBottomSheet>
    with TickerProviderStateMixin {

  // Bottom sheet drag state
  late double maxHeight;
  final double minHeight = 200;
  final double collapsedHeight = 150;
  double _sheetOffset = 0; // 0 = collapsed, 1 = fully expanded
  double _dragStartY = 0;
  double _startHeight = 0;

  // Animation controllers
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  // Recording state
  String? _currentRecordingName;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    ));

    // Auto-expand when showing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  /// Generate default recording name based on location/time
  String _generateRecordingName() {
    if (_currentRecordingName != null) return _currentRecordingName!;

    final now = DateTime.now();
    // For now, use time-based naming. Location can be added later.
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _currentRecordingName = 'Recording $timeStr';
    return _currentRecordingName!;
  }

  /// Start recording with current settings
  void _startRecording() {
    final folderId = widget.selectedFolder?.id ?? 'all_recordings';
    final format = widget.selectedFormat ?? AudioFormat.m4a;

    context.read<RecordingBloc>().add(StartRecording(
      folderId: folderId,
      format: format,
      sampleRate: format.defaultSampleRate,
      bitRate: 128000,
    ));
  }

  /// Stop recording
  void _stopRecording() {
    context.read<RecordingBloc>().add(StopRecording(
      recordingName: _currentRecordingName,
    ));
  }

  /// Toggle recording state
  void _toggleRecording(RecordingState state) {
    if (state.canStartRecording) {
      _startRecording();
    } else if (state.canStopRecording) {
      _stopRecording();
    }
  }

  /// Pause recording
  void _pauseRecording() {
    context.read<RecordingBloc>().add(const PauseRecording());
  }

  /// Resume recording
  void _resumeRecording() {
    context.read<RecordingBloc>().add(const ResumeRecording());
  }

  /// Cancel recording
  void _cancelRecording() {
    context.read<RecordingBloc>().add(const CancelRecording());
    widget.onComplete?.call();
  }

  /// Handle drag start
  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _startHeight = minHeight + (maxHeight - minHeight) * _sheetOffset;
  }

  /// Handle drag update
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    double delta = _dragStartY - details.globalPosition.dy;
    double newHeight = (_startHeight + delta).clamp(minHeight, maxHeight);
    setState(() {
      _sheetOffset = (newHeight - minHeight) / (maxHeight - minHeight);
    });
  }

  /// Handle drag end
  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _sheetOffset = _sheetOffset > 0.5 ? 1 : 0;
    });
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final centiseconds = (duration.inMilliseconds.remainder(1000) / 10).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    maxHeight = MediaQuery.of(context).size.height * 0.9;

    return BlocConsumer<RecordingBloc, RecordingState>(
      listener: (context, state) {
        if (state is RecordingCompleted) {
          // Show completion and close
          _slideController.reverse().then((_) {
            widget.onComplete?.call();
          });
        } else if (state is RecordingError) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final isRecording = state.isRecording || state.isPaused;
        final currentHeight = isRecording
            ? minHeight + (maxHeight - minHeight) * _sheetOffset
            : collapsedHeight;

        return AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return AnimatedPositioned(
              bottom: -collapsedHeight + (collapsedHeight * _slideAnimation.value),
              left: 0,
              right: 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              height: currentHeight,
              child: GestureDetector(
                onVerticalDragStart: isRecording ? _onVerticalDragStart : null,
                onVerticalDragUpdate: isRecording ? _onVerticalDragUpdate : null,
                onVerticalDragEnd: isRecording ? _onVerticalDragEnd : null,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2D1B69),
                        Color(0xFF5A2B8C),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues( alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: _buildSheetContent(state),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Build sheet content based on recording state and expansion
  Widget _buildSheetContent(RecordingState state) {
    final isExpanded = _sheetOffset > 0.8;
    final isRecording = state.isRecording || state.isPaused;

    return Column(
      children: [
        // Handle bar
        if (isRecording) ...[
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues( alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Content area
        Expanded(
          child: isExpanded
              ? _buildExpandedContent(state)
              : _buildCompactContent(state),
        ),
      ],
    );
  }

  /// Build compact content (collapsed state)
  Widget _buildCompactContent(RecordingState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Recording info
          if (state.isRecording || state.isPaused) ...[
            Text(
              _generateRecordingName(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state is RecordingInProgress
                  ? _formatDuration(state.duration)
                  : state is RecordingPaused
                  ? _formatDuration(state.duration)
                  : '00:00.00',
              style: TextStyle(
                color: Colors.white.withValues( alpha: 0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),

            // Compact waveform
            RecordWaveform(
              filePath: state is RecordingInProgress ? state.filePath : '',
              amplitude: state is RecordingInProgress ? state.amplitude : 0.0,
              isRecording: state.isRecording,
            ),
          ],

          const Spacer(),

          // Main record button
          _buildRecordButton(state),
        ],
      ),
    );
  }

  /// Build expanded content (full screen)
  Widget _buildExpandedContent(RecordingState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Recording title and time
          Text(
            _generateRecordingName(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            state is RecordingInProgress
                ? _formatDuration(state.duration)
                : state is RecordingPaused
                ? _formatDuration(state.duration)
                : '00:00.00',
            style: TextStyle(
              color: Colors.white.withValues( alpha: 0.8),
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 32),

          // Fullscreen waveform
          FullScreenWaveform(
            filePath: state is RecordingInProgress ? state.filePath : null,
            amplitude: state is RecordingInProgress ? state.amplitude : 0.0,
            isRecording: state.isRecording,
          ),

          const Spacer(),

          // Playback controls (disabled during recording)
          _buildPlaybackControls(state),

          const SizedBox(height: 32),

          // Bottom controls
          _buildBottomControls(state),
        ],
      ),
    );
  }

  /// Build main record/stop button
  Widget _buildRecordButton(RecordingState state) {
    return GestureDetector(
      onTap: () => _toggleRecording(state),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: state.isRecording ? Colors.white : Colors.red,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: (state.isRecording ? Colors.white : Colors.red)
                  .withValues( alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: state.isRecording
              ? const Icon(
            Icons.stop_rounded,
            key: ValueKey('stop'),
            color: Colors.red,
            size: 32,
          )
              : const Icon(
            Icons.fiber_manual_record,
            key: ValueKey('record'),
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  /// Build playback controls (for expanded view)
  Widget _buildPlaybackControls(RecordingState state) {
    final isDisabled = state.isRecording || state.isPaused;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: Icons.replay_10,
          onPressed: isDisabled ? null : () {},
          overlay: '10',
        ),
        _buildControlButton(
          icon: Icons.play_arrow,
          onPressed: isDisabled ? null : () {},
          size: 50,
        ),
        _buildControlButton(
          icon: Icons.forward_10,
          onPressed: isDisabled ? null : () {},
          overlay: '10',
        ),
      ],
    );
  }

  /// Build bottom controls (for expanded view)
  Widget _buildBottomControls(RecordingState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel button
        IconButton(
          onPressed: () => _cancelRecording(),
          icon: const Icon(
            Icons.close,
            color: Colors.red,
            size: 28,
          ),
        ),

        // Pause/Resume button
        if (state.canPauseRecording)
          _buildControlButton(
            icon: Icons.pause,
            onPressed: _pauseRecording,
            backgroundColor: Colors.orange.withValues( alpha: 0.2),
            iconColor: Colors.orange,
            size: 60,
          )
        else if (state.canResumeRecording)
          _buildControlButton(
            icon: Icons.play_arrow,
            onPressed: _resumeRecording,
            backgroundColor: Colors.green.withValues( alpha: 0.2),
            iconColor: Colors.green,
            size: 60,
          )
        else
          _buildRecordButton(state),

        // Done button
        TextButton(
          onPressed: state.canStopRecording ? () => _stopRecording() : null,
          child: Text(
            'Done',
            style: TextStyle(
              color: state.canStopRecording ? Colors.cyan : Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Build individual control button
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    String? overlay,
    double size = 40,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    final isEnabled = onPressed != null;
    final bgColor = backgroundColor ??
        (isEnabled ? Colors.white.withValues( alpha: 0.1) : Colors.grey.withValues( alpha: 0.1));
    final iColor = iconColor ?? (isEnabled ? Colors.white : Colors.grey);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(
            color: iColor.withValues( alpha: 0.3),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              color: iColor,
              size: size * 0.6,
            ),
            if (overlay != null)
              Text(
                overlay,
                style: TextStyle(
                  color: iColor.withValues( alpha: 0.8),
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}