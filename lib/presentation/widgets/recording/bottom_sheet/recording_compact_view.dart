// File: presentation/widgets/recording/bottom_sheet/recording_compact_view.dart
import 'package:flutter/material.dart';
import '../../../../core/extensions/duration_extensions.dart';
import '../custom_waveform/flutter_sound_waveform.dart';

/// Vista compatta del bottom sheet di registrazione.
///
/// Layout (dall'alto verso il basso):
///   handle bar          — fissa
///   [Expanded]          — vuoto se non in registrazione, contenuto altrimenti
///   bottone record      — fisso 110px
class RecordingCompactView extends StatelessWidget {
  final String? title;
  final Duration elapsed;
  final bool isRecording;
  final double amplitude;
  final List<double> waveData;
  final Animation<double> pulseAnimation;
  final VoidCallback onToggle;

  const RecordingCompactView({
    super.key,
    required this.title,
    required this.elapsed,
    required this.isRecording,
    required this.amplitude,
    required this.waveData,
    required this.pulseAnimation,
    required this.onToggle,
  });

  String get _formattedTime => elapsed.formatted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      // stretch → tutti i figli ricevono larghezza tight = larghezza colonna
      // (evita vincoli loose che rompono Expanded/LayoutBuilder annidati)
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Handle bar ──────────────────────────────────────────────
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Area centrale ────────────────────────────────────────────
        // LayoutBuilder con soglia minima: evita il RenderFlex overflow
        // durante i ~300ms in cui AnimatedContainer anima da height=180
        // a minHeight. In quel lasso isRecording è già true ma lo spazio
        // disponibile è ancora < 80px → mostriamo SizedBox.shrink() finché
        // non c'è abbastanza spazio per il contenuto.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (!isRecording || constraints.maxHeight < 80) {
                return const SizedBox.shrink();
              }
              return _buildRecordingContent();
            },
          ),
        ),

        // ── Bottone record ───────────────────────────────────────────
        SizedBox(
          height: 110,
          child: Center(child: _buildRecordButton()),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Titolo + timer + waveform.
  ///
  /// Riceve vincoli tight (W × H) dall'Expanded esterno.
  /// La waveform riempie tutto lo spazio rimanente tramite
  /// Expanded → Padding → LayoutBuilder, senza intermediari che
  /// rilassino i vincoli.
  Widget _buildRecordingContent() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),

        // Titolo
        if (title != null)
          Text(
            title!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),

        const SizedBox(height: 4),

        // Timer
        Text(
          _formattedTime,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // Waveform: riempie tutto lo spazio rimanente.
        // LayoutBuilder figlio diretto di Expanded → maxWidth e maxHeight
        // sono i valori reali disponibili → Size passata a RecordingWaveform
        // corrisponde esattamente allo spazio occupato.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return RecordingWaveform(
                  amplitude: amplitude,
                  waveData: waveData,
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  waveColor: Colors.cyan,
                  spacing: 1.5,
                  waveThickness: 2.5,
                  scaleFactor: constraints.maxHeight * 0.40,
                  currentDuration: elapsed,
                  centerBars: true,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Bottone record con animazione pulse.
  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: pulseAnimation.value,
            child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isRecording
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
                color: isRecording
                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.8)
                    : Colors.cyan,
                width: isRecording ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isRecording
                      ? const Color(0xFFDC143C).withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.2),
                  blurRadius: isRecording ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isRecording
                    ? const Icon(
                        Icons.stop,
                        key: ValueKey('stop'),
                        color: Colors.white,
                        size: 32,
                      )
                    : const Icon(
                        Icons.fiber_manual_record,
                        key: ValueKey('rec'),
                        color: Color(0xFF2E1065),
                        size: 30,
                      ),
              ),
            ),
          ),
        );
        },
      ),
    );
  }
}
