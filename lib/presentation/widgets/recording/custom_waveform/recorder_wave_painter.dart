// File: presentation/widgets/recording/custom_waveform/recorder_wave_painter.dart
import 'package:flutter/material.dart';
import 'label.dart';
import 'waveform_utils.dart';

/// Custom RecorderWavePainter copied from audio_waveforms package.
///
/// This will paint the waveform.
///
/// Additional Information to play around:
///
/// This gives location of first wave from right to left when scrolling:
/// -totalBackDistance.dx + dragOffset.dx + (spacing * i)
///
/// This gives location of first wave from left to right when scrolling:
/// -totalBackDistance.dx + dragOffset.dx
class CustomRecorderWavePainter extends CustomPainter {
  final List<double> waveData;
  final List<int> waveSegments;
  final Color waveColor;
  final bool showMiddleLine;
  final double spacing;
  final double initialPosition;
  final bool showTop;
  final bool showBottom;
  final double bottomPadding;
  final StrokeCap waveCap;
  final Color middleLineColor;
  final double middleLineThickness;
  final Offset totalBackDistance;
  final Offset dragOffset;
  final double waveThickness;
  final VoidCallback pushBack;
  final bool callPushback;
  final bool extendWaveform;
  final bool showDurationLabel;
  final bool showHourInDuration;
  final double updateFrequecy;
  final Paint _wavePaint;
  final Paint _linePaint;
  final Paint _durationLinePaint;
  final TextStyle durationStyle;
  final Color durationLinesColor;
  final double durationTextPadding;
  final double durationLinesHeight;
  final double labelSpacing;
  final Shader? gradient;
  final bool shouldClearLabels;
  final VoidCallback revertClearLabelCall;
  final Function(int) setCurrentPositionDuration;
  final bool shouldCalculateScrolledPosition;
  final double scaleFactor;
  final Duration currentlyRecordedDuration;
  final bool isPaused;
  /// Barre future da erosione progressiva: ancora a 0.3 opacity anche durante recording.
  final int futureBarsCount;

  /// Palette dei segmenti: indice 0 = colore base, 1..N = colori overwrite.
  static const List<Color> _kSegmentPalette = [
    Color(0xFF00BCD4), // 0 — cyan (base)
    Color(0xFFFF6B6B), // 1 — coral
    Color(0xFF81C784), // 2 — verde morbido
    Color(0xFFFFD54F), // 3 — ambra
    Color(0xFFBA68C8), // 4 — viola morbido
    Color(0xFF4FC3F7), // 5 — azzurro chiaro
  ];

  /// Restituisce il colore della barra [i] in base al suo segmento.
  /// Se [waveSegments] è vuoto o [i] è fuori range, usa [waveColor].
  Color _getBarColor(int i) {
    if (waveSegments.isEmpty || i >= waveSegments.length) return waveColor;
    return _kSegmentPalette[waveSegments[i] % _kSegmentPalette.length];
  }

  CustomRecorderWavePainter({
    required this.waveData,
    required this.waveSegments,
    required this.waveColor,
    required this.showMiddleLine,
    required this.spacing,
    required this.initialPosition,
    required this.showTop,
    required this.showBottom,
    required this.bottomPadding,
    required this.waveCap,
    required this.middleLineColor,
    required this.middleLineThickness,
    required this.totalBackDistance,
    required this.dragOffset,
    required this.waveThickness,
    required this.pushBack,
    required this.callPushback,
    required this.extendWaveform,
    required this.updateFrequecy,
    required this.showHourInDuration,
    required this.showDurationLabel,
    required this.durationStyle,
    required this.durationLinesColor,
    required this.durationTextPadding,
    required this.durationLinesHeight,
    required this.labelSpacing,
    required this.gradient,
    required this.shouldClearLabels,
    required this.revertClearLabelCall,
    required this.setCurrentPositionDuration,
    required this.shouldCalculateScrolledPosition,
    required this.scaleFactor,
    required this.currentlyRecordedDuration,
    this.isPaused = false,
    this.futureBarsCount = 0,
  })  : _wavePaint = Paint()
          ..color = waveColor
          ..strokeWidth = waveThickness
          ..strokeCap = waveCap,
        _linePaint = Paint()
          ..color = middleLineColor
          ..strokeWidth = middleLineThickness,
        _durationLinePaint = Paint()
          ..strokeWidth = 3
          ..color = durationLinesColor;
  var _labelPadding = 0.0;

  final List<WaveformLabel> _labels = [];
  static const int durationBuffer = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paintStartTimestamp = DateTime.now().millisecondsSinceEpoch;

    if (shouldClearLabels) {
      _labels.clear();
      pushBack();
      revertClearLabelCall();
    }
    for (var i = 0; i < waveData.length; i++) {
      /// wave gradient
      if (gradient != null) _waveGradient();

      // Il pushback scatta solo per barre registrate (non future):
      // le barre future non devono causare lo scroll del waveform.
      final isRecordedBar = futureBarsCount == 0 || i < waveData.length - futureBarsCount;
      if (isRecordedBar &&
          ((spacing * i) + dragOffset.dx + spacing >
              size.width / (extendWaveform ? 1 : 2) + totalBackDistance.dx) &&
          callPushback) {
        pushBack();
      }

      /// draws waves
      _drawWave(canvas, size, i);

      /// duration labels
      if (showDurationLabel) {
        _addLabel(canvas, i, size);
        _drawTextInRange(canvas, i, size);
      }
    }

    /// middle line
    if (showMiddleLine) _drawMiddleLine(canvas, size);

