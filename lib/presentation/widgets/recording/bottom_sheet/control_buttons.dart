// File: presentation/widgets/recording/bottom_sheet/control_buttons.dart
import 'package:flutter/material.dart';

/// Controlli rewind/forward per la vista fullscreen in pausa.
///
/// Il bottone play è rimosso: è gestito dal pulsante principale circolare
/// in RecordingFullscreenView (_buildActionButton).
/// FullscreenActionButton e EyePausePainter rimossi: mai usati.
class FullscreenPlaybackControls extends StatelessWidget {
  final VoidCallback? onRewind;
  final VoidCallback? onForward;

  const FullscreenPlaybackControls({
    super.key,
    this.onRewind,
    this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: _buildControlButton(
            icon: Icons.replay_10,
            onPressed: onRewind ?? () {},
            title: 'Rewind',
          ),
        ),
        const SizedBox(width: 60),
        Flexible(
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
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonSize = (constraints.maxHeight * 0.5).clamp(50.0, 80.0);
        final iconSize = buttonSize * 0.45;

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
