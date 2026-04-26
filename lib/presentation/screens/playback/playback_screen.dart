// File: lib/presentation/screens/playback/playback_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../domain/entities/recording_entity.dart';
import '../recording/controllers/recording_playback_coordinator.dart';
import 'playback_eye_widget.dart';

const _yellow = Color(0xFFE8D04A);
const _bgColors = [
  Color(0xFF5B1FBF),
  Color(0xFF9B2FC9),
  Color(0xFFD13BA4),
  Color(0xFFF5537A),
];
const _bgStops = [0.0, 0.38, 0.72, 1.0];

// pixel per barra nella waveform scorrevole
const _kBarStep = 4.0;

class PlaybackScreen extends StatefulWidget {
  final RecordingEntity recording;
  const PlaybackScreen({super.key, required this.recording});

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  late final RecordingPlaybackCoordinator _playbackCoordinator;
  late final List<double> _waveData;
  double _speed = 1.0;
  bool _showSpeed = false;

  @override
  void initState() {
    super.initState();
    _playbackCoordinator = GetIt.I<RecordingPlaybackCoordinator>();
    _playbackCoordinator.state.addListener(_onAudioState);
    _waveData = _buildWaveData();
    unawaited(_initializePlayback());
  }

  Future<void> _initializePlayback() async {
    await _playbackCoordinator.initialize();
    await _playbackCoordinator.expandRecording(widget.recording);
  }

  void _onAudioState() {
    if (mounted) setState(() {});
  }

  List<double> _buildWaveData() {
    final raw = widget.recording.waveformData;
    if (raw != null && raw.isNotEmpty) {
      final max = raw.reduce(math.max);
      if (max > 0) return raw.map((v) => (v / max).clamp(0.08, 1.0)).toList();
    }
    return List.generate(96, (i) {
      final t = i / 95;
      final env = math.sin(t * math.pi) * 0.85 + 0.15;
      final mod = 0.55 + 0.45 * math.sin(t * 22 + 1.3) * math.cos(t * 9);
      final noise = 0.75 + math.sin(i * 7.1) * 0.25;
      return (env * mod * noise).clamp(0.08, 1.0);
    });
  }

