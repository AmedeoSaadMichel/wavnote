import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../domain/entities/recording_session_segment.dart';
import '../../../../services/audio/segment_playback_controller.dart';
import '../custom_waveform/recorder_wave_painter.dart';

/// Four readable cards per page, with a radial transition between pages.
class RecordingSegmentOrbit extends StatefulWidget {
  final List<RecordingSessionSegment> segments;
  final ValueListenable<Map<String, SegmentPlaybackState>>? playback;
  final Future<void> Function(RecordingSessionSegment) onPlay;
  final Future<void> Function(RecordingSessionSegment) onSave;
  final VoidCallback onClose;

  const RecordingSegmentOrbit({
    super.key,
    required this.segments,
    required this.onPlay,
    required this.onSave,
    required this.onClose,
    this.playback,
  });

  @override
  State<RecordingSegmentOrbit> createState() => _RecordingSegmentOrbitState();
}

class _RecordingSegmentOrbitState extends State<RecordingSegmentOrbit> {
  int _page = 0;
  double _dragDistance = 0;
  String? _busyId;
  final Set<String> _savedIds = {};
  int get _pages => (widget.segments.length / 4).ceil();

  void _turn(int delta) {
    if (_busyId != null) return;
    final next = (_page + delta).clamp(0, _pages - 1);
    if (next != _page) setState(() => _page = next);
  }

