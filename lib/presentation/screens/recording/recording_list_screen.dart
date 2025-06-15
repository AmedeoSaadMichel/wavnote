// File: presentation/screens/recording/recording_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
import '../../../domain/entities/folder_entity.dart';
import '../../../core/enums/audio_format.dart';
import '../../blocs/recording/recording_bloc.dart';
import '../../widgets/recording/recording_bottom_sheet.dart';
import '../../../services/audio/audio_recorder_service.dart';

/// Midnight Gospel inspired Recording Screen - Organic Cloud Style
///
/// Features flowing organic shapes, scattered stars, and cloud-like formations
/// matching the authentic Midnight Gospel visual aesthetic.
/// Now includes integrated recording functionality with bottom sheet.
class RecordingListScreen extends StatefulWidget {
  final FolderEntity folder;

  const RecordingListScreen({
    super.key,
    required this.folder,
  });

  @override
  State<RecordingListScreen> createState() => _RecordingListScreenState();
}

class _RecordingListScreenState extends State<RecordingListScreen>
    with TickerProviderStateMixin {

  late AnimationController _cloudController;
  late AnimationController _starController;
  late AnimationController _pulseController;
  late Animation<double> _cloudAnimation;
  late Animation<double> _starAnimation;

  bool _showRecordingSheet = false;

  @override
  void initState() {
    super.initState();

    // Slow cloud drift animation
    _cloudController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Twinkling stars animation
    _starController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Gentle pulse for UI elements
    _pulseController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _cloudAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_cloudController);

    _starAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _starController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _cloudController.dispose();
    _starController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Show recording bottom sheet
  void _showRecordingBottomSheet() {
    setState(() {
      _showRecordingSheet = true;
    });
  }

  /// Hide recording bottom sheet
  void _hideRecordingBottomSheet() {
    setState(() {
      _showRecordingSheet = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Organic cloud background
          _buildOrganicCloudBackground(),

          // Scattered stars
          _buildScatteredStars(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header with folder name
                _buildOrganicHeader(),

                // Recordings list
                Expanded(
                  child: _buildRecordingsList(),
                ),
              ],
            ),
          ),

          // Organic recording button (always visible)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: _buildOrganicRecordingButton(),
            ),
          ),

          // Recording bottom sheet overlay
          if (_showRecordingSheet)
            BlocProvider(
              create: (context) {
                final audioService = AudioRecorderService();
                return RecordingBloc(audioService: audioService)
                  ..add(const CheckRecordingPermissions());
              },
              child: RecordingBottomSheet(
                selectedFolder: widget.folder,
                selectedFormat: AudioFormat.m4a, // Default
                onComplete: _hideRecordingBottomSheet,
              ),
            ),
        ],
      ),
    );
  }

  /// Build organic flowing cloud background
  Widget _buildOrganicCloudBackground() {
    return AnimatedBuilder(
      animation: _cloudAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
          painter: OrganicCloudPainter(_cloudAnimation.value),
        );
      },
    );
  }

  /// Build scattered twinkling stars
  Widget _buildScatteredStars() {
    return AnimatedBuilder(
      animation: _starAnimation,
      builder: (context, child) {
        return Stack(
          children: _generateStars(),
        );
      },
    );
  }

  /// Generate random stars with twinkling effect
  List<Widget> _generateStars() {
    final stars = <Widget>[];
    final random = math.Random(42); // Fixed seed for consistent positions

    for (int i = 0; i < 25; i++) {
      final left = random.nextDouble() * MediaQuery.of(context).size.width;
      final top = random.nextDouble() * MediaQuery.of(context).size.height;
      final starType = random.nextInt(3);
      final size = random.nextDouble() * 8 + 4;
      final twinkleOffset = random.nextDouble() * math.pi * 2;

      stars.add(
        Positioned(
          left: left,
          top: top,
          child: AnimatedBuilder(
            animation: _starController,
            builder: (context, child) {
              final opacity = 0.4 + (math.sin(_starController.value * 2 * math.pi + twinkleOffset) * 0.4);
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: _buildStar(starType, size),
              );
            },
          ),
        ),
      );
    }

    return stars;
  }

  /// Build individual star based on type
  Widget _buildStar(int type, double size) {
    switch (type) {
      case 0: // Four-pointed star
        return Icon(
          Icons.add,
          size: size,
          color: Colors.yellowAccent,
        );
      case 1: // Diamond star
        return Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Colors.pinkAccent,
              shape: BoxShape.rectangle,
            ),
          ),
        );
      case 2: // Circle star
        return Container(
          width: size * 0.6,
          height: size * 0.6,
          decoration: const BoxDecoration(
            color: Colors.cyanAccent,
            shape: BoxShape.circle,
          ),
        );
      default:
        return const SizedBox();
    }
  }

  /// Build organic header
  Widget _buildOrganicHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Navigation row
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),

          const SizedBox(height: 20),

          // Folder name with organic styling
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                // Folder icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.folder.color.withValues( alpha:0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.folder.color.withValues( alpha:0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    widget.folder.icon,
                    color: widget.folder.color,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 16),

                // Folder name
                Text(
                  widget.folder.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Recording count
                Text(
                  widget.folder.recordingCountText,
                  style: TextStyle(
                    color: Colors.white.withValues( alpha:0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build recordings list
  Widget _buildRecordingsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: widget.folder.isEmpty
          ? _buildEmptyState()
          : _buildRecordingsListView(),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          Text(
            'No recordings yet',
            style: TextStyle(
              color: Colors.white.withValues( alpha:0.9),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Tap the record button to start',
            style: TextStyle(
              color: Colors.white.withValues( alpha:0.7),
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 100), // Space for record button
        ],
      ),
    );
  }

  /// Build recordings list view
  Widget _buildRecordingsListView() {
    // Mock recordings data
    final mockRecordings = List.generate(
      math.max(2, widget.folder.recordingCount), // Show at least 2 for demo
          (index) => {
        'name': index == 0 ? '88 Bostall Lane 2' : '88 Bostall Lane',
        'date': '10 Jun 2025',
        'duration': index == 0 ? '00:14' : '01:23',
        'isPlaying': index == 0,
      },
    );

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120), // Space for record button
      itemCount: mockRecordings.length,
      itemBuilder: (context, index) {
        return _buildRecordingItem(mockRecordings[index]);
      },
    );
  }

  /// Build individual recording item
  Widget _buildRecordingItem(Map<String, dynamic> recording) {
    final isPlaying = recording['isPlaying'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF4A1A5C).withValues( alpha:0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues( alpha:0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recording name and date
          Text(
            recording['name'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            recording['date'],
            style: TextStyle(
              color: Colors.white.withValues( alpha:0.7),
              fontSize: 14,
            ),
          ),

          if (isPlaying) ...[
            const SizedBox(height: 16),

            // Waveform visualization
            _buildWaveform(),

            const SizedBox(height: 12),

            // Time display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '00:00',
                  style: TextStyle(
                    color: Colors.white.withValues( alpha:0.8),
                    fontSize: 12,
                  ),
                ),
                Text(
                  recording['duration'],
                  style: TextStyle(
                    color: Colors.white.withValues( alpha:0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Control buttons
            _buildControlButtons(),
          ],
        ],
      ),
    );
  }

  /// Build waveform visualization
  Widget _buildWaveform() {
    return Container(
      height: 60,
      child: Row(
        children: [
          // Play position indicator
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 8),

          // Waveform bars
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 60),
              painter: WaveformPainter(),
            ),
          ),
        ],
      ),
    );
  }

  /// Build control buttons
  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Waveform button
        _buildControlButton(
          icon: Icons.graphic_eq,
          color: Colors.blueAccent,
        ),

        // Rewind button
        _buildControlButton(
          icon: Icons.replay_10,
          color: Colors.white,
        ),

        // Play/Pause button
        _buildControlButton(
          icon: Icons.play_arrow,
          color: Colors.white,
          isLarge: true,
        ),

        // Forward button
        _buildControlButton(
          icon: Icons.forward_10,
          color: Colors.white,
        ),

        // Delete button
        _buildControlButton(
          icon: Icons.delete_outline,
          color: Colors.blueAccent,
        ),
      ],
    );
  }

  /// Build individual control button
  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    bool isLarge = false,
  }) {
    final size = isLarge ? 50.0 : 40.0;
    final iconSize = isLarge ? 28.0 : 20.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isLarge ? Colors.white : Colors.transparent,
        shape: BoxShape.circle,
        border: isLarge ? null : Border.all(
          color: color.withValues( alpha:0.5),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: isLarge ? Colors.black : color,
        size: iconSize,
      ),
    );
  }

  /// Build organic recording button
  Widget _buildOrganicRecordingButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (math.sin(_pulseController.value * 2 * math.pi) * 0.05);
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: _showRecordingBottomSheet,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFFF4444),
                    Color(0xFFDD2222),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues( alpha:0.3),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.fiber_manual_record,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for organic flowing clouds