  double get _progress {
    final dur = _duration;
    if (dur == Duration.zero) return 0;
    return (_position.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
  }

  Duration get _position => _playbackCoordinator.state.value.position;

  Duration get _duration {
    final duration = _playbackCoordinator.state.value.duration;
    return duration == Duration.zero ? widget.recording.duration : duration;
  }

  bool get _isCurrentlyPlaying => _playbackCoordinator.state.value.isPlaying;

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _skip(int seconds) async {
    final newPos = Duration(
      milliseconds: (_position.inMilliseconds + seconds * 1000).clamp(
        0,
        _duration.inMilliseconds,
      ),
    );
    if (_duration == Duration.zero) return;
    await _playbackCoordinator.seekToPercent(
      newPos.inMilliseconds / _duration.inMilliseconds,
    );
  }

  // Scrub delta: trascinare a sinistra = avanzare, a destra = tornare indietro
  void _scrubDelta(double dx) {
    final n = _waveData.length;
    if (n <= 1) return;
    final delta = -dx / _kBarStep / (n - 1);
    final newProgress = (_progress + delta).clamp(0.0, 1.0);
    _playbackCoordinator.seekToPercent(newProgress);
  }

  @override
  void dispose() {
    _playbackCoordinator.state.removeListener(_onAudioState);
    unawaited(_playbackCoordinator.stopPlayback());
    unawaited(_playbackCoordinator.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final durStr = _fmt(widget.recording.duration);
    final curStr = _fmt(_position);
    final title = widget.recording.locationName?.isNotEmpty == true
        ? widget.recording.locationName!
        : widget.recording.name;

    return Scaffold(
      body: Stack(
        children: [
          // sfondo gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _bgColors,
                stops: _bgStops,
              ),
            ),
          ),

          // blob glow top-left
          Positioned(
            left: -180,
            top: -120,
            child: _GlowBlob(
              size: 500,
              color: const Color(0xFFFFB4DC).withValues(alpha: 0.35),
            ),
          ),

          // blob glow bottom-right
          Positioned(
            right: -120,
            bottom: 120,
            child: _GlowBlob(
              size: 400,
              color: const Color(0xFFFF78B4).withValues(alpha: 0.3),
            ),
          ),

          // top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PillButton(
                    onTap: () {},
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _dot(),
                        const SizedBox(width: 5),
                        _dot(),
                        const SizedBox(width: 5),
                        _dot(),
                      ],
                    ),
                  ),
                  _PillButton(
                    color: Colors.transparent,
                    glowColor: Colors.transparent,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.cyan,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // titolo + metadata + timer
          Positioned(
            top: 110,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.cyan,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(timeStr, style: _metaStyle),
                    const SizedBox(width: 14),
                    Text(
                      '•',
                      style: _metaStyle.copyWith(color: Colors.white24),
                    ),
                    const SizedBox(width: 14),
                    Text(durStr, style: _metaStyle),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  curStr,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '← SWIPE TO SCRUB →',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 11,
                    color: Colors.white54,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // play button — icona ciano piccola, senza sfondo
          Positioned(
            top: screenH * 0.46 - 60,
            right: 28,
            child: _GlowIconButton(
              playing: _isCurrentlyPlaying,
              onTap: _playbackCoordinator.togglePlayback,
            ),
          ),

          // waveform scorrevole con playhead fisso al centro
          Positioned(
            top: screenH * 0.46,
            left: 0,
            right: 0,
            height: 180,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => _scrubDelta(d.delta.dx),
              child: CustomPaint(
                painter: _WaveformPainter(
                  waveData: _waveData,
                  progress: _progress,
                ),
              ),
            ),
          ),

          // controlli in basso
          Positioned(
            left: 0,
            right: 0,
            bottom: 42,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PlaybackEyeWidget(
                      dir: EyeDir.back,
                      color: _yellow,
                      playing: _isCurrentlyPlaying,
                      onTap: () => _skip(-15),
                    ),
                    const SizedBox(width: 34),
                    PlaybackEyeWidget(
                      dir: EyeDir.fwd,
                      color: _yellow,
                      playing: _isCurrentlyPlaying,
                      onTap: () => _skip(15),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _BottomPill(
                  speed: _speed,
                  showSpeed: _showSpeed,
                  onSpeedTap: () => setState(() => _showSpeed = !_showSpeed),
                  onSpeedSelect: (s) => setState(() {
                    _speed = s;
                    _showSpeed = false;
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _metaStyle = TextStyle(
  fontSize: 13,
  color: Colors.white70,
  letterSpacing: 0.2,
);

// ── glow blob ────────────────────────────────────────────────────────────────
class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

Widget _dot() => Container(
  width: 5,
  height: 5,
  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
);

// ── pill button top bar ───────────────────────────────────────────────────────
class _PillButton extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? glowColor;
  final VoidCallback onTap;

  const _PillButton({
    required this.child,
    required this.onTap,
    this.color,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color ?? Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: glowColor != null
            ? [BoxShadow(color: glowColor!, blurRadius: 24)]
            : null,
      ),
      child: Center(child: child),
    ),
  );
}

// ── bottone play/pause: icona ciano piccola, nessuno sfondo ──────────────────
class _GlowIconButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;
  const _GlowIconButton({required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              color: Colors.cyan.withValues(alpha: 0.7),
              size: playing ? 30 : 34,
            ),
          ),
          Icon(
            playing ? Icons.pause : Icons.play_arrow,
            color: Colors.cyan,
            size: playing ? 28 : 32,
          ),
        ],
      ),
    ),
  );
}

// ── pill controlli in basso ───────────────────────────────────────────────────
class _BottomPill extends StatelessWidget {
  final double speed;
  final bool showSpeed;
  final VoidCallback onSpeedTap;
  final ValueChanged<double> onSpeedSelect;