    /// calculates scrolled position with respect to duration
    if (shouldCalculateScrolledPosition) _setScrolledDuration(size);

    // Log paint duration every 5 points
    if (waveData.length % 5 == 0) {
      final paintEndTimestamp = DateTime.now().millisecondsSinceEpoch;
      final paintDuration = paintEndTimestamp - paintStartTimestamp;
      print('⏱️ [$paintEndTimestamp] CustomPaint.paint COMPLETE: ${waveData.length} points, paintDuration=${paintDuration}ms');
    }
  }

  @override
  bool shouldRepaint(CustomRecorderWavePainter oldDelegate) {
    // Durante la registrazione attiva: ridipingi sempre (waveData cresce in-place,
    // lo stesso oggetto lista viene mutato → il confronto sulla lunghezza non funziona).
    if (!isPaused) return true;
    // In pausa: ridipingi solo se posizione, colore o stato pausa cambiano.
    return oldDelegate.totalBackDistance != totalBackDistance ||
        oldDelegate.dragOffset != dragOffset ||
        oldDelegate.waveColor != waveColor ||
        oldDelegate.isPaused != isPaused ||
        oldDelegate.futureBarsCount != futureBarsCount ||
        oldDelegate.waveSegments.length != waveSegments.length ||
        (waveSegments.isNotEmpty &&
            oldDelegate.waveSegments.isNotEmpty &&
            oldDelegate.waveSegments.last != waveSegments.last);
  }

  void _drawTextInRange(Canvas canvas, int i, Size size) {
    if (_labels.isNotEmpty && i < _labels.length) {
      final label = _labels[i];
      final content = label.content;
      final offset = label.offset;
      final halfWidth = size.width * 0.5;
      final textSpan = TextSpan(
        text: content,
        style: durationStyle,
      );

      // Text painting is performance intensive process so we will only render
      // labels whose position is greater then -halfWidth and triple of
      // halfWidth because it will be in visible viewport and it has extra
      // buffer so that bigger labels can be visible when they are extremely at
      // right or left.
      if (offset.dx > -halfWidth && offset.dx < halfWidth * 3) {
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(minWidth: 0, maxWidth: halfWidth * 2);
        textPainter.paint(canvas, offset);
      }
    }
  }

  void _addLabel(Canvas canvas, int i, Size size) {
    final labelDuration = Duration(seconds: i);
    final durationLineDx = _labelPadding + dragOffset.dx - totalBackDistance.dx;
    final height = size.height;
    final currentDuration =
        Duration(seconds: currentlyRecordedDuration.inSeconds + durationBuffer);
    if (labelDuration < currentDuration) {
      canvas.drawLine(
        Offset(durationLineDx, height),
        Offset(durationLineDx, height + durationLinesHeight),
        _durationLinePaint,
      );
      _labels.add(
        WaveformLabel(
          content: showHourInDuration
              ? labelDuration.toHHMMSS()
              : labelDuration.inSeconds.toMMSS(),
          offset: Offset(
            durationLineDx - durationTextPadding,
            height + labelSpacing,
          ),
        ),
      );
    }
    _labelPadding += spacing * updateFrequecy;
  }

  void _drawMiddleLine(Canvas canvas, Size size) {
    final halfWidth = size.width * 0.5;
    canvas.drawLine(
      Offset(halfWidth, 0),
      Offset(halfWidth, size.height),
      _linePaint,
    );
  }

  void _drawWave(Canvas canvas, Size size, int i) {
    final halfWidth = size.width * 0.5;
    final height = size.height;
    final dx =
        -totalBackDistance.dx + dragOffset.dx + (spacing * i) - initialPosition;
    final scaledWaveHeight = waveData[i] * scaleFactor;
    final upperDy = height - (showTop ? scaledWaveHeight : 0) - bottomPadding;
    final lowerDy =
        height + (showBottom ? scaledWaveHeight : 0) - bottomPadding;

    // To remove unnecessary rendering, we will only draw waves whose position
    // is less then double of half width which is max width and half width from
    // 0 is negative direction have some buffer on left side.
    if (dx > -halfWidth && dx < halfWidth * 2) {
      // Barra futura = ancora da sovrascrivere durante erosione progressiva
      final isFutureBar = futureBarsCount > 0 && i >= waveData.length - futureBarsCount;
      final barColor = _getBarColor(i);
      if (isPaused) {
        final opacity = dx < halfWidth ? 1.0 : 0.3;
        final paint = Paint()
          ..color = barColor.withValues(alpha: opacity)
          ..strokeWidth = waveThickness
          ..strokeCap = waveCap;
        canvas.drawLine(Offset(dx, upperDy), Offset(dx, lowerDy), paint);
      } else if (isFutureBar) {
        final paint = Paint()
          ..color = barColor.withValues(alpha: 0.3)
          ..strokeWidth = waveThickness
          ..strokeCap = waveCap;
        canvas.drawLine(Offset(dx, upperDy), Offset(dx, lowerDy), paint);
      } else {
        final paint = Paint()
          ..color = barColor
          ..strokeWidth = waveThickness
          ..strokeCap = waveCap;
        canvas.drawLine(Offset(dx, upperDy), Offset(dx, lowerDy), paint);
      }
    }
  }

  void _waveGradient() {
    _wavePaint.shader = gradient;
  }

  void _setScrolledDuration(Size size) {
    setCurrentPositionDuration(
        (((-totalBackDistance.dx + dragOffset.dx - (size.width / 2)) /
                    (spacing * updateFrequecy)) *
                1000)
            .abs()
            .toInt());
  }
}
