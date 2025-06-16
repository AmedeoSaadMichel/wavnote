// File: presentation/screens/recording/recording_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
import '../../../domain/entities/recording_entity.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../blocs/audio_recorder/audio_recorder_bloc.dart';
import '../../widgets/recording/player_controls.dart';
import '../../../core/utils/date_formatter.dart';

/// Cosmic recording detail screen with Midnight Gospel aesthetic
///
/// Provides comprehensive recording information and playback controls including:
/// - Immersive cosmic background with flowing celestial effects
/// - Complete recording metadata with mystical presentation
/// - Full-featured audio player controls with ethereal animations
/// - Recording statistics and quality information
/// - Location and tag management with cosmic theming
/// - Action buttons for sharing, editing, and deletion
/// - Transcendent user experience with otherworldly design
class RecordingDetailScreen extends StatefulWidget {
  final RecordingEntity recording;
  final FolderEntity? folder;

  const RecordingDetailScreen({
    super.key,
    required this.recording,
    this.folder,
  });

  @override
  State<RecordingDetailScreen> createState() => _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends State<RecordingDetailScreen>
    with TickerProviderStateMixin {
  // Animation controllers for cosmic effects
  late AnimationController _backgroundController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;

  // Animations
  late Animation<double> _backgroundAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<double> _pulseAnimation;

  // UI state
  bool _showFullMetadata = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    // Background cosmic flow animation
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.linear),
    );

    // Floating elements animation
    _floatingController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    _floatingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    // Pulse animation for interactive elements
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start continuous animations
    _backgroundController.repeat();
    _floatingController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Cosmic background
          _buildCosmicBackground(),

          // Main content
          _buildMainContent(),

          // Floating cosmic elements
          _buildFloatingElements(),
        ],
      ),
    );
  }

  /// Build animated cosmic background
  Widget _buildCosmicBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.3, 0.7, 1.0],
              colors: [
                const Color(0xFF0f0023), // Deep void
                const Color(0xFF1a0033), // Deep purple
                const Color(0xFF2d1b69), // Royal purple
                const Color(0xFF1a0033), // Deep purple
              ],
            ),
          ),
          child: CustomPaint(
            painter: CosmicBackgroundPainter(
              animationValue: _backgroundAnimation.value,
              floatingValue: _floatingAnimation.value,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  /// Build main content with scrollable layout
  Widget _buildMainContent() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // App bar with cosmic styling
          _buildCosmicAppBar(),

          // Recording content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Recording header
                _buildRecordingHeader(),
                const SizedBox(height: 30),

                // Player controls
                _buildPlayerSection(),
                const SizedBox(height: 30),

                // Recording details
                _buildRecordingDetails(),
                const SizedBox(height: 30),

                // Metadata section
                _buildMetadataSection(),
                const SizedBox(height: 30),

                // Action buttons
                _buildActionButtons(),
                const SizedBox(height: 100), // Extra space for floating elements
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Build cosmic app bar
  Widget _buildCosmicAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _buildCosmicButton(
        icon: Icons.arrow_back,
        onTap: () => Navigator.pop(context),
      ),
      actions: [
        _buildCosmicButton(
          icon: Icons.share,
          onTap: _shareRecording,
        ),
        const SizedBox(width: 8),
        _buildCosmicButton(
          icon: Icons.more_vert,
          onTap: _showMoreOptions,
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build recording header with title and basic info
  Widget _buildRecordingHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recording title
        Text(
          widget.recording.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        // Folder and creation info
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_outlined,
                    color: Colors.cyan,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.folder?.name ?? 'Unknown Folder',
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              DateFormatter.formatForRecordingList(widget.recording.createdAt),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Duration and quality badges
        _buildQualityBadges(),
      ],
    );
  }

  /// Build quality and format badges
  Widget _buildQualityBadges() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildInfoBadge(
          icon: Icons.access_time,
          label: widget.recording.durationFormatted,
          color: Colors.purple,
        ),
        _buildInfoBadge(
          icon: Icons.storage,
          label: widget.recording.fileSizeFormatted,
          color: Colors.indigo,
        ),
        _buildInfoBadge(
          icon: Icons.graphic_eq,
          label: widget.recording.format.name,
          color: Colors.blue,
        ),
        _buildInfoBadge(
          icon: Icons.high_quality,
          label: widget.recording.qualityDescription,
          color: Colors.teal,
        ),
      ],
    );
  }

  /// Build info badge
  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build player section with full controls
  Widget _buildPlayerSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: PlayerControls(
        recording: widget.recording,
        showWaveform: true,
        showSpeedControl: true,
        showVolumeControl: true,
        compactMode: false,
      ),
    );
  }

  /// Build recording details section
  Widget _buildRecordingDetails() {
    return _buildCosmicCard(
      title: 'Recording Details',
      icon: Icons.info_outline,
      child: Column(
        children: [
          _buildDetailRow('Created', DateFormatter.formatFullDate(widget.recording.createdAt)),
          if (widget.recording.updatedAt != null)
            _buildDetailRow('Last Modified', DateFormatter.formatFullDate(widget.recording.updatedAt!)),
          _buildDetailRow('Sample Rate', '${widget.recording.sampleRate} Hz'),
          _buildDetailRow('Bitrate', '${widget.recording.approximateBitrate} kbps'),
          _buildDetailRow('Channels', 'Stereo'),
          _buildDetailRow('File Path', widget.recording.filePath),
          if (widget.recording.hasLocation) ...[
            const Divider(color: Colors.white24, height: 24),
            _buildDetailRow('Location', widget.recording.locationName ?? 'Unknown Location'),
            _buildDetailRow('Coordinates', '${widget.recording.latitude?.toStringAsFixed(6)}, ${widget.recording.longitude?.toStringAsFixed(6)}'),
          ],
        ],
      ),
    );
  }

  /// Build metadata section with tags and additional info
  Widget _buildMetadataSection() {
    return _buildCosmicCard(
      title: 'Metadata',
      icon: Icons.label_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.recording.tags.isNotEmpty) ...[
            const Text(
              'Tags',
              style: TextStyle(
                color: Colors.cyan,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.recording.tags.map((tag) => _buildTag(tag)).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Recording statistics
          const Text(
            'Statistics',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatisticsGrid(),
        ],
      ),
    );
  }

  /// Build statistics grid
  Widget _buildStatisticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatCard('Age', widget.recording.ageDescription, Icons.schedule),
        _buildStatCard('Size/Duration', '${(widget.recording.fileSize / widget.recording.duration.inSeconds / 1024).toStringAsFixed(1)} KB/s', Icons.speed),
        _buildStatCard('Efficiency', '${((widget.recording.fileSize / (widget.recording.duration.inSeconds * 44100 * 2 * 2)) * 100).toStringAsFixed(1)}%', Icons.tune),
        _buildStatCard('Quality Score', _getQualityScore(), Icons.star),
      ],
    );
  }

  /// Build statistic card
  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.cyan, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Build action buttons section
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Edit',
            icon: Icons.edit,
            color: Colors.blue,
            onTap: _editRecording,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            label: 'Share',
            icon: Icons.share,
            color: Colors.green,
            onTap: _shareRecording,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            label: 'Delete',
            icon: Icons.delete,
            color: Colors.red,
            onTap: _deleteRecording,
          ),
        ),
      ],
    );
  }

  /// Build action button
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build cosmic card container
  Widget _buildCosmicCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.cyan, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  /// Build detail row
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build tag chip
  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: Colors.purple,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Build cosmic button
  Widget _buildCosmicButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.cyan, size: 20),
      ),
    );
  }

  /// Build floating cosmic elements
  Widget _buildFloatingElements() {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: CustomPaint(
            painter: FloatingElementsPainter(
              animationValue: _floatingAnimation.value,
              backgroundValue: _backgroundAnimation.value,
            ),
          ),
        );
      },
    );
  }

  // ==== HELPER METHODS ====

  String _getQualityScore() {
    final score = ((widget.recording.sampleRate / 48000) *
        (widget.recording.approximateBitrate / 320) *
        100).clamp(0, 100);
    return '${score.toStringAsFixed(0)}/100';
  }

  // ==== ACTION METHODS ====

  void _editRecording() {
    // TODO: Implement recording editing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit recording functionality coming soon')),
    );
  }

  void _shareRecording() {
    // TODO: Implement recording sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share recording functionality coming soon')),
    );
  }

  void _deleteRecording() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b69),
        title: const Text('Delete Recording', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${widget.recording.name}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.cyan)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AudioRecorderBloc>().add(
                DeleteRecordingRequested(recordingId: widget.recording.id),
              );
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF2d1b69),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.red),
              title: Text(
                widget.recording.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Toggle favorite
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.cyan),
              title: const Text('Duplicate', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Duplicate recording
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move, color: Colors.green),
              title: const Text('Move to Folder', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Move to folder
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for cosmic background effects
class CosmicBackgroundPainter extends CustomPainter {
  final double animationValue;
  final double floatingValue;

  CosmicBackgroundPainter({
    required this.animationValue,
    required this.floatingValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Draw floating cosmic particles
    for (int i = 0; i < 50; i++) {
      final offset = Offset(
        (size.width * (i * 0.1) % 1) + math.sin(animationValue + i) * 20,
        (size.height * (i * 0.07) % 1) + math.cos(animationValue + i) * 15,
      );

      paint.color = Colors.cyan.withValues(alpha: 0.1 + (math.sin(animationValue + i) * 0.1));
      canvas.drawCircle(offset, 1 + math.sin(animationValue + i), paint);
    }

    // Draw cosmic waves
    final path = Path();
    for (double x = 0; x <= size.width; x += 5) {
      final y = size.height * 0.7 +
          math.sin((x / size.width) * 4 * math.pi + animationValue) * 30 +
          math.sin((x / size.width) * 2 * math.pi + animationValue * 0.5) * 15;

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    paint.color = Colors.purple.withValues(alpha: 0.1);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CosmicBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.floatingValue != floatingValue;
  }
}

/// Custom painter for floating cosmic elements
class FloatingElementsPainter extends CustomPainter {
  final double animationValue;
  final double backgroundValue;

  FloatingElementsPainter({
    required this.animationValue,
    required this.backgroundValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Draw floating stars
    for (int i = 0; i < 20; i++) {
      final x = (size.width * (i * 0.13) % 1) + math.sin(backgroundValue + i * 0.5) * 30;
      final y = (size.height * (i * 0.17) % 1) + math.cos(backgroundValue + i * 0.3) * 20;
      final opacity = 0.1 + math.sin(animationValue + i) * 0.1;

      paint.color = Colors.white.withValues(alpha: opacity);
      _drawStar(canvas, Offset(x, y), 2 + math.sin(animationValue + i), paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = (i * math.pi) / 5;
      final r = i.isEven ? radius : radius * 0.5;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(FloatingElementsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.backgroundValue != backgroundValue;
  }
}