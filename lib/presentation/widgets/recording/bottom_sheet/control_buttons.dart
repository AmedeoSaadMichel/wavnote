// File: presentation/widgets/recording/bottom_sheet/control_buttons.dart
import 'package:flutter/material.dart';

/// Bottone record con pupilla che si dilata durante la registrazione.
/// Identico in compact e fullscreen. L'icona overlay è opzionale
/// (usata solo in fullscreen quando in pausa per mostrare ▶).
class RecordPupilButton extends StatelessWidget {
  final bool isRecording;
  final double size;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;
  final IconData? overlayIcon;

  const RecordPupilButton({
    super.key,
    required this.isRecording,
    required this.size,
    required this.pulseAnimation,
    required this.onTap,
    this.overlayIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, _) {
          return Transform.scale(
            scale: pulseAnimation.value,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFA500), Color(0xFFFFC107)],
                ),
                border: Border.all(color: Colors.cyan, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      width: isRecording ? size * 0.65 : size * 0.28,
                      height: isRecording ? size * 0.65 : size * 0.28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1A0A2E),
                      ),
                    ),
                    if (overlayIcon != null)
                      Icon(
                        overlayIcon,
                        color: const Color(0xFF2E1065),
                        size: size * 0.35,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Controlli rewind/forward per la vista fullscreen in pausa.
///
/// Il bottone play è rimosso: è gestito dal pulsante principale circolare
/// in RecordingFullscreenView (_buildActionButton).
/// FullscreenActionButton e EyePausePainter rimossi: mai usati.
class FullscreenPlaybackControls extends StatelessWidget {
  final VoidCallback? onRewind;
  final VoidCallback? onPlay;
  final VoidCallback? onForward;
  /// Se true, il bottone centrale mostra ⏹ stop invece di ▶ play.
  final bool isPlayingPreview;

  const FullscreenPlaybackControls({
    super.key,
    this.onRewind,
    this.onPlay,
    this.onForward,
    this.isPlayingPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          flex: 2,
          child: _buildControlButton(
            icon: Icons.replay_10,
            onPressed: onRewind ?? () {},
            title: 'Rewind',
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          flex: 3,
          child: _buildControlButton(
            icon: isPlayingPreview ? Icons.stop : Icons.play_arrow,
            onPressed: onPlay ?? () {},
            title: isPlayingPreview ? 'Stop' : 'Play',
            isLarge: true,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          flex: 2,
          child: _buildControlButton(
            icon: Icons.forward_10,
            onPressed: onForward ?? () {},
            title: 'Forward',
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? title,
    bool isLarge = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final base = (constraints.maxHeight * 0.5).clamp(50.0, 80.0);
        final buttonSize = isLarge ? base : base * 0.75;
        final iconSize = buttonSize * (isLarge ? 0.5 : 0.45);

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFA500),
                      Color(0xFFFFC107),
                    ],
                  ),
                  border: Border.all(color: Colors.cyan, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: onPressed,
                  icon: Icon(
                    icon,
                    color: const Color(0xFF2E1065),
                    size: iconSize,
                  ),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
