// File: presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
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
  final List<int> waveSegments;
  final VoidCallback onToggle;
  final VoidCallback? onPause;
  final VoidCallback? onDone;
  final VoidCallback? onChat;

  /// Riprende la registrazione (bottone pupilla quando in pausa).
  final void Function({
    required int seekBarIndex,
    required List<double> waveData,
  })?
  onResume;

  /// Avvia/ferma il playback di anteprima dal playhead (bottone play nei controlli).
  final VoidCallback? onPlay;
  final bool isPlayingPreview;
  final Function(int seekBarIndex)? onSeekBarIndexChanged;
  final int seekBarIndex;
  final int seekVersion;
  final int futureBarsCount;
  final Animation<double> pulseAnimation;

  /// seekBarIndex dal BLoC — durante il playback preview fa scorrere la waveform.
  final int? blocSeekBarIndex;
  final int sessionCounter;

  const RecordingFullscreenView({
    super.key,
    required this.title,
    required this.elapsed,
    required this.isRecording,
    this.isPaused = false,
    required this.amplitude,
    required this.waveData,
    this.waveSegments = const [],
    required this.onToggle,
    required this.pulseAnimation,
    this.onPause,
    this.onDone,
    this.onChat,
    this.onResume,
    this.onPlay,
    this.isPlayingPreview = false,
    this.onSeekBarIndexChanged,
    this.seekBarIndex = 0,
    this.seekVersion = 0,
    this.futureBarsCount = 0,
    this.blocSeekBarIndex,
    this.sessionCounter = 0,
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

  /// Counter posizione: "← MM:SS / MM:SS →"
  /// Durante registrazione: posizione = durata totale (sempre all'ultimo punto).
  /// Durante pausa: posizione = barra di seek corrente.
  ///
  /// La durata totale usa il massimo tra waveData e widget.elapsed:
  /// dopo la fine naturale del playback, _onStopRecordingPreview aggiorna
  /// RecordingPaused.duration con la durata reale del file di preview assemblato,
  /// che viene passata come widget.elapsed. In quel momento elapsed > waveData
  /// e viene mostrata la durata corretta dell'audio completo.
  String _seekLabel(int barIndex) {
    final waveMs = widget.waveData.length * 100;
    final elapsedMs = widget.elapsed.inMilliseconds;
    // Usa il massimo tra la durata calcolata dalla waveform e quella dal BLoC.
    // Dopo la fine naturale del playback, elapsed contiene la durata del file
    // di preview completo (es. 14.9s) che supera waveData.length*100 (es. 9s).
    final totalMs = elapsedMs > waveMs ? elapsedMs : waveMs;
    final seekMs = widget.isRecording
        ? elapsedMs
        : ((barIndex + 1) * 100).clamp(0, totalMs);
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
          Positioned(top: 12, right: 16, child: _buildChatButton()),
        // Done — sempre visibile
        Positioned(bottom: 40, right: 20, child: _buildDoneButton()),
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
                key: ValueKey(widget.sessionCounter),
                amplitude: widget.amplitude,
                waveData: widget.waveData,
                waveSegments: widget.waveSegments,
                size: Size(constraints.maxWidth, constraints.maxHeight),
                waveColor: Colors.cyan,
                spacing: 2.0,
                waveThickness: 2.5,
                scaleFactor: constraints.maxHeight * 0.50,
                currentDuration: widget.elapsed,
                isPaused: widget.isPaused,
                showPlayhead: true,
                centerBars: true,
                futureBarsCount: widget.futureBarsCount,
                onSeekBarIndexChanged: widget.onSeekBarIndexChanged,
                seekVersion: widget.seekVersion,
                externalSeekBarIndex:
                    (widget.isPlayingPreview || widget.isPaused)
                    ? (widget.waveData.isNotEmpty
                          ? widget.seekBarIndex.clamp(
                              0,
                              widget.waveData.length - 1,
                            )
                          : widget.seekBarIndex)
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return FullscreenPlaybackControls(
      onPlay: widget.onPlay,
      isPlayingPreview: widget.isPlayingPreview,
    );
  }

  Widget _buildActionButton() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = (constraints.maxHeight * 0.45).clamp(70.0, 120.0);
          return RecordPupilButton(
            isRecording: widget.isRecording,
            size: size,
            pulseAnimation: widget.pulseAnimation,
            // In pausa: ▶ per riprendere la registrazione
            overlayIcon: widget.isPaused ? Icons.play_arrow : null,
            onTap: () {
              if (widget.isRecording) {
                widget.onPause?.call();
              } else if (widget.isPaused) {
                // Il pupil button riprende la registrazione (non il preview)
                widget.onResume?.call(
                  seekBarIndex: widget.seekBarIndex,
                  waveData: widget.waveData,
                );
              } else {
                widget.onToggle();
              }
            },
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
