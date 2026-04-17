// File: presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart
import 'package:flutter/material.dart';
import 'recorder_wave_painter.dart';

/// Real-time waveform widget driven by amplitude data (0.0–1.0).
///
/// Receives amplitude values from [AudioRecorderService] and renders
/// a scrolling waveform using [CustomRecorderWavePainter].
/// Durante la pausa, supporta il drag orizzontale per scorrere la waveform
/// e notifica l'indice della barra di seek tramite [onSeekBarIndexChanged].
class RecordingWaveform extends StatefulWidget {
  final double
  amplitude; // Current amplitude (0.0-1.0) from AudioRecorderService
  final List<double> waveData; // Waveform data from parent
  final List<int> waveSegments; // Segment index per bar (colori overwrite)
  final Size size;
  final Color waveColor;
  final double spacing;
  final double waveThickness;
  final double scaleFactor;
  final bool showMiddleLine;
  final Color middleLineColor;
  final double middleLineThickness;
  final bool showDurationLabel;
  final Duration currentDuration;
  final Shader? gradient;
  final bool isPaused;
  final bool showPlayhead;
  final Function(int seekBarIndex)? onSeekBarIndexChanged;

  /// Versione del seek: incrementata ogni volta che avviene un seek-and-resume.
  /// Quando cambia, la waveform riposiziona l'ultima barra sul playhead.
  final int seekVersion;

  /// Se true, le barre vengono disegnate al centro verticale del canvas
  /// (bottomPadding = size.height/2). Default false → barre in fondo (comportamento
  /// originale usato dalla fullscreen view con Clip.none).
  final bool centerBars;

  /// Numero di barre future ancora da sovrascrivere (erosione progressiva).
  /// Queste barre restano a 0.3 opacity anche durante la registrazione.
  final int futureBarsCount;

  /// Indice seek bar dal BLoC; quando cambia dall'esterno (es. playback preview)
  /// la waveform riposiziona automaticamente il suo offset.
  final int? externalSeekBarIndex;

