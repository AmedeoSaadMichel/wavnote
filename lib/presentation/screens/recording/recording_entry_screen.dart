// File: presentation/screens/recording/recording_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
import '../../blocs/recording/recording_bloc.dart';
import '../../widgets/recording/recording_bottom_sheet.dart';
import '../../../services/audio/audio_recorder_service.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../../core/enums/audio_format.dart';

/// Enhanced entry point for recording functionality
///
/// Provides a full-screen recording interface with bottom sheet
/// that matches the iOS Voice Memos app experience while maintaining
/// the WavNote visual theme.
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

/// Main recording screen with iOS Voice Memos style interface
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

  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;

  bool _showBottomSheet = false;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    // Start background animation
    _backgroundController.forward();

    // Show bottom sheet after a brief delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showBottomSheet = true;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  /// Handle recording completion
  void _onRecordingComplete() {
    Navigator.of(context).pop();
  }

  /// Show permission request dialog
  void _showPermissionDialog(RecordingPermissionStatus state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Microphone Access Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mic_off,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                state.hasMicrophone
                    ? 'Please grant microphone permission to record audio'
                    : 'No microphone detected on this device',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            if (state.hasMicrophone)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.read<RecordingBloc>().add(const RequestRecordingPermissions());
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.yellowAccent.withValues( alpha: 0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Grant Permission',
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
      body: BlocConsumer<RecordingBloc, RecordingState>(
        listener: (context, state) {
          if (state is RecordingPermissionStatus && !state.canRecord) {
            _showPermissionDialog(state);
          } else if (state is RecordingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              // Animated background
              _buildAnimatedBackground(state),

              // Main content
              SafeArea(
                child: Column(
                  children: [
                    // Header
                    _buildHeader(state),

                    // Content area
                    Expanded(
                      child: _buildContent(state),
                    ),
                  ],
                ),
              ),

              // Bottom sheet overlay
              if (_showBottomSheet)
                RecordingBottomSheet(
                  selectedFolder: widget.selectedFolder,
                  selectedFormat: widget.selectedFormat,
                  onComplete: _onRecordingComplete,
                ),
            ],
          );
        },
      ),
    );
  }

  /// Build animated background with recording state effects
  Widget _buildAnimatedBackground(RecordingState state) {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: state.isRecording
                  ? [
                const Color(0xFF8E2DE2).withValues( alpha: 0.9),
                const Color(0xFFDA22FF).withValues( alpha: 0.8),
                const Color(0xFFFF4E50).withValues( alpha: 0.7),
                Colors.red.withValues( alpha: 0.6),
              ]
                  : [
                const Color(0xFF8E2DE2),
                const Color(0xFFDA22FF),
                const Color(0xFFFF4E50),
              ],
              stops: state.isRecording
                  ? [0.0, 0.3, 0.7, 1.0]
                  : [0.0, 0.5, 1.0],
            ),
          ),
          child: state.isRecording
              ? _buildRecordingEffects()
              : _buildStaticBackground(),
        );
      },
    );
  }

  /// Build recording visual effects overlay
  Widget _buildRecordingEffects() {
    return CustomPaint(
      size: Size.infinite,
      painter: RecordingEffectsPainter(
        animation: _backgroundAnimation,
      ),
    );
  }

  /// Build static background pattern
  Widget _buildStaticBackground() {
    return CustomPaint(
      size: Size.infinite,
      painter: StaticBackgroundPainter(
        animation: _backgroundAnimation,
      ),
    );
  }

  /// Build header with back button and title
  Widget _buildHeader(RecordingState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: state.canStartRecording
                ? () => Navigator.pop(context)
                : null,
            icon: Icon(
              Icons.arrow_back,
              color: state.canStartRecording ? Colors.white : Colors.grey,
              size: 24,
            ),
          ),
          const Spacer(),

          // Title
          Text(
            state.isRecording
                ? 'Recording...'
                : 'Voice Recording',
            style: const TextStyle(
              color: Colors.yellowAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          // Settings indicator
          if (widget.selectedFolder != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.selectedFolder!.color.withValues( alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.selectedFolder!.color.withValues( alpha: 0.5),
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
                  const SizedBox(width: 6),
                  Text(
                    widget.selectedFolder!.name,
                    style: TextStyle(
                      color: widget.selectedFolder!.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(width: 60),
          ],
        ],
      ),
    );
  }

  /// Build main content area
  Widget _buildContent(RecordingState state) {
    if (state is RecordingPermissionRequesting) {
      return _buildPermissionRequestingContent();
    }

    return _buildReadyContent(state);
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

  /// Build ready to record content
  Widget _buildReadyContent(RecordingState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Main visual indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: state.isRecording ? 160 : 120,
            height: state.isRecording ? 160 : 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues( alpha: 0.1),
              border: Border.all(
                color: state.isRecording
                    ? Colors.red.withValues( alpha: 0.5)
                    : Colors.white.withValues( alpha: 0.3),
                width: state.isRecording ? 3 : 2,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                state.isRecording ? Icons.graphic_eq : Icons.mic,
                key: ValueKey(state.isRecording),
                size: state.isRecording ? 80 : 60,
                color: state.isRecording ? Colors.red : Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Status text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              state.isRecording
                  ? 'Tap the recording controls below'
                  : state is RecordingPermissionStatus && state.canRecord
                  ? 'Ready to Record'
                  : 'Setting up recording...',
              key: ValueKey(state.runtimeType),
              style: TextStyle(
                color: Colors.white.withValues( alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Format info
          if (widget.selectedFormat != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.selectedFormat!.color.withValues( alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.selectedFormat!.color.withValues( alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.selectedFormat!.icon,
                    color: widget.selectedFormat!.color,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.selectedFormat!.name} Format',
                    style: TextStyle(
                      color: widget.selectedFormat!.color,
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
}

/// Custom painter for recording effects
class RecordingEffectsPainter extends CustomPainter {
  final Animation<double> animation;

  RecordingEffectsPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Draw pulsing circles
    for (int i = 0; i < 3; i++) {
      final radius = (50 + i * 30) * animation.value;
      final opacity = (1.0 - animation.value) * 0.1;

      paint.color = Colors.red.withValues( alpha: opacity);

      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius,
        paint,
      );
    }

    // Draw flowing particles
    final particlePaint = Paint()
      ..color = Colors.white.withValues( alpha: 0.1)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) + (animation.value * 360);
      final distance = 100 + (animation.value * 50);

      final x = size.width / 2 + distance * math.cos(angle * math.pi / 180);
      final y = size.height / 2 + distance * math.sin(angle * math.pi / 180);

      canvas.drawCircle(
        Offset(x, y),
        3 * animation.value,
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom painter for static background
class StaticBackgroundPainter extends CustomPainter {
  final Animation<double> animation;

  StaticBackgroundPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues( alpha: 0.05 * animation.value)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw concentric circles
    for (int i = 1; i <= 5; i++) {
      final radius = (i * 50) * animation.value;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius,
        paint,
      );
    }

    // Draw grid pattern
    paint.strokeWidth = 0.5;
    final gridSize = 50.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}