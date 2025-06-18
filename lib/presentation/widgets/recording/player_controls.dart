// File: presentation/widgets/recording/player_controls.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
import '../../../domain/entities/recording_entity.dart';
import '../../bloc/audio_player/audio_player_bloc.dart';
import '../../bloc/audio_player/audio_player_event.dart';
import '../../bloc/audio_player/audio_player_state.dart';

/// Cosmic player controls widget with Midnight Gospel aesthetic
///
/// Provides comprehensive audio playback controls including:
/// - Play/pause/stop with ethereal animations
/// - Position slider with celestial progress tracking
/// - Speed control with mystical speed selection
/// - Volume control with cosmic amplitude visualization
/// - Time display with sacred duration formatting
/// - Waveform visualization with flowing energy patterns
class PlayerControls extends StatefulWidget {
  final RecordingEntity recording;
  final bool showWaveform;
  final bool showSpeedControl;
  final bool showVolumeControl;
  final bool compactMode;
  final VoidCallback? onClose;

  const PlayerControls({
    super.key,
    required this.recording,
    this.showWaveform = true,
    this.showSpeedControl = true,
    this.showVolumeControl = true,
    this.compactMode = false,
    this.onClose,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls>
    with TickerProviderStateMixin {
  // Animation controllers for cosmic effects
  late AnimationController _pulseController;
  late AnimationController _waveController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  // Control state
  bool _isDraggingPosition = false;
  double _dragPosition = 0.0;

  // Playback speeds with cosmic descriptions
  final List<PlaybackSpeed> _playbackSpeeds = [
    PlaybackSpeed(0.25, 'Meditative', '🐌'),
    PlaybackSpeed(0.5, 'Contemplative', '🧘'),
    PlaybackSpeed(0.75, 'Thoughtful', '💭'),
    PlaybackSpeed(1.0, 'Natural', '⭐'),
    PlaybackSpeed(1.25, 'Flowing', '🌊'),
    PlaybackSpeed(1.5, 'Energetic', '⚡'),
    PlaybackSpeed(1.75, 'Swift', '🚀'),
    PlaybackSpeed(2.0, 'Transcendent', '✨'),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    // Pulse animation for play button
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wave animation for progress visualization
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );

    // Start continuous animations
    _waveController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioPlayerBloc, AudioPlayerState>(
      builder: (context, state) {
        return Container(
          padding: EdgeInsets.all(widget.compactMode ? 12 : 20),
          decoration: _buildCosmicBackground(),
          child: widget.compactMode
              ? _buildCompactControls(state)
              : _buildFullControls(state),
        );
      },
    );
  }

  /// Build cosmic background decoration
  BoxDecoration _buildCosmicBackground() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1a0033), // Deep purple
          Color(0xFF2d1b69), // Royal purple
          Color(0xFF1a0033), // Deep purple
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.cyan.withValues(alpha: 0.3),
          blurRadius: 20,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: Colors.purple.withValues(alpha: 0.2),
          blurRadius: 30,
          spreadRadius: 5,
        ),
      ],
    );
  }

  /// Build compact controls for smaller spaces
  Widget _buildCompactControls(AudioPlayerState state) {
    return Row(
      children: [
        _buildPlayPauseButton(state, compact: true),
        const SizedBox(width: 12),
        Expanded(child: _buildProgressSlider(state, compact: true)),
        const SizedBox(width: 12),
        _buildTimeDisplay(state, compact: true),
        if (widget.onClose != null) ...[
          const SizedBox(width: 8),
          _buildCloseButton(),
        ],
      ],
    );
  }

  /// Build full controls with all features
  Widget _buildFullControls(AudioPlayerState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with recording info and close button
        _buildHeader(),
        const SizedBox(height: 20),

        // Waveform visualization
        if (widget.showWaveform) ...[
          _buildWaveformVisualization(state),
          const SizedBox(height: 20),
        ],

        // Progress slider and time
        _buildProgressSection(state),
        const SizedBox(height: 20),

        // Main control buttons
        _buildMainControls(state),
        const SizedBox(height: 16),

        // Secondary controls
        _buildSecondaryControls(state),
      ],
    );
  }

  /// Build header with recording info
  Widget _buildHeader() {
    return Row(
      children: [
        // Recording icon
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.graphic_eq,
            color: Colors.cyan,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),

        // Recording info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.recording.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.recording.qualityDescription} • ${widget.recording.fileSizeFormatted}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Close button
        if (widget.onClose != null) _buildCloseButton(),
      ],
    );
  }

  /// Build waveform visualization
  Widget _buildWaveformVisualization(AudioPlayerState state) {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(
            painter: WaveformPainter(
              progress: _getPlaybackProgress(state),
              amplitude: _getAmplitude(state),
              waveOffset: _waveAnimation.value,
              isPlaying: state.isPlaying,
            ),
            size: const Size(double.infinity, 60),
          ),
        );
      },
    );
  }

  /// Build progress section with slider and time
  Widget _buildProgressSection(AudioPlayerState state) {
    return Column(
      children: [
        _buildProgressSlider(state),
        const SizedBox(height: 8),
        _buildTimeDisplay(state),
      ],
    );
  }

  /// Build progress slider
  Widget _buildProgressSlider(AudioPlayerState state, {bool compact = false}) {
    final progress = _isDraggingPosition ? _dragPosition : _getPlaybackProgress(state);
    final duration = _getPlaybackDuration(state);

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: compact ? 4 : 6,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: compact ? 8 : 12),
        overlayShape: RoundSliderOverlayShape(overlayRadius: compact ? 16 : 24),
        activeTrackColor: Colors.cyan,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
        thumbColor: Colors.cyan,
        overlayColor: Colors.cyan.withValues(alpha: 0.2),
      ),
      child: Slider(
        value: progress,
        onChanged: duration.inMilliseconds > 0
            ? (value) {
          setState(() {
            _isDraggingPosition = true;
            _dragPosition = value;
          });
        }
            : null,
        onChangeEnd: (value) {
          setState(() {
            _isDraggingPosition = false;
          });
          final position = Duration(
            milliseconds: (value * duration.inMilliseconds).round(),
          );
          context.read<AudioPlayerBloc>().add(SeekToPositionEvent(position: position));
        },
      ),
    );
  }

  /// Build time display
  Widget _buildTimeDisplay(AudioPlayerState state, {bool compact = false}) {
    final position = _getPlaybackPosition(state);
    final duration = _getPlaybackDuration(state);
    final remaining = duration - position;

    if (compact) {
      return Text(
        '${_formatDuration(position)} / ${_formatDuration(duration)}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatDuration(position),
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          '-${_formatDuration(remaining)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// Build main control buttons
  Widget _buildMainControls(AudioPlayerState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skip backward 10s
        _buildControlButton(
          icon: Icons.replay_10,
          onPressed: () => _skipBackward(state),
          size: 40,
        ),
        const SizedBox(width: 20),

        // Play/Pause button
        _buildPlayPauseButton(state),
        const SizedBox(width: 20),

        // Skip forward 30s
        _buildControlButton(
          icon: Icons.forward_30,
          onPressed: () => _skipForward(state),
          size: 40,
        ),
      ],
    );
  }

  /// Build play/pause button with cosmic animation
  Widget _buildPlayPauseButton(AudioPlayerState state, {bool compact = false}) {
    final isPlaying = state.isPlaying;
    final size = compact ? 40.0 : 60.0;
    final iconSize = compact ? 20.0 : 30.0;

    // Update pulse animation based on playing state
    if (isPlaying && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isPlaying && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    return AnimatedBuilder(
      animation: isPlaying ? _pulseAnimation : AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Transform.scale(
          scale: isPlaying ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: () => _togglePlayPause(state),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPlaying
                      ? [Colors.cyan, Colors.blue]
                      : [Colors.purple, Colors.indigo],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:                     (isPlaying ? Colors.cyan : Colors.purple).withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build secondary controls
  Widget _buildSecondaryControls(AudioPlayerState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Speed control
        if (widget.showSpeedControl) _buildSpeedControl(state),

        // Stop button
        _buildControlButton(
          icon: Icons.stop,
          onPressed: state.isPlaying || state.isPaused
              ? () => context.read<AudioPlayerBloc>().add(const StopPlaybackEvent())
              : null,
          size: 36,
        ),

        // Volume control
        if (widget.showVolumeControl) _buildVolumeControl(state),
      ],
    );
  }

  /// Build speed control with cosmic menu
  Widget _buildSpeedControl(AudioPlayerState state) {
    final currentSpeed = state is AudioPlayerPlaying ? state.playbackSpeed : 1.0;

    return PopupMenuButton<double>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed, color: Colors.cyan, size: 16),
            const SizedBox(width: 4),
            Text(
              '${currentSpeed}x',
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onSelected: (speed) {
        context.read<AudioPlayerBloc>().add(SetPlaybackSpeedEvent(speed: speed));
      },
      itemBuilder: (context) => _playbackSpeeds.map((speed) {
        final isSelected = speed.value == currentSpeed;
        return PopupMenuItem<double>(
          value: speed.value,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? Colors.cyan.withValues(alpha: 0.2) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(speed.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${speed.value}x',
                        style: TextStyle(
                          color: isSelected ? Colors.cyan : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        speed.description,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.cyan.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check, color: Colors.cyan, size: 16),
              ],
            ),
          ),
        );
      }).toList(),
      color: const Color(0xFF2d1b69),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
    );
  }

  /// Build volume control
  Widget _buildVolumeControl(AudioPlayerState state) {
    final currentVolume = state is AudioPlayerPlaying ? state.volume : 1.0;

    return GestureDetector(
      onTap: () {
        // Toggle volume between 0 and 1
        final newVolume = currentVolume > 0 ? 0.0 : 1.0;
        context.read<AudioPlayerBloc>().add(SetVolumeEvent(volume: newVolume));
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
        ),
        child: Icon(
          _getVolumeIcon(currentVolume),
          color: Colors.cyan,
          size: 20,
        ),
      ),
    );
  }

  /// Build control button
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double size,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: onPressed != null
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: onPressed != null
                ? Colors.cyan.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Icon(
          icon,
          color: onPressed != null ? Colors.cyan : Colors.white.withValues(alpha: 0.3),
          size: size * 0.5,
        ),
      ),
    );
  }

  /// Build close button
  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  // ==== HELPER METHODS ====

  void _togglePlayPause(AudioPlayerState state) {
    if (state.isPlaying) {
      context.read<AudioPlayerBloc>().add(const PausePlaybackEvent());
    } else if (state.isPaused) {
      context.read<AudioPlayerBloc>().add(const StartPlaybackEvent());
    } else {
      context.read<AudioPlayerBloc>().add(LoadAudioEvent(filePath: widget.recording.filePath));
    }
  }

  void _skipBackward(AudioPlayerState state) {
    final currentPosition = _getPlaybackPosition(state);
    final newPosition = Duration(
      milliseconds: math.max(0, currentPosition.inMilliseconds - 10000),
    );
    context.read<AudioPlayerBloc>().add(SeekToPositionEvent(position: newPosition));
  }

  void _skipForward(AudioPlayerState state) {
    final currentPosition = _getPlaybackPosition(state);
    final duration = _getPlaybackDuration(state);
    final newPosition = Duration(
      milliseconds: math.min(
        duration.inMilliseconds,
        currentPosition.inMilliseconds + 30000,
      ),
    );
    context.read<AudioPlayerBloc>().add(SeekToPositionEvent(position: newPosition));
  }

  double _getPlaybackProgress(AudioPlayerState state) {
    final position = _getPlaybackPosition(state);
    final duration = _getPlaybackDuration(state);
    if (duration.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  Duration _getPlaybackPosition(AudioPlayerState state) {
    return state.currentPosition;
  }

  Duration _getPlaybackDuration(AudioPlayerState state) {
    final duration = state.totalDuration;
    return duration.inMilliseconds > 0 ? duration : widget.recording.duration;
  }

  double _getAmplitude(AudioPlayerState state) {
    // Since AudioPlayerState doesn't have amplitude, we'll simulate it
    if (state.isPlaying) {
      return 0.3 + (0.4 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000);
    }
    return 0.0;
  }

  IconData _getVolumeIcon(double volume) {
    if (volume == 0) return Icons.volume_off;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Playback speed configuration
class PlaybackSpeed {
  final double value;
  final String description;
  final String emoji;

  const PlaybackSpeed(this.value, this.description, this.emoji);
}

/// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  final double progress;
  final double amplitude;
  final double waveOffset;
  final bool isPlaying;

  const WaveformPainter({
    required this.progress,
    required this.amplitude,
    required this.waveOffset,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final centerY = size.height / 2;
    final progressX = size.width * progress;

    // Draw background waveform
    paint.color = Colors.white.withValues(alpha: 0.3);
    _drawWaveform(canvas, size, centerY, paint, 0.3);

    // Draw progress waveform
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, progressX, size.height));
    paint.color = Colors.cyan;
    _drawWaveform(canvas, size, centerY, paint, isPlaying ? amplitude : 0.3);
    canvas.restore();

    // Draw progress indicator
    paint.color = Colors.cyan;
    paint.strokeWidth = 3;
    canvas.drawLine(
      Offset(progressX, 0),
      Offset(progressX, size.height),
      paint,
    );
  }

  void _drawWaveform(Canvas canvas, Size size, double centerY, Paint paint, double amp) {
    final path = Path();
    final points = (size.width / 4).round();

    for (int i = 0; i < points; i++) {
      final x = (i / points) * size.width;
      final waveValue = math.sin((i / points) * 4 * math.pi + waveOffset);
      final y = centerY + (waveValue * amp * centerY * 0.7);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.waveOffset != waveOffset ||
        oldDelegate.isPlaying != isPlaying;
  }
}