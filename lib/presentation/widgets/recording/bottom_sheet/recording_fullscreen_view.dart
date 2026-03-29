// File: presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/extensions/duration_extensions.dart';
import 'control_buttons.dart';
import '../custom_waveform/flutter_sound_waveform.dart';

/// Vista fullscreen del bottom sheet di registrazione.
///
/// Layout:
/// - Handle
/// - Titolo
/// - Subtitle: orario HH:mm + elapsed (sempre visibile, orologio aggiornato ogni 30s)
/// - Waveform con playhead
/// - Seek label "← pos / tot →" (sempre visibile, aggiornata dal BLoC)
/// - Controlli rewind/forward (SOLO in pausa)
/// - Pulsante principale (pausa/play/rec)
/// - Bottone Done (sempre visibile)
/// - Bottone chat (sempre visibile in alto a destra)
class RecordingFullscreenView extends StatefulWidget {
  final String? title;
  final Duration elapsed;
  final bool isRecording;
  final bool isPaused;
  final double amplitude;
  final List<double> waveData;
  final VoidCallback onToggle;
  final VoidCallback? onPause;
  final VoidCallback? onDone;
  final VoidCallback? onChat;
  final VoidCallback? onPlay;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final Function(int seekBarIndex)? onSeekBarIndexChanged;
  final int seekBarIndex;
  final int seekVersion;
  final int futureBarsCount;

  const RecordingFullscreenView({
    super.key,
    required this.title,
    required this.elapsed,
    required this.isRecording,
    this.isPaused = false,
    required this.amplitude,
    required this.waveData,
    required this.onToggle,
    this.onPause,
    this.onDone,
    this.onChat,
    this.onPlay,
    this.onRewind,
    this.onForward,
    this.onSeekBarIndexChanged,
    this.seekBarIndex = 0,
    this.seekVersion = 0,
    this.futureBarsCount = 0,
  });

  @override
  State<RecordingFullscreenView> createState() =>
      _RecordingFullscreenViewState();
}

class _RecordingFullscreenViewState extends State<RecordingFullscreenView> {
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Aggiorna ogni 30 secondi — mostriamo solo HH:mm
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String get _formattedTime => widget.elapsed.formatted;

  /// Counter posizione: "← MM:SS / MM:SS →"
  /// Durante registrazione: posizione = durata totale (sempre all'ultimo punto).
  /// Durante pausa: posizione = barra di seek corrente.
  String _seekLabel(int barIndex) {
    final seekMs = barIndex * 100;
    final totalMs = widget.waveData.length * 100;
    String fmt(int ms) {
      final d = Duration(milliseconds: ms);
      final m = d.inMinutes.toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    return '← ${fmt(seekMs)} / ${fmt(totalMs)} →';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(flex: 2, child: _buildHandle()),
            Flexible(flex: 2, child: _buildTitle()),
            Flexible(flex: 1, child: _buildSubtitle()),
            Flexible(flex: 8, child: _buildWaveform(context)),
            // Seek label sempre visibile — aggiornata dal BLoC ogni secondo
            Flexible(flex: 2, child: _buildSeekLabel()),
            // Controlli rewind/forward SOLO in pausa — con transizione
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: widget.isPaused
                  ? SizedBox(
                      key: const ValueKey('controls'),
                      height: 80,
                      child: _buildPlaybackControls(),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
            Flexible(flex: 4, child: _buildActionButton()),
          ],
        ),
        // Bottone chat (trascrizione) — sempre visibile in alto a destra
        if (widget.onChat != null)
          Positioned(
            top: 12,
            right: 16,
            child: _buildChatButton(),
          ),
        // Done — sempre visibile
        Positioned(
          bottom: 40,
          right: 20,
          child: _buildDoneButton(),
        ),
      ],
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 50,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        widget.title ?? 'New Recording',
        style: const TextStyle(
          color: Colors.cyan,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Orario corrente (HH:mm) + elapsed formattato — sempre visibile.
  Widget _buildSubtitle() {
    final timeString =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    return Text(
      timeString,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Seek label sotto la waveform — sempre visibile.
  /// Durante registrazione mostra "← elapsed / elapsed →".
  /// Durante pausa mostra la posizione di seek "← pos / tot →".
  Widget _buildSeekLabel() {
    return Center(
      child: Text(
        _seekLabel(widget.seekBarIndex),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildWaveform(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(
        heightFactor: 1.0,
        widthFactor: 1.0,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return RecordingWaveform(
                amplitude: widget.amplitude,
                waveData: widget.waveData,
                size: Size(constraints.maxWidth, constraints.maxHeight),
                waveColor: Colors.cyan,
                spacing: 2.0,
                waveThickness: 2.5,
                scaleFactor: 80.0,
                currentDuration: widget.elapsed,
                isPaused: widget.isPaused,
                showPlayhead: true,
                centerBars: true,
                futureBarsCount: widget.futureBarsCount,
                onSeekBarIndexChanged: widget.onSeekBarIndexChanged,
                seekVersion: widget.seekVersion,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return FullscreenPlaybackControls(
      onRewind: widget.onRewind,
      onPlay: widget.onPlay,
      onForward: widget.onForward,
    );
  }

  Widget _buildActionButton() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = (constraints.maxHeight * 0.45).clamp(70.0, 120.0);
          return GestureDetector(
            onTap: () {
              if (widget.isRecording) {
                widget.onPause?.call();
              } else if (widget.isPaused) {
                widget.onPlay?.call();
              } else {
                widget.onToggle();
              }
            },
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.isRecording
                    ? const LinearGradient(
                        colors: [
                          Color(0xFFDC143C),
                          Color(0xFFB22222),
                          Color(0xFF8B0000),
                        ],
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFFFFA500),
                          Color(0xFFFFC107),
                        ],
                      ),
                border: Border.all(
                  color: widget.isRecording
                      ? const Color(0xFFFF6B6B).withValues(alpha: 0.8)
                      : Colors.cyan,
                  width: widget.isRecording ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isRecording
                        ? const Color(0xFFDC143C).withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: widget.isRecording ? 16 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: widget.isRecording
                      ? Icon(
                          Icons.pause,
                          key: const ValueKey('pause'),
                          color: Colors.white,
                          size: size * 0.4,
                        )
                      : widget.isPaused
                          ? Icon(
                              Icons.play_arrow,
                              key: const ValueKey('play'),
                              color: Colors.white,
                              size: size * 0.45,
                            )
                          : Icon(
                              Icons.fiber_manual_record,
                              key: const ValueKey('rec'),
                              color: Colors.white,
                              size: size * 0.4,
                            ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatButton() {
    return GestureDetector(
      onTap: widget.onChat,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.chat_bubble_outline,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildDoneButton() {
    return GestureDetector(
      onTap: widget.onDone,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Done',
          style: TextStyle(
            color: Colors.cyan,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
