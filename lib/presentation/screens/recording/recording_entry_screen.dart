// File: presentation/screens/recording/recording_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/recording/recording_bloc.dart';
import '../../../services/audio/audio_recorder_service.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../../core/enums/audio_format.dart';

/// Entry point for recording functionality with its own provider
///
/// This screen creates its own RecordingBloc instance to avoid provider issues
class RecordingEntryScreen extends StatelessWidget {
  final FolderEntity? selectedFolder;
  final AudioFormat? selectedFormat;

  const RecordingEntryScreen({
    super.key,
    this.selectedFolder,
    this.selectedFormat,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final audioService = AudioRecorderService();
        return RecordingBloc(audioService: audioService)
          ..add(const CheckRecordingPermissions());
      },
      child: RecordingScreen(
        selectedFolder: selectedFolder,
        selectedFormat: selectedFormat,
      ),
    );
  }
}

/// Main recording screen with beautiful UI
class RecordingScreen extends StatefulWidget {
  final FolderEntity? selectedFolder;
  final AudioFormat? selectedFormat;

  const RecordingScreen({
    super.key,
    this.selectedFolder,
    this.selectedFormat,
  });

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  TextEditingController? _nameController;
  String? _recordingName;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _nameController?.dispose();
    super.dispose();
  }

  /// Start recording with current settings
  void _startRecording() {
    final folderId = widget.selectedFolder?.id ?? 'all_recordings';
    final format = widget.selectedFormat ?? AudioFormat.wav;

    context.read<RecordingBloc>().add(StartRecording(
      folderId: folderId,
      format: format,
      sampleRate: format.defaultSampleRate,
      bitRate: 128000,
    ));

    _pulseController.repeat(reverse: true);
  }

  /// Stop recording with optional name
  void _stopRecording() {
    _pulseController.stop();

    if (_recordingName?.isNotEmpty == true) {
      context.read<RecordingBloc>().add(StopRecording(recordingName: _recordingName));
    } else {
      context.read<RecordingBloc>().add(const StopRecording());
    }
  }

  /// Pause current recording
  void _pauseRecording() {
    context.read<RecordingBloc>().add(const PauseRecording());
    _pulseController.stop();
  }

  /// Resume paused recording
  void _resumeRecording() {
    context.read<RecordingBloc>().add(const ResumeRecording());
    _pulseController.repeat(reverse: true);
  }

  /// Cancel current recording
  void _cancelRecording() {
    context.read<RecordingBloc>().add(const CancelRecording());
    _pulseController.stop();
    Navigator.of(context).pop();
  }

  /// Show recording name dialog
  void _showNameDialog() {
    _nameController = TextEditingController(text: _recordingName ?? '');

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Recording Name',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter recording name (optional)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.yellowAccent),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.yellowAccent, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _recordingName = _nameController?.text.trim();
                });
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.yellowAccent.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.yellowAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8E2DE2),
              Color(0xFFDA22FF),
              Color(0xFFFF4E50),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocConsumer<RecordingBloc, RecordingState>(
            listener: (context, state) {
              if (state is RecordingCompleted) {
                _showCompletionDialog(state.recording.name);
              } else if (state is RecordingError) {
                _showErrorDialog(state.message);
              }
            },
            builder: (context, state) {
              return Column(
                children: [
                  // Header
                  _buildHeader(state),

                  // Main content based on state
                  Expanded(
                    child: _buildMainContent(state),
                  ),

                  // Controls
                  _buildControls(state),

                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build header with back button and settings
  Widget _buildHeader(RecordingState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: state.canStartRecording ? () => Navigator.pop(context) : null,
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          const Spacer(),
          const Text(
            'Voice Recording',
            style: TextStyle(
              color: Colors.yellowAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (state.canStartRecording) ...[
            GestureDetector(
              onTap: _showNameDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF5A2B8C).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit, color: Colors.cyan, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _recordingName?.isNotEmpty == true ? _recordingName! : 'Name',
                      style: const TextStyle(
                        color: Colors.cyan,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(width: 60), // Placeholder for alignment
          ],
        ],
      ),
    );
  }

  /// Build main content area
  Widget _buildMainContent(RecordingState state) {
    if (state is RecordingPermissionRequesting) {
      return _buildPermissionRequestingContent();
    }

    if (state is RecordingPermissionStatus && !state.canRecord) {
      return _buildPermissionDeniedContent(state);
    }

    if (state.isRecording || state.isPaused) {
      return _buildRecordingContent(state);
    }

    return _buildInitialContent();
  }

  /// Build permission requesting content
  Widget _buildPermissionRequestingContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.yellowAccent),
          SizedBox(height: 24),
          Text(
            'Requesting microphone permission...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  /// Build permission denied content
  Widget _buildPermissionDeniedContent(RecordingPermissionStatus state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.mic_off,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 24),
          const Text(
            'Microphone Access Required',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            state.hasMicrophone
                ? 'Please grant microphone permission to record audio'
                : 'No microphone detected on this device',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (state.hasMicrophone)
            ElevatedButton.icon(
              onPressed: () {
                context.read<RecordingBloc>().add(const RequestRecordingPermissions());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellowAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.mic),
              label: const Text('Grant Permission'),
            ),
        ],
      ),
    );
  }

  /// Build initial content (ready to record)
  Widget _buildInitialContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Microphone icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.mic,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          const Text(
            'Ready to Record',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle with folder info
          if (widget.selectedFolder != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.selectedFolder!.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.selectedFolder!.color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.selectedFolder!.icon,
                    color: widget.selectedFolder!.color,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recording to: ${widget.selectedFolder!.name}',
                    style: TextStyle(
                      color: widget.selectedFolder!.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Build active recording content
  Widget _buildRecordingContent(RecordingState state) {
    final duration = state is RecordingInProgress ? state.duration
        : state is RecordingPaused ? state.duration
        : Duration.zero;

    final amplitude = state is RecordingInProgress ? state.amplitude : 0.0;
    final isPaused = state.isPaused;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated recording indicator
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isPaused ? 1.0 : _pulseAnimation.value,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPaused
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                    border: Border.all(
                      color: isPaused ? Colors.orange : Colors.red,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    isPaused ? Icons.pause : Icons.mic,
                    size: 70,
                    color: isPaused ? Colors.orange : Colors.red,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Duration display
          Text(
            _formatDuration(duration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Status text
          Text(
            isPaused ? 'Recording Paused' : 'Recording...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 32),

          // Mock amplitude visualization
          if (!isPaused)
            Container(
              height: 60,
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(20, (index) {
                  final height = 10 + (amplitude * 40) + (index % 3 * 10);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 6,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.cyan,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  /// Build control buttons
  Widget _buildControls(RecordingState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Cancel/Back button
          if (state.canCancelRecording)
            _buildControlButton(
              icon: Icons.close,
              color: Colors.grey,
              onPressed: _cancelRecording,
              label: 'Cancel',
            )
          else
            const SizedBox(width: 80),

          // Main action button
          _buildMainActionButton(state),

          // Secondary action button
          if (state.canPauseRecording)
            _buildControlButton(
              icon: Icons.pause,
              color: Colors.orange,
              onPressed: _pauseRecording,
              label: 'Pause',
            )
          else if (state.canResumeRecording)
            _buildControlButton(
              icon: Icons.play_arrow,
              color: Colors.green,
              onPressed: _resumeRecording,
              label: 'Resume',
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  /// Build main action button (record/stop)
  Widget _buildMainActionButton(RecordingState state) {
    if (state.canStartRecording) {
      return _buildControlButton(
        icon: Icons.fiber_manual_record,
        color: Colors.red,
        onPressed: _startRecording,
        label: 'Record',
        isLarge: true,
      );
    } else if (state.canStopRecording) {
      return _buildControlButton(
        icon: Icons.stop,
        color: Colors.red,
        onPressed: _stopRecording,
        label: 'Stop',
        isLarge: true,
      );
    } else {
      return _buildControlButton(
        icon: Icons.hourglass_empty,
        color: Colors.grey,
        onPressed: null,
        label: 'Wait',
        isLarge: true,
      );
    }
  }

  /// Build individual control button
  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required String label,
    bool isLarge = false,
  }) {
    final size = isLarge ? 80.0 : 60.0;
    final iconSize = isLarge ? 40.0 : 24.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onPressed != null ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
              border: Border.all(
                color: onPressed != null ? color : Colors.grey,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: onPressed != null ? color : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: onPressed != null ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Show completion dialog
  void _showCompletionDialog(String recordingName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Recording Completed',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Successfully saved "$recordingName"',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close recording screen
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Recording Error',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}