  const _BottomPill({
    required this.speed,
    required this.showSpeed,
    required this.onSpeedTap,
    required this.onSpeedSelect,
  });

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.topCenter,
    clipBehavior: Clip.none,
    children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChipButton(
              onTap: onSpeedTap,
              child: Text(
                '${speed}x',
                style: const TextStyle(
                  color: Colors.cyan,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _divider(),
            _ChipButton(
              child: const Icon(
                Icons.content_cut,
                color: Colors.white,
                size: 20,
              ),
            ),
            _ChipButton(
              child: const Icon(
                Icons.label_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            _divider(),
            _ChipButton(child: Icon(Icons.mic, color: _yellow, size: 20)),
          ],
        ),
      ),
      if (showSpeed)
        Positioned(
          bottom: 54,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [0.5, 1.0, 1.5, 2.0].map((s) {
                final active = s == speed;
                return _ChipButton(
                  onTap: () => onSpeedSelect(s),
                  color: active ? Colors.cyan : Colors.transparent,
                  child: Text(
                    '${s}x',
                    style: TextStyle(
                      color: active ? const Color(0xFF1A0B2E) : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
    ],
  );

  Widget _divider() => Container(
    width: 1,
    height: 20,
    color: Colors.white.withValues(alpha: 0.14),
    margin: const EdgeInsets.symmetric(horizontal: 2),
  );
}

class _ChipButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;

  const _ChipButton({required this.child, this.onTap, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color ?? Colors.transparent,
      ),
      child: Center(child: child),
    ),
  );
}

// ── CustomPainter — waveform scorrevole con playhead fisso al centro ──────────
//
// La barra corrente è sempre al centro (cx). Le barre a sinistra = suonate
// (gradiente teal→giallo), quelle a destra = non ancora (bianco 55%).
// Man mano che progress aumenta, la waveform "scorre" verso sinistra.
class _WaveformPainter extends CustomPainter {
  final List<double> waveData;
  final double progress;

  const _WaveformPainter({required this.waveData, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (waveData.isEmpty) return;

    final n = waveData.length;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxH = size.height * 0.78;
    const barW = 2.5;

    // Indice (float) della barra attualmente al centro
    final centerBarF = progress * (n - 1);

    // Quante barre entrano da centro al bordo
    final halfBars = (cx / _kBarStep).ceil() + 2;

    for (int offset = -halfBars; offset <= halfBars; offset++) {
      final barIndexF = centerBarF + offset;
      final x = cx + offset * _kBarStep;

      if (x < -barW || x > size.width + barW) continue;

      if (barIndexF < 0 || barIndexF >= n - 1) continue;

      // Altezza: interpola tra barre adiacenti per scroll fluido
      double h;
      final lo = barIndexF.floor().clamp(0, n - 1);
      final hi = (lo + 1).clamp(0, n - 1);
      final frac = barIndexF - lo;
      h = (waveData[lo] * (1 - frac) + waveData[hi] * frac) * maxH;
      h = h.clamp(4.0, maxH);

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, cy), width: barW, height: h),
        const Radius.circular(2),
      );

      if (offset < 0) {
        // barre suonate: glow + gradiente teal→giallo
        canvas.drawRRect(
          rect,
          Paint()
            ..color = Colors.cyan.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..shader =
                const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.cyan, _yellow],
                ).createShader(
                  Rect.fromCenter(
                    center: Offset(x, cy),
                    width: barW,
                    height: h,
                  ),
                ),
        );
      } else {
        // barre non suonate: bianco 55%
        canvas.drawRRect(
          rect,
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );
      }
    }

    // playhead fisso al centro
    final phGlow = Paint()
      ..color = _yellow.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), phGlow);
    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, size.height),
      Paint()
        ..color = _yellow
        ..strokeWidth = 2,
    );

    // dot top e bottom del playhead
    for (final dy in [0.0, size.height]) {
      canvas.drawCircle(
        Offset(cx, dy),
        6,
        Paint()
          ..color = _yellow.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(Offset(cx, dy), 6, Paint()..color = _yellow);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.waveData != waveData;
}