  const RecordingWaveform({
    super.key,
    required this.amplitude,
    required this.waveData,
    this.waveSegments = const [],
    required this.size,
    this.waveColor = Colors.cyan,
    this.spacing = 4.0,
    this.waveThickness = 3.5,
    this.scaleFactor = 80.0,
    this.showMiddleLine = false,
    this.middleLineColor = Colors.white,
    this.middleLineThickness = 1.0,
    this.showDurationLabel = false,
    required this.currentDuration,
    this.gradient,
    this.isPaused = false,
    this.showPlayhead = false,
    this.onSeekBarIndexChanged,
    this.seekVersion = 0,
    this.centerBars = false,
    this.futureBarsCount = 0,
    this.externalSeekBarIndex,
  });

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform> {
  Offset _totalBackDistance = Offset.zero;
  final Offset _dragOffset = Offset.zero;
  double _initialPosition = 0.0;

  @override
  void initState() {
    super.initState();
    // Se la widget viene creata con dati già presenti (es. widget ricreata dopo
    // seek-and-resume, o fullscreen aperta mentre era in pausa/registrazione),
    // posiziona subito l'ultima barra sul playhead invece di partire da sinistra.
    if (widget.waveData.isNotEmpty) {
      final halfWidth = widget.size.width / 2;
      final lastIndex = widget.waveData.length - 1;
      _totalBackDistance = Offset(
        (lastIndex * widget.spacing) - halfWidth + (widget.spacing / 2),
        0,
      );
    }
  }

  @override
  void didUpdateWidget(RecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset scroll position when waveData is cleared (new recording)
    if (widget.waveData.isEmpty && oldWidget.waveData.isNotEmpty) {
      setState(() {
        _totalBackDistance = Offset.zero;
        _initialPosition = 0.0;
      });
      return;
    }

    // Seek-and-resume: riposiziona in modo che l'ultima barra sia sul playhead.
    // seekVersion cambia solo una volta per ogni seek → scatta esattamente una volta.
    if (widget.seekVersion != oldWidget.seekVersion &&
        widget.waveData.isNotEmpty) {
      final halfWidth = widget.size.width / 2;
      final lastIndex = widget.waveData.length - 1;
      setState(() {
        _totalBackDistance = Offset(
          (lastIndex * widget.spacing) - halfWidth + (widget.spacing / 2),
          0,
        );
        _initialPosition = 0.0;
      });
      return;
    }

    // Quando si entra in pausa: centra l'ultima barra sul playhead.
    // Aggiungiamo metà del tick (spacing / 2) come piccolo offset per assicurarci
    // che la barra appaia incollata "da sinistra" e non col suo esatto centro
    // sul playhead, così da eliminare l'effetto "spazio vuoto finale".
    if (widget.isPaused && !oldWidget.isPaused && widget.waveData.isNotEmpty) {
      final halfWidth = widget.size.width / 2;
      final lastIndex =
          widget.externalSeekBarIndex ?? (widget.waveData.length - 1);
      setState(() {
        _totalBackDistance = Offset(
          (lastIndex * widget.spacing) - halfWidth + (widget.spacing / 2),
          0,
        );
      });
      debugPrint(
        '🌊 WAVEFORM pause align externalSeekBarIndex=${widget.externalSeekBarIndex} lastIndex=$lastIndex waveDataLength=${widget.waveData.length} spacing=${widget.spacing} totalBackDistance=${_totalBackDistance.dx}',
      );
      return;
    }

    // Erosione progressiva: futureBarsCount cala → una barra futura è stata registrata.
    // Il painter non vede nuove barre (lunghezza fissa) → non chiama pushBack.
    // Avanziamo manualmente lo scroll di un spacing per far scorrere la waveform.
    if (!widget.isPaused &&
        widget.futureBarsCount < oldWidget.futureBarsCount &&
        widget.waveData.isNotEmpty) {
      setState(() {
        _initialPosition = 0.0;
        _totalBackDistance = _totalBackDistance + Offset(widget.spacing, 0.0);
      });
    }

    // Playback preview: riposiziona la waveform quando l'indice cambia dall'esterno
    if (widget.externalSeekBarIndex != null &&
        widget.externalSeekBarIndex != oldWidget.externalSeekBarIndex &&
        widget.externalSeekBarIndex != _currentSeekBarIndex) {
      final halfWidth = widget.size.width / 2;
      final targetDx =
          (widget.externalSeekBarIndex! * widget.spacing) -
          halfWidth +
          (widget.spacing / 2);
      setState(() {
        _totalBackDistance = Offset(targetDx, 0);
      });
      debugPrint(
        '🌊 WAVEFORM external seek sync old=${oldWidget.externalSeekBarIndex} new=${widget.externalSeekBarIndex} current=$_currentSeekBarIndex targetDx=$targetDx',
      );
    }

    // Auto-follow end: durante la registrazione (non in pausa), se la waveform
    // cresce e supera il centro (halfWidth), forziamo _totalBackDistance per
    // tenere l'ultima barra ancorata al playhead. Questo aggira il ritardo del pushBack.
    if (!widget.isPaused &&
        widget.waveData.length > oldWidget.waveData.length) {
      final halfWidth = widget.size.width / 2;
      final currentWaveformWidth = widget.waveData.length * widget.spacing;
      if (currentWaveformWidth > halfWidth) {
        final lastIndex = widget.waveData.length - 1;
        setState(() {
          _totalBackDistance = Offset(
            (lastIndex * widget.spacing) - halfWidth + (widget.spacing / 2),
            0,
          );
          _initialPosition = 0.0;
        });
      }
    }
  }

  int get _currentSeekBarIndex {
    final halfWidth = widget.size.width / 2;
    // Sottraiamo lo shift (spacing/2) dal calcolo inverso
    final index =
        ((_totalBackDistance.dx + halfWidth - (widget.spacing / 2)) /
                widget.spacing)
            .round();
    return index.clamp(
      0,
      widget.waveData.isEmpty ? 0 : widget.waveData.length - 1,
    );
  }

  // ── Listener handlers (non partecipano alla gesture arena) ──────────────
  // Usare Listener invece di GestureDetector garantisce che i drag verticali
  // del parent (compact/expand sheet) non vengano mai bloccati.
  void _onPointerDown(PointerDownEvent event) {
    if (!widget.isPaused) return;
    debugPrint(
      '🌊 WAVEFORM pointerDown x=${event.position.dx.toStringAsFixed(1)} y=${event.position.dy.toStringAsFixed(1)} currentIndex=$_currentSeekBarIndex',
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.isPaused) return;
    final dx = event.delta.dx;
    if (dx == 0) return;

    final halfWidth = widget.size.width / 2;
    // Il limite sinistro per scrollare indietro al massimo (fino a 0)
    final minDx = -halfWidth + (widget.spacing / 2);
    // Il limite destro per scrollare in avanti al massimo (fino a fine wave)
    final maxDx = widget.waveData.isEmpty
        ? 0.0
        : ((widget.waveData.length - 1) * widget.spacing) -
              halfWidth +
              (widget.spacing / 2);

    final newDx = (_totalBackDistance.dx - dx).clamp(minDx, maxDx);
    setState(() {
      _totalBackDistance = Offset(newDx, 0);
    });
    debugPrint(
      '🌊 WAVEFORM pointerMove dx=${dx.toStringAsFixed(2)} newDx=${newDx.toStringAsFixed(2)} currentIndex=$_currentSeekBarIndex',
    );
    widget.onSeekBarIndexChanged?.call(_currentSeekBarIndex);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!widget.isPaused) return;
    debugPrint(
      '🌊 WAVEFORM pointerUp x=${event.position.dx.toStringAsFixed(1)} y=${event.position.dy.toStringAsFixed(1)} currentIndex=$_currentSeekBarIndex',
    );
  }
  // ─────────────────────────────────────────────────────────────────────────