class OrganicCloudPainter extends CustomPainter {
  final double animation;

  OrganicCloudPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Background base
    paint.color = const Color(0xFF6B2D8E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw flowing organic shapes
    _drawOrganicShape(canvas, size, const Color(0xFFE85A9B), 0.0, 0.1);
    _drawOrganicShape(canvas, size, const Color(0xFF8B5FBF), 0.2, 0.3);
    _drawOrganicShape(canvas, size, const Color(0xFF4A9EE8), 0.4, 0.6);
    _drawOrganicShape(canvas, size, const Color(0xFF6BCF7F), 0.6, 0.8);
    _drawOrganicShape(canvas, size, const Color(0xFFFFB347), 0.8, 1.0);
  }

  void _drawOrganicShape(Canvas canvas, Size size, Color color, double startY, double endY) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Create flowing organic shapes
    final baseY = size.height * startY;
    final amplitude = size.height * 0.15;
    final frequency = 0.01;

    path.moveTo(0, baseY);

    for (double x = 0; x <= size.width; x += 5) {
      // Multiple sine wave layers for organic feel
      final wave1 = math.sin((x * frequency) + (animation * 2 * math.pi)) * amplitude * 0.5;
      final wave2 = math.sin((x * frequency * 2.3) + (animation * 1.5 * math.pi)) * amplitude * 0.3;
      final wave3 = math.sin((x * frequency * 0.7) + (animation * 0.8 * math.pi)) * amplitude * 0.2;

      final y = baseY + wave1 + wave2 + wave3;
      path.lineTo(x, y);
    }

    // Close the shape to create cloud-like forms
    path.lineTo(size.width, size.height * endY);
    path.lineTo(0, size.height * endY);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final random = math.Random(42);
    final barWidth = 2.0;
    final spacing = 3.0;
    final barCount = (size.width / (barWidth + spacing)).floor();

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing);
      final height = random.nextDouble() * size.height * 0.8 + size.height * 0.1;
      final y = (size.height - height) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, height),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}