  Future<void> _act(
    RecordingSessionSegment segment, {
    required bool save,
  }) async {
    if (_busyId != null) return;
    setState(() => _busyId = segment.recording.id);
    try {
      await (save ? widget.onSave(segment) : widget.onPlay(segment));
      if (mounted && save) {
        setState(() => _savedIds.add(segment.recording.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Segmento salvato nella libreria')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              save
                  ? 'Impossibile salvare il segmento. Riprova.'
                  : 'Impossibile riprodurre il segmento. Riprova.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listenable = widget.playback;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onClose();
      },
      child: Material(
        color: const Color(0xFF1A0A2E).withValues(alpha: .72),
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: true,
          label: 'Segmenti della registrazione',
          child: listenable == null
              ? _buildOrbit(null)
              : ValueListenableBuilder<Map<String, SegmentPlaybackState>>(
                  valueListenable: listenable,
                  builder: (_, playback, _) => _buildOrbit(playback),
                ),
        ),
      ),
    );
  }

  Widget _buildOrbit(
    Map<String, SegmentPlaybackState>? playback,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final first = _page * 4;
      final end = math.min(first + 4, widget.segments.length);
      final width = math.min(constraints.maxWidth - 24, 500.0);
      final height = math.max(
        330.0,
        math.min(constraints.maxHeight - 100, 470.0),
      );
      final cardWidth = (width - 32) / 2;
      final cardHeight = math.min(154.0, (height - 90) / 2);
      return SingleChildScrollView(
        child: SizedBox(
          height: math.max(430.0, constraints.maxHeight),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _dragDistance = 0,
            onHorizontalDragUpdate: (details) =>
                _dragDistance += details.delta.dx,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (_dragDistance.abs() > 30 || velocity.abs() > 100) {
                _turn(
                  (_dragDistance.abs() > 30 ? _dragDistance : velocity) < 0
                      ? 1
                      : -1,
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IgnorePointer(
                          child: SizedBox(
                            width: width * .8,
                            height: height * .8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.cyan.withValues(alpha: .35),
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: RotationTransition(
                                  turns: Tween<double>(
                                    begin: .035,
                                    end: 0,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: SizedBox(
                            key: ValueKey(_page),
                            width: width,
                            height: height,
                            child: Stack(
                              children: [
                                for (var i = first; i < end; i++)
                                  Positioned(
                                    left: (i - first).isEven ? 0 : null,
                                    right: (i - first).isOdd ? 0 : null,
                                    top: i - first < 2 ? 0 : null,
                                    bottom: i - first >= 2 ? 0 : null,
                                    width: cardWidth,
                                    height: cardHeight,
                                    child: _card(
                                      widget.segments[i],
                                      i,
                                      playback,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          height: 90,
                          child: Material(
                            color: const Color(0xFF2E1065),
                            shape: const CircleBorder(
                              side: BorderSide(color: Colors.cyan),
                            ),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: widget.onClose,
                              child: Tooltip(
                                message: 'Chiudi segmenti',
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.layers_outlined,
                                      color: Colors.cyan,
                                      size: 22,
                                    ),
                                    Text(
                                      '${widget.segments.length} segmenti',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Segmenti precedenti',
                        onPressed: _page > 0 ? () => _turn(-1) : null,
                        icon: const Icon(Icons.chevron_left),
                        color: Colors.cyan,
                        disabledColor: Colors.white24,
                      ),
                      Text(
                        '${first + 1}–$end di ${widget.segments.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Segmenti successivi',
                        onPressed: _page + 1 < _pages ? () => _turn(1) : null,
                        icon: const Icon(Icons.chevron_right),
                        color: Colors.cyan,
                        disabledColor: Colors.white24,
                      ),
                    ],
                  ),
                  if (_pages > 1)
                    const Text(
                      'Scorri per gli altri segmenti',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _card(
    RecordingSessionSegment segment,
    int index,
    Map<String, SegmentPlaybackState>? playback,
  ) {
    final recording = segment.recording;
    final color = CustomRecorderWavePainter.segmentColor(segment.colorIndex);
    final playing = playback?[recording.id]?.isPlaying ?? false;
    final busy = _busyId == recording.id;
    final saved = _savedIds.contains(recording.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E).withValues(alpha: .9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: playing ? color : Colors.white24,
          width: playing ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Segmento ${index + 1}',
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: CustomPaint(
                painter: SegmentWaveformPainter(
                  samples: recording.waveformData ?? const [],
                  color: color,
                  position: playback?[recording.id]?.position ?? Duration.zero,
                ),
              ),
            ),
          ),
          Text(
            recording.durationFormatted,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: playing
                    ? 'Ferma segmento ${index + 1}'
                    : 'Ascolta segmento ${index + 1}',
                onPressed: _busyId == null
                    ? () => _act(segment, save: false)
                    : null,
                icon: Icon(
                  playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                color: const Color(0xFFFFC107),
                disabledColor: Colors.white24,
              ),
              IconButton(
                tooltip: saved
                    ? 'Segmento salvato'
                    : 'Salva segmento ${index + 1}',
                onPressed: _busyId == null && !saved
                    ? () => _act(segment, save: true)
                    : null,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.cyan,
                        ),
                      )
                    : Icon(saved ? Icons.check : Icons.save_alt),
                color: const Color(0xFFFFC107),
                disabledColor: saved ? Colors.cyan : Colors.white24,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SegmentWaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;
  final Duration position;
  const SegmentWaveformPainter({
    required this.samples,
    required this.color,
    this.position = Duration.zero,
  });

  /// Native snapshots use the recorder's same 100 ms buckets.
  double get playheadSample => position.inMicroseconds / 100000;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    const spacing = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final current = playheadSample.clamp(0.0, samples.length.toDouble());
    final center = size.width / 2;
    final first = math.max(0, (current - center / spacing).floor());
    final last = math.min(
      samples.length,
      (current + center / spacing).ceil() + 1,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = first; i < last; i++) {
      final half = math.max(
        1.0,
        samples[i].abs().clamp(0, 1) * size.height * .43,
      );
      final x = center + (i - current) * spacing;
      canvas.drawLine(
        Offset(x, size.height / 2 - half),
        Offset(x, size.height / 2 + half),
        paint,
      );
    }
    canvas.drawLine(
      Offset(center, 0),
      Offset(center, size.height),
      Paint()
        ..color = const Color(0xFFFFC107)
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SegmentWaveformPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.position != position ||
      !listEquals(oldDelegate.samples, samples);
}