  /// Called when waveform needs to scroll back (same as audio_waveforms library)
  /// IMPORTANT: Does NOT call setState - the parent widget's setState handles repainting
  void _onPushBack() {
    _initialPosition = 0.0;
    _totalBackDistance = _totalBackDistance + Offset(widget.spacing, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final buildTimestamp = DateTime.now().millisecondsSinceEpoch;
    print(
      '⏱️ [$buildTimestamp] RecordingWaveform.build START: waveData.length = ${widget.waveData.length}, amplitude = ${widget.amplitude.toStringAsFixed(3)}',
    );

    const double playheadExtension = 0.0;
    // centerBars=true → barre al centro verticale del canvas (compact view).
    // centerBars=false → barre in fondo (comportamento originale fullscreen).
    final double bottomPadding = widget.centerBars ? widget.size.height / 2 : 0;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: widget.size.width,
            height: widget.size.height,
            color: Colors.transparent,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: CustomRecorderWavePainter(
                  waveData: widget.waveData.isEmpty ? [0.0] : widget.waveData,
                  waveSegments: widget.waveSegments,
                  waveColor: widget.waveColor,
                  showMiddleLine: widget.showMiddleLine,
                  spacing: widget.spacing,
                  initialPosition: _initialPosition,
                  showTop: true,
                  showBottom: true,
                  bottomPadding: bottomPadding,
                  waveCap: StrokeCap.round,
                  middleLineColor: widget.middleLineColor,
                  middleLineThickness: widget.middleLineThickness,
                  totalBackDistance: _totalBackDistance,
                  dragOffset: _dragOffset,
                  waveThickness: widget.waveThickness,
                  pushBack: _onPushBack,
                  callPushback: !widget.isPaused,
                  extendWaveform: false,
                  updateFrequecy: 10.0,
                  showHourInDuration: false,
                  showDurationLabel: widget.showDurationLabel,
                  durationStyle: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  durationLinesColor: Colors.white30,
                  durationTextPadding: 10,
                  durationLinesHeight: 8,
                  labelSpacing: 12,
                  gradient: widget.gradient,
                  shouldClearLabels: false,
                  revertClearLabelCall: () {},
                  setCurrentPositionDuration: (int ms) {},
                  shouldCalculateScrolledPosition: false,
                  scaleFactor: widget.scaleFactor,
                  currentlyRecordedDuration: widget.currentDuration,
                  isPaused: widget.isPaused,
                  futureBarsCount: widget.futureBarsCount,
                ),
              ),
            ),
          ),
          // Linea playhead: visibile solo in fullscreen (showPlayhead: true)
          if (widget.showPlayhead)
            Positioned(
              left: widget.size.width / 2 - 1,
              top: 0,
              child: Container(
                width: 2,
                height: widget.size.height + playheadExtension,
                color: const Color(0xFFFFC107),
              ),
            ),
        ],
      ),
    );
  }
}
