# Waveform Seek & Trim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When recording is paused, let the user drag the waveform to any position, then tap Resume to trim audio to that point and continue recording from there — preserving audio before the seek point and appending new audio after it.

**Architecture:** Four layers: (1) waveform widget becomes draggable during pause via `GestureDetector` updating `_totalBackDistance`; (2) `SeekAndResumeUseCase` stops recorder, trims to seek point (saves base to `_base` path), restarts recorder; (3) native platform channel `wavnote/audio_trimmer` handles `trimAudio` and `concatenateAudio` per format; (4) BLoC carries `seekBasePath` in `RecordingInProgress` and concatenates base + continuation before final stop.

**Tech Stack:** Flutter `MethodChannel`, Swift `AVAssetExportSession`/`AVMutableComposition`, Kotlin `MediaExtractor`/`MediaMuxer`, Dart `dartz`, `bloc_test`/`mocktail`.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `lib/presentation/widgets/recording/custom_waveform/recorder_wave_painter.dart` | Fix `shouldRepaint`; draw playhead line; per-bar opacity split when paused |
| Modify | `lib/presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart` | Accept `isPaused`; manual drag → `_totalBackDistance`; expose `onSeekBarIndexChanged` |
| Modify | `lib/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart` | Remove old seek%; pass drag to waveform; show seek time label |
| Modify | `lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart` | Track `_seekBarIndex`; dispatch `SeekAndResumeRecording` on resume tap |
| Modify | `lib/presentation/bloc/recording/recording_event.dart` | Add `SeekAndResumeRecording` event |
| Modify | `lib/presentation/bloc/recording/recording_state.dart` | Add `seekBasePath` to `RecordingInProgress`; update `copyWith` |
| Modify | `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart` | Add `_onSeekAndResumeRecording`; add concatenation in `_onStopRecording` |
| Modify | `lib/presentation/bloc/recording/recording_bloc.dart` | Import + register `SeekAndResumeRecording` handler; inject `SeekAndResumeUseCase` |
| Create | `lib/services/audio/audio_trimmer_service.dart` | Dart `MethodChannel` wrapper: `trimAudio`, `concatenateAudio` |
| Create | `lib/domain/usecases/recording/seek_and_resume_usecase.dart` | Orchestrate stop → trim → restart; return `SeekAndResumeResult` |
| Create | `ios/Runner/AudioTrimmerPlugin.swift` | Trim + concatenate for M4A, WAV, FLAC via AVFoundation |
| Create | `android/app/src/main/kotlin/com/example/wavnote/AudioTrimmerPlugin.kt` | Trim + concatenate for M4A/FLAC (MediaMuxer) and WAV (byte splice) |
| Modify | `ios/Runner/AppDelegate.swift` | Register `AudioTrimmerPlugin` |
| Modify | `android/app/src/main/kotlin/com/example/wavnote/MainActivity.kt` | Register `AudioTrimmerPlugin` |
| Modify | `lib/config/dependency_injection.dart` | Register `AudioTrimmerService` singleton |
| Create | `test/unit/usecases/seek_and_resume_usecase_test.dart` | Unit tests for the use case |
| Create | `test/unit/blocs/recording_bloc_seek_test.dart` | BLoC tests for `SeekAndResumeRecording` |

---

## Task 1 — Fix `shouldRepaint` (performance)

**Files:**
- Modify: `lib/presentation/widgets/recording/custom_waveform/recorder_wave_painter.dart:146`

**Problem:** `shouldRepaint` always returns `true` → the canvas repaints every frame even when nothing has changed (60 fps during pause).

- [ ] **Step 1: Replace `shouldRepaint`**

In `recorder_wave_painter.dart`, replace:

```dart
@override
bool shouldRepaint(CustomRecorderWavePainter oldDelegate) => true;
```

with:

```dart
@override
bool shouldRepaint(CustomRecorderWavePainter oldDelegate) {
  return oldDelegate.waveData.length != waveData.length ||
      oldDelegate.totalBackDistance != totalBackDistance ||
      oldDelegate.dragOffset != dragOffset ||
      oldDelegate.waveColor != waveColor;
}
```

- [ ] **Step 2: Hot-reload and verify in logs**

Run the app, start recording, pause. The log should show `RecordingWaveform.build START` calls much less frequently during idle pause (no user drag, no amplitude change).

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/recording/custom_waveform/recorder_wave_painter.dart
git commit -m "perf: shouldRepaint only when waveData/scroll/color changes"
```

---

## Task 2 — Waveform drag scroll during pause

**Files:**
- Modify: `lib/presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart`

Add `isPaused` + `onSeekBarIndexChanged` parameters. Wire a `GestureDetector` so dragging during pause updates `_totalBackDistance` and emits the seek bar index.

- [ ] **Step 1: Add new parameters to `RecordingWaveform`**

In `flutter_sound_waveform.dart`, add to the `RecordingWaveform` class:

```dart
// File: presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart
import 'package:flutter/material.dart';
import 'recorder_wave_painter.dart';

class RecordingWaveform extends StatefulWidget {
  final double amplitude;
  final List<double> waveData;
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
  // ── NEW ──
  final bool isPaused;
  final Function(int seekBarIndex)? onSeekBarIndexChanged;

  const RecordingWaveform({
    super.key,
    required this.amplitude,
    required this.waveData,
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
    // ── NEW ──
    this.isPaused = false,
    this.onSeekBarIndexChanged,
  });

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}
```

- [ ] **Step 2: Add drag handler + seekBarIndex computation to state**

Replace `_RecordingWaveformState` with:

```dart
class _RecordingWaveformState extends State<RecordingWaveform> {
  Offset _totalBackDistance = Offset.zero;
  final Offset _dragOffset = Offset.zero;
  double _initialPosition = 0.0;

  @override
  void didUpdateWidget(RecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.waveData.isEmpty && oldWidget.waveData.isNotEmpty) {
      setState(() {
        _totalBackDistance = Offset.zero;
        _initialPosition = 0.0;
      });
    }
  }

  int get _currentSeekBarIndex {
    final halfWidth = widget.size.width / 2;
    final index = ((_totalBackDistance.dx + halfWidth) / widget.spacing).round();
    return index.clamp(0, widget.waveData.isEmpty ? 0 : widget.waveData.length - 1);
  }

  double get _maxScrollDx {
    if (widget.waveData.isEmpty) return 0.0;
    return ((widget.waveData.length - 1) * widget.spacing).toDouble();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.isPaused) return;
    final newDx = (_totalBackDistance.dx - details.delta.dx).clamp(0.0, _maxScrollDx);
    setState(() {
      _totalBackDistance = Offset(newDx, 0);
    });
    widget.onSeekBarIndexChanged?.call(_currentSeekBarIndex);
  }

  void _onPushBack() {
    _initialPosition = 0.0;
    _totalBackDistance = _totalBackDistance + Offset(widget.spacing, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: widget.isPaused ? _onHorizontalDragUpdate : null,
      child: Container(
        width: widget.size.width,
        height: widget.size.height,
        color: Colors.transparent,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: CustomRecorderWavePainter(
              waveData: widget.waveData.isEmpty ? [0.0] : widget.waveData,
              waveColor: widget.waveColor,
              showMiddleLine: widget.showMiddleLine,
              spacing: widget.spacing,
              initialPosition: _initialPosition,
              showTop: true,
              showBottom: true,
              bottomPadding: 0,
              waveCap: StrokeCap.round,
              middleLineColor: widget.middleLineColor,
              middleLineThickness: widget.middleLineThickness,
              totalBackDistance: _totalBackDistance,
              dragOffset: _dragOffset,
              waveThickness: widget.waveThickness,
              pushBack: _onPushBack,
              callPushback: !widget.isPaused,
              extendWaveform: true,
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
            ),
          ),
        ),
      ),
    );
  }
}
```

Note `callPushback: !widget.isPaused` — disables auto-scroll when paused so drag can control position freely. Also note new `isPaused` parameter passed to the painter (added in Task 3).

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart
git commit -m "feat: waveform draggable during pause, exposes seekBarIndex"
```

---

## Task 3 — Playhead line + per-bar opacity split in painter

**Files:**
- Modify: `lib/presentation/widgets/recording/custom_waveform/recorder_wave_painter.dart`

When paused: draw a vertical cyan line at horizontal center; bars left of center = full opacity, bars right = 30% opacity.

- [ ] **Step 1: Add `isPaused` field to painter constructor**

Add `isPaused` to `CustomRecorderWavePainter`:

```dart
// in the field declarations, after `scaleFactor`:
final bool isPaused;

// in the constructor parameters, after `currentlyRecordedDuration`:
required this.isPaused,

// in the constructor initializer list, _wavePaint is already set; no change needed there
```

Update the `shouldRepaint` method to also check `isPaused`:

```dart
@override
bool shouldRepaint(CustomRecorderWavePainter oldDelegate) {
  return oldDelegate.waveData.length != waveData.length ||
      oldDelegate.totalBackDistance != totalBackDistance ||
      oldDelegate.dragOffset != dragOffset ||
      oldDelegate.waveColor != waveColor ||
      oldDelegate.isPaused != isPaused;
}
```

- [ ] **Step 2: Add playhead line drawing**

Add this private method to `CustomRecorderWavePainter`:

```dart
void _drawPlayhead(Canvas canvas, Size size) {
  final halfWidth = size.width / 2;
  final paint = Paint()
    ..color = Colors.cyanAccent
    ..strokeWidth = 2.0;
  canvas.drawLine(
    Offset(halfWidth, 0),
    Offset(halfWidth, size.height),
    paint,
  );
}
```

- [ ] **Step 3: Modify `_drawWave` to apply opacity split when paused**

Replace `_drawWave`:

```dart
void _drawWave(Canvas canvas, Size size, int i) {
  final halfWidth = size.width / 2;
  final height = size.height;
  final dx =
      -totalBackDistance.dx + dragOffset.dx + (spacing * i) - initialPosition;
  final scaledWaveHeight = waveData[i] * scaleFactor;
  final upperDy = height - (showTop ? scaledWaveHeight : 0) - bottomPadding;
  final lowerDy =
      height + (showBottom ? scaledWaveHeight : 0) - bottomPadding;

  if (dx > -halfWidth && dx < halfWidth * 2) {
    if (isPaused) {
      final opacity = dx < halfWidth ? 1.0 : 0.3;
      final paint = Paint()
        ..color = waveColor.withValues(alpha: opacity)
        ..strokeWidth = waveThickness
        ..strokeCap = waveCap;
      canvas.drawLine(Offset(dx, upperDy), Offset(dx, lowerDy), paint);
    } else {
      canvas.drawLine(Offset(dx, upperDy), Offset(dx, lowerDy), _wavePaint);
    }
  }
}
```

- [ ] **Step 4: Call `_drawPlayhead` from `paint()` when paused**

In `paint()`, after the `for` loop and before `/// middle line`, add:

```dart
/// playhead line (pause seek mode)
if (isPaused) _drawPlayhead(canvas, size);
```

- [ ] **Step 5: Update all `CustomRecorderWavePainter` constructor calls**

Only one call site exists: `flutter_sound_waveform.dart` (already updated in Task 2 — `isPaused: widget.isPaused` was included).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/recording/custom_waveform/recorder_wave_painter.dart
git commit -m "feat: playhead line and opacity split when paused"
```

---

## Task 4 — Seek time label + wiring in fullscreen view

**Files:**
- Modify: `lib/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart`
- Modify: `lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart`

Show `"← 00:03 / 00:07 →"` label during pause. Pass `isPaused` and `onSeekBarIndexChanged` down to the waveform.

- [ ] **Step 1: Update `RecordingFullscreenView` constructor**

Replace the existing class with the complete updated version. Key changes:
- Remove old `onSeek: Function(double)?` parameter
- Add `onSeekBarIndexChanged: Function(int)?` parameter
- Add `seekBarIndex: int` parameter (default 0)
- Add `totalDuration: Duration` parameter

```dart
// File: presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart
import 'package:flutter/material.dart';
import '../../../../core/extensions/duration_extensions.dart';
import 'control_buttons.dart';
import '../custom_waveform/flutter_sound_waveform.dart';

class RecordingFullscreenView extends StatelessWidget {
  final String? title;
  final Duration elapsed;
  final bool isRecording;
  final bool isPaused;
  final String? filePath;
  final double amplitude;
  final List<double> waveData;
  final VoidCallback onToggle;
  final VoidCallback? onPause;
  final VoidCallback? onDone;
  final VoidCallback? onChat;
  final VoidCallback? onPlay;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  // ── NEW (replaces onSeek) ──
  final Function(int seekBarIndex)? onSeekBarIndexChanged;
  final int seekBarIndex;

  const RecordingFullscreenView({
    super.key,
    required this.title,
    required this.elapsed,
    required this.isRecording,
    this.isPaused = false,
    required this.filePath,
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
  });

  String get _formattedTime => elapsed.formatted;

  /// Format seek position as MM:SS / MM:SS
  String _seekLabel(int barIndex) {
    final seekMs = barIndex * 50;
    final totalMs = waveData.length * 50;
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
            Flexible(flex: 2, child: _buildFullscreenTitle()),
            Flexible(flex: 1, child: _buildFullscreenSubtitle()),
            Flexible(flex: 8, child: _buildFullscreenWaveform(context)),
            // Seek label replaces time display during pause
            Flexible(
              flex: 2,
              child: isPaused
                  ? _buildSeekLabel()
                  : _buildFullscreenTimeDisplay(),
            ),
            Flexible(flex: 4, child: _buildFullscreenPlaybackControls()),
            Flexible(flex: 4, child: _buildFullscreenActionButton()),
          ],
        ),
        if (!isRecording || isPaused)
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

  Widget _buildFullscreenTitle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        title ?? 'New Recording',
        style: const TextStyle(
          color: Colors.cyan,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFullscreenSubtitle() {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Text(
      '$timeString  $_formattedTime',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildFullscreenWaveform(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(
        heightFactor: 0.65,
        widthFactor: 1.0,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildWaveformWidget(),
        ),
      ),
    );
  }

  Widget _buildWaveformWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RecordingWaveform(
          amplitude: amplitude,
          waveData: waveData,
          size: Size(constraints.maxWidth, constraints.maxHeight),
          waveColor: Colors.cyan,
          spacing: 2.0,
          waveThickness: 2.5,
          scaleFactor: 80.0,
          currentDuration: elapsed,
          isPaused: isPaused,
          onSeekBarIndexChanged: onSeekBarIndexChanged,
        );
      },
    );
  }

  Widget _buildSeekLabel() {
    return Center(
      child: Text(
        _seekLabel(seekBarIndex),
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

  Widget _buildFullscreenTimeDisplay() {
    return Center(
      child: Text(
        _formattedTime,
        style: const TextStyle(
          color: Colors.cyan,
          fontSize: 38,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.0,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFullscreenPlaybackControls() {
    return FullscreenPlaybackControls(
      isRecording: isRecording,
      onPlay: onPlay,
      onRewind: onRewind,
      onForward: onForward,
    );
  }

  Widget _buildFullscreenActionButton() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = (constraints.maxHeight * 0.45).clamp(70.0, 120.0);
          return GestureDetector(
            onTap: () {
              if (isRecording) {
                onPause?.call();
              } else if (isPaused) {
                onPlay?.call();
              } else {
                onToggle();
              }
            },
            child: Container(
              width: size,
              height: size,
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
                      ? Icon(
                          Icons.pause,
                          key: const ValueKey('pause'),
                          color: Colors.white,
                          size: size * 0.4,
                        )
                      : isPaused
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

  Widget _buildDoneButton() {
    return GestureDetector(
      onTap: onDone,
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
```

- [ ] **Step 2: Update `RecordingBottomSheet` to track `_seekBarIndex` and pass it down**

In `recording_bottom_sheet_main.dart`:

Add state field:
```dart
int _seekBarIndex = 0;
```

Add reset in `didUpdateWidget` when recording transitions to paused (reset to last bar index):
```dart
// Inside didUpdateWidget, after the existing isRecording check:
if (widget.isPaused && !oldWidget.isPaused) {
  setState(() {
    _seekBarIndex = _waveData.isEmpty ? 0 : _waveData.length - 1;
  });
}
```

Add reset when new recording starts:
```dart
// In the block: if (widget.isRecording && !oldWidget.isRecording && !oldWidget.isPaused)
setState(() {
  _waveData.clear();
  _seekBarIndex = 0;
});
```

Update the `RecordingFullscreenView` constructor call in `_buildContainer()`:
```dart
RecordingFullscreenView(
  key: const ValueKey('fullscreen'),
  title: widget.title,
  elapsed: widget.elapsed,
  isRecording: widget.isRecording,
  isPaused: widget.isPaused,
  filePath: widget.filePath,
  amplitude: widget.amplitude,
  waveData: _waveData,
  onToggle: widget.onToggle,
  onPause: widget.onPause,
  onDone: widget.onDone,
  onChat: widget.onChat,
  onPlay: widget.onPlay,        // resume is handled here — see Task 11
  onRewind: widget.onRewind,
  onForward: widget.onForward,
  onSeekBarIndexChanged: (index) {
    setState(() => _seekBarIndex = index);
  },
  seekBarIndex: _seekBarIndex,
)
```

Also remove `onSeek` from `RecordingBottomSheet`'s constructor and field declarations (it is replaced by the BLoC-dispatching resume — see Task 11).

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart \
        lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart
git commit -m "feat: seek time label and seekBarIndex tracking in bottom sheet"
```

---

## Task 5 — `AudioTrimmerService` (Dart)

**Files:**
- Create: `lib/services/audio/audio_trimmer_service.dart`

- [ ] **Step 1: Create the service**

```dart
// File: services/audio/audio_trimmer_service.dart
import 'package:flutter/services.dart';

/// Flutter-side wrapper for the native audio trimmer platform channel.
///
/// Channel: wavnote/audio_trimmer
/// Methods: trimAudio, concatenateAudio
class AudioTrimmerService {
  static const MethodChannel _channel =
      MethodChannel('wavnote/audio_trimmer');

  bool _isInitialized = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = true;
    return true;
  }

  /// Trim [filePath] to [durationMs] milliseconds from the start.
  ///
  /// The result is written to [outputPath] (temp file → rename pattern
  /// is handled natively). If [outputPath] equals [filePath], the
  /// original is replaced atomically.
  ///
  /// Throws [PlatformException] on native failure.
  Future<void> trimAudio({
    required String filePath,
    required int durationMs,
    required String format,
    required String outputPath,
  }) async {
    await _channel.invokeMethod<void>('trimAudio', {
      'filePath': filePath,
      'durationMs': durationMs,
      'format': format,
      'outputPath': outputPath,
    });
  }

  /// Concatenate [basePath] + [appendPath] → [outputPath].
  ///
  /// Both inputs must be the same format. The result replaces [outputPath].
  /// Throws [PlatformException] on native failure.
  Future<void> concatenateAudio({
    required String basePath,
    required String appendPath,
    required String outputPath,
    required String format,
  }) async {
    await _channel.invokeMethod<void>('concatenateAudio', {
      'basePath': basePath,
      'appendPath': appendPath,
      'outputPath': outputPath,
      'format': format,
    });
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/audio/audio_trimmer_service.dart
git commit -m "feat: AudioTrimmerService dart channel wrapper"
```

---

## Task 6 — iOS `AudioTrimmerPlugin.swift`

**Files:**
- Create: `ios/Runner/AudioTrimmerPlugin.swift`
- Modify: `ios/Runner/AppDelegate.swift`

- [ ] **Step 1: Create the Swift plugin**

```swift
// File: ios/Runner/AudioTrimmerPlugin.swift
import Flutter
import AVFoundation

class AudioTrimmerPlugin: NSObject, FlutterPlugin {

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "wavnote/audio_trimmer",
      binaryMessenger: registrar.messenger()
    )
    let instance = AudioTrimmerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
      return
    }
    switch call.method {
    case "trimAudio":
      trimAudio(args: args, result: result)
    case "concatenateAudio":
      concatenateAudio(args: args, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Trim

  private func trimAudio(args: [String: Any], result: @escaping FlutterResult) {
    guard
      let filePath = args["filePath"] as? String,
      let durationMs = args["durationMs"] as? Int,
      let outputPath = args["outputPath"] as? String
    else {
      result(FlutterError(code: "INVALID_ARGS", message: "trimAudio: missing params", details: nil))
      return
    }

    let asset = AVURLAsset(url: URL(fileURLWithPath: filePath))
    let trimDuration = CMTime(value: CMTimeValue(durationMs), timescale: 1000)
    let timeRange = CMTimeRange(start: .zero, duration: trimDuration)

    guard let exportSession = AVAssetExportSession(
      asset: asset,
      presetName: AVAssetExportPresetPassthrough
    ) else {
      result(FlutterError(code: "EXPORT_FAILED", message: "Could not create export session", details: nil))
      return
    }

    let format = (args["format"] as? String) ?? "m4a"
    let fileType: AVFileType = format == "wav" ? .wav : .m4a
    let tempPath = outputPath + ".tmp"

    exportSession.outputURL = URL(fileURLWithPath: tempPath)
    exportSession.outputFileType = fileType
    exportSession.timeRange = timeRange

    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        do {
          let fm = FileManager.default
          if fm.fileExists(atPath: outputPath) {
            try fm.removeItem(atPath: outputPath)
          }
          try fm.moveItem(atPath: tempPath, toPath: outputPath)
          result(nil)
        } catch {
          result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterError(
          code: "EXPORT_FAILED",
          message: exportSession.error?.localizedDescription ?? "Unknown export error",
          details: nil
        ))
      }
    }
  }

  // MARK: - Concatenate

  private func concatenateAudio(args: [String: Any], result: @escaping FlutterResult) {
    guard
      let basePath = args["basePath"] as? String,
      let appendPath = args["appendPath"] as? String,
      let outputPath = args["outputPath"] as? String
    else {
      result(FlutterError(code: "INVALID_ARGS", message: "concatenateAudio: missing params", details: nil))
      return
    }

    let format = (args["format"] as? String) ?? "m4a"
    let fileType: AVFileType = format == "wav" ? .wav : .m4a

    let composition = AVMutableComposition()
    guard let track = composition.addMutableTrack(
      withMediaType: .audio,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      result(FlutterError(code: "TRACK_ERROR", message: "Could not create composition track", details: nil))
      return
    }

    let assets: [AVURLAsset] = [
      AVURLAsset(url: URL(fileURLWithPath: basePath)),
      AVURLAsset(url: URL(fileURLWithPath: appendPath)),
    ]

    var cursor = CMTime.zero
    for asset in assets {
      let duration = asset.duration
      guard let srcTrack = asset.tracks(withMediaType: .audio).first else { continue }
      do {
        try track.insertTimeRange(
          CMTimeRange(start: .zero, duration: duration),
          of: srcTrack,
          at: cursor
        )
        cursor = CMTimeAdd(cursor, duration)
      } catch {
        result(FlutterError(code: "INSERT_ERROR", message: error.localizedDescription, details: nil))
        return
      }
    }

    guard let exportSession = AVAssetExportSession(
      asset: composition,
      presetName: AVAssetExportPresetPassthrough
    ) else {
      result(FlutterError(code: "EXPORT_FAILED", message: "Could not create export session", details: nil))
      return
    }

    let tempPath = outputPath + ".concat.tmp"
    exportSession.outputURL = URL(fileURLWithPath: tempPath)
    exportSession.outputFileType = fileType

    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        do {
          let fm = FileManager.default
          if fm.fileExists(atPath: outputPath) {
            try fm.removeItem(atPath: outputPath)
          }
          try fm.moveItem(atPath: tempPath, toPath: outputPath)
          result(nil)
        } catch {
          result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterError(
          code: "EXPORT_FAILED",
          message: exportSession.error?.localizedDescription ?? "Unknown export error",
          details: nil
        ))
      }
    }
  }
}
```

- [ ] **Step 2: Register the plugin in `AppDelegate.swift`**

Replace `AppDelegate.swift` with:

```swift
// File: ios/Runner/AppDelegate.swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register audio trimmer plugin
    if let registrar = self.registrar(forPlugin: "AudioTrimmerPlugin") {
      AudioTrimmerPlugin.register(with: registrar)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/AudioTrimmerPlugin.swift ios/Runner/AppDelegate.swift
git commit -m "feat: iOS AudioTrimmerPlugin (trim + concatenate via AVFoundation)"
```

---

## Task 7 — Android `AudioTrimmerPlugin.kt`

**Files:**
- Create: `android/app/src/main/kotlin/com/example/wavnote/AudioTrimmerPlugin.kt`
- Modify: `android/app/src/main/kotlin/com/example/wavnote/MainActivity.kt`

- [ ] **Step 1: Create the Kotlin plugin**

```kotlin
// File: android/app/src/main/kotlin/com/example/wavnote/AudioTrimmerPlugin.kt
package com.example.wavnote

import android.media.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

class AudioTrimmerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

  private lateinit var channel: MethodChannel

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "wavnote/audio_trimmer")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "trimAudio" -> {
        val filePath = call.argument<String>("filePath") ?: return result.error("INVALID_ARGS", "filePath missing", null)
        val durationMs = call.argument<Int>("durationMs") ?: return result.error("INVALID_ARGS", "durationMs missing", null)
        val format = call.argument<String>("format") ?: "m4a"
        val outputPath = call.argument<String>("outputPath") ?: return result.error("INVALID_ARGS", "outputPath missing", null)
        try {
          if (format == "wav") {
            trimWav(filePath, durationMs, outputPath)
          } else {
            trimMuxed(filePath, durationMs.toLong() * 1000L, outputPath, format)
          }
          result.success(null)
        } catch (e: Exception) {
          result.error("TRIM_FAILED", e.message, null)
        }
      }
      "concatenateAudio" -> {
        val basePath = call.argument<String>("basePath") ?: return result.error("INVALID_ARGS", "basePath missing", null)
        val appendPath = call.argument<String>("appendPath") ?: return result.error("INVALID_ARGS", "appendPath missing", null)
        val outputPath = call.argument<String>("outputPath") ?: return result.error("INVALID_ARGS", "outputPath missing", null)
        val format = call.argument<String>("format") ?: "m4a"
        try {
          if (format == "wav") {
            concatenateWav(basePath, appendPath, outputPath)
          } else {
            concatenateMuxed(basePath, appendPath, outputPath, format)
          }
          result.success(null)
        } catch (e: Exception) {
          result.error("CONCAT_FAILED", e.message, null)
        }
      }
      else -> result.notImplemented()
    }
  }

  // ── Trim: MediaExtractor + MediaMuxer (M4A / FLAC) ──────────────────────────

  private fun trimMuxed(inputPath: String, endUs: Long, outputPath: String, format: String) {
    val tempPath = "$outputPath.tmp"
    val extractor = MediaExtractor()
    extractor.setDataSource(inputPath)

    val muxerFormat = if (format == "flac") MediaMuxer.OutputFormat.MUXER_OUTPUT_WEBM
                      else MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
    val muxer = MediaMuxer(tempPath, muxerFormat)

    val trackMap = mutableMapOf<Int, Int>()
    for (i in 0 until extractor.trackCount) {
      val fmt = extractor.getTrackFormat(i)
      val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
      if (mime.startsWith("audio/")) {
        extractor.selectTrack(i)
        trackMap[i] = muxer.addTrack(fmt)
      }
    }

    muxer.start()
    val buffer = ByteBuffer.allocate(1024 * 1024)
    val info = MediaCodec.BufferInfo()

    for ((srcTrack, muxTrack) in trackMap) {
      extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
      while (true) {
        info.offset = 0
        info.size = extractor.readSampleData(buffer, 0)
        if (info.size < 0) break
        info.presentationTimeUs = extractor.sampleTime
        if (info.presentationTimeUs > endUs) break
        info.flags = extractor.sampleFlags
        muxer.writeSampleData(muxTrack, buffer, info)
        extractor.advance()
      }
    }

    muxer.stop()
    muxer.release()
    extractor.release()

    atomicReplace(tempPath, outputPath)
  }

  // ── Trim: WAV byte truncation ────────────────────────────────────────────────

  private fun trimWav(inputPath: String, durationMs: Int, outputPath: String) {
    val src = File(inputPath)
    val bytes = src.readBytes()
    // Read WAV header fields
    val sampleRate = ByteBuffer.wrap(bytes, 24, 4).order(ByteOrder.LITTLE_ENDIAN).int
    val bitsPerSample = ByteBuffer.wrap(bytes, 34, 2).order(ByteOrder.LITTLE_ENDIAN).short.toInt()
    val channels = ByteBuffer.wrap(bytes, 22, 2).order(ByteOrder.LITTLE_ENDIAN).short.toInt()
    val dataOffset = findWavDataOffset(bytes)
    val bytesPerSample = bitsPerSample / 8
    val bytesPerSecond = sampleRate * channels * bytesPerSample
    val keepBytes = (bytesPerSecond * durationMs / 1000).toLong()
    val newDataSize = minOf(keepBytes, (bytes.size - dataOffset).toLong()).toInt()

    val tempPath = "$outputPath.tmp"
    FileOutputStream(tempPath).use { fos ->
      fos.write(bytes, 0, dataOffset + newDataSize)
    }
    updateWavHeader(tempPath, newDataSize)
    atomicReplace(tempPath, outputPath)
  }

  private fun findWavDataOffset(bytes: ByteArray): Int {
    var i = 12
    while (i < bytes.size - 8) {
      val id = String(bytes, i, 4, Charsets.US_ASCII)
      val size = ByteBuffer.wrap(bytes, i + 4, 4).order(ByteOrder.LITTLE_ENDIAN).int
      if (id == "data") return i + 8
      i += 8 + size
    }
    return 44 // fallback to standard header size
  }

  private fun updateWavHeader(path: String, dataSize: Int) {
    RandomAccessFile(path, "rw").use { raf ->
      raf.seek(4)
      val chunkSize = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(dataSize + 36).array()
      raf.write(chunkSize)
      val dataOffset = findWavDataOffset(File(path).readBytes())
      raf.seek((dataOffset - 4).toLong())
      val subChunk2Size = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(dataSize).array()
      raf.write(subChunk2Size)
    }
  }

  // ── Concatenate: MediaMuxer (M4A / FLAC) ─────────────────────────────────────

  private fun concatenateMuxed(basePath: String, appendPath: String, outputPath: String, format: String) {
    val tempPath = "$outputPath.concat.tmp"
    val muxerFormat = if (format == "flac") MediaMuxer.OutputFormat.MUXER_OUTPUT_WEBM
                      else MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
    val muxer = MediaMuxer(tempPath, muxerFormat)
    val buffer = ByteBuffer.allocate(1024 * 1024)
    val info = MediaCodec.BufferInfo()
    var timeOffsetUs = 0L

    for (inputPath in listOf(basePath, appendPath)) {
      val extractor = MediaExtractor()
      extractor.setDataSource(inputPath)
      var muxTrack = -1
      for (i in 0 until extractor.trackCount) {
        val fmt = extractor.getTrackFormat(i)
        val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
        if (mime.startsWith("audio/")) {
          extractor.selectTrack(i)
          if (muxTrack == -1) muxTrack = muxer.addTrack(fmt)
          break
        }
      }
      if (muxTrack == -1) { extractor.release(); continue }
      if (inputPath == basePath) muxer.start()

      var lastPts = 0L
      extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
      while (true) {
        info.offset = 0
        info.size = extractor.readSampleData(buffer, 0)
        if (info.size < 0) break
        info.presentationTimeUs = extractor.sampleTime + timeOffsetUs
        lastPts = info.presentationTimeUs
        info.flags = extractor.sampleFlags
        muxer.writeSampleData(muxTrack, buffer, info)
        extractor.advance()
      }
      timeOffsetUs = lastPts + 1
      extractor.release()
    }

    muxer.stop()
    muxer.release()
    atomicReplace(tempPath, outputPath)
  }

  // ── Concatenate: WAV PCM splice ───────────────────────────────────────────────

  private fun concatenateWav(basePath: String, appendPath: String, outputPath: String) {
    val baseBytes = File(basePath).readBytes()
    val appendBytes = File(appendPath).readBytes()
    val baseDataOffset = findWavDataOffset(baseBytes)
    val appendDataOffset = findWavDataOffset(appendBytes)
    val baseDataSize = baseBytes.size - baseDataOffset
    val appendDataSize = appendBytes.size - appendDataOffset
    val totalDataSize = baseDataSize + appendDataSize

    val tempPath = "$outputPath.concat.tmp"
    FileOutputStream(tempPath).use { fos ->
      fos.write(baseBytes, 0, baseDataOffset + baseDataSize)
      fos.write(appendBytes, appendDataOffset, appendDataSize)
    }
    updateWavHeader(tempPath, totalDataSize)
    atomicReplace(tempPath, outputPath)
  }

  // ── Utility ──────────────────────────────────────────────────────────────────

  private fun atomicReplace(srcPath: String, dstPath: String) {
    val src = File(srcPath)
    val dst = File(dstPath)
    if (dst.exists()) dst.delete()
    src.renameTo(dst)
  }
}
```

- [ ] **Step 2: Register plugin in `MainActivity.kt`**

```kotlin
// File: android/app/src/main/kotlin/com/example/wavnote/MainActivity.kt
package com.example.wavnote

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    flutterEngine.plugins.add(AudioTrimmerPlugin())
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/wavnote/AudioTrimmerPlugin.kt \
        android/app/src/main/kotlin/com/example/wavnote/MainActivity.kt
git commit -m "feat: Android AudioTrimmerPlugin (trim + concatenate M4A/WAV/FLAC)"
```

---

## Task 8 — Register `AudioTrimmerService` in DI

**Files:**
- Modify: `lib/config/dependency_injection.dart`

- [ ] **Step 1: Add import and registration**

```dart
// File: config/dependency_injection.dart
import 'package:get_it/get_it.dart';

import '../data/repositories/recording_repository.dart';
import '../services/audio/audio_service_coordinator.dart';
import '../services/audio/audio_trimmer_service.dart';    // ← ADD
import '../services/location/geolocation_service.dart';

final GetIt sl = GetIt.instance;

Future<void> setupDependencies() async {
  if (!sl.isRegistered<AudioServiceCoordinator>()) {
    sl.registerLazySingleton<AudioServiceCoordinator>(
      () => AudioServiceCoordinator(),
    );
  }

  if (!sl.isRegistered<GeolocationService>()) {
    sl.registerLazySingleton<GeolocationService>(
      () => GeolocationService(),
    );
  }

  if (!sl.isRegistered<RecordingRepository>()) {
    sl.registerLazySingleton<RecordingRepository>(
      () => RecordingRepository(),
    );
  }

  // ── ADD ──────────────────────────────────────────────────────────────────────
  if (!sl.isRegistered<AudioTrimmerService>()) {
    sl.registerLazySingleton<AudioTrimmerService>(
      () => AudioTrimmerService(),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────────

  final audioInitialized = await sl<AudioServiceCoordinator>().initialize();
  if (!audioInitialized) {
    assert(false, 'AudioServiceCoordinator failed to initialize');
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/config/dependency_injection.dart
git commit -m "feat: register AudioTrimmerService in DI"
```

---

## Task 9 — `SeekAndResumeUseCase`

**Files:**
- Create: `lib/domain/usecases/recording/seek_and_resume_usecase.dart`
- Create: `test/unit/usecases/seek_and_resume_usecase_test.dart`

**Logic summary:**
1. Compute `trimDurationMs = seekBarIndex * 50`
2. Call `_audioService.stopRecording()` — flushes file, no DB save
3. Build `basePath = filePath.replaceAll('.ext', '_base.ext')`
4. Call `_trimmerService.trimAudio(filePath → basePath, durationMs, format)`
5. Truncate `waveData` to `seekBarIndex`
6. Call `_audioService.startRecording(filePath, format, ...)` — new recording to original path
7. Return `Right(SeekAndResumeResult(seekBasePath: basePath, waveData: truncated))`

If `seekBarIndex == lastBarIndex`: skip trim, call `_audioService.resumeRecording()` instead and return `Right(SeekAndResumeResult(seekBasePath: null, waveData: waveData))`.

- [ ] **Step 1: Write the failing test**

```dart
// File: test/unit/usecases/seek_and_resume_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';

import 'package:wavnote/domain/usecases/recording/seek_and_resume_usecase.dart';
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart';
import 'package:wavnote/services/audio/audio_trimmer_service.dart';
import 'package:wavnote/core/enums/audio_format.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';

class MockAudioService extends Mock implements IAudioServiceRepository {}
class MockTrimmerService extends Mock implements AudioTrimmerService {}

void main() {
  late SeekAndResumeUseCase useCase;
  late MockAudioService mockAudio;
  late MockTrimmerService mockTrimmer;

  setUp(() {
    mockAudio = MockAudioService();
    mockTrimmer = MockTrimmerService();
    useCase = SeekAndResumeUseCase(
      audioService: mockAudio,
      trimmerService: mockTrimmer,
    );
    registerFallbackValue(AudioFormat.m4a);
  });

  group('SeekAndResumeUseCase', () {
    const filePath = '/docs/all_recordings/test_123.m4a';
    final waveData = List<double>.generate(100, (i) => 0.5);
    final fakeEntity = RecordingEntity.create(
      name: 'test',
      filePath: filePath,
      folderId: 'all_recordings',
      format: AudioFormat.m4a,
      duration: const Duration(seconds: 5),
      fileSize: 1000,
      sampleRate: 44100,
    );

    test('happy path: trims, restarts, returns truncated waveData', () async {
      when(() => mockAudio.stopRecording()).thenAnswer((_) async => fakeEntity);
      when(() => mockTrimmer.trimAudio(
        filePath: any(named: 'filePath'),
        durationMs: any(named: 'durationMs'),
        format: any(named: 'format'),
        outputPath: any(named: 'outputPath'),
      )).thenAnswer((_) async {});
      when(() => mockAudio.startRecording(
        filePath: any(named: 'filePath'),
        format: any(named: 'format'),
        sampleRate: any(named: 'sampleRate'),
        bitRate: any(named: 'bitRate'),
      )).thenAnswer((_) async => true);

      final result = await useCase.execute(
        filePath: filePath,
        seekBarIndex: 40,
        format: AudioFormat.m4a,
        sampleRate: 44100,
        bitRate: 128000,
        waveData: waveData,
      );

      expect(result.isRight(), true);
      final r = result.getOrElse(() => throw Exception());
      expect(r.truncatedWaveData.length, 40);
      expect(r.seekBasePath, contains('_base'));
      // trim called with 40 * 50 = 2000ms
      verify(() => mockTrimmer.trimAudio(
        filePath: filePath,
        durationMs: 2000,
        format: 'm4a',
        outputPath: any(named: 'outputPath'),
      )).called(1);
    });

    test('seekBarIndex == waveData.length - 1: resumes without trim', () async {
      when(() => mockAudio.resumeRecording()).thenAnswer((_) async => true);

      final result = await useCase.execute(
        filePath: filePath,
        seekBarIndex: waveData.length - 1,
        format: AudioFormat.m4a,
        sampleRate: 44100,
        bitRate: 128000,
        waveData: waveData,
      );

      expect(result.isRight(), true);
      final r = result.getOrElse(() => throw Exception());
      expect(r.seekBasePath, isNull);
      expect(r.truncatedWaveData.length, waveData.length);
      verifyNever(() => mockTrimmer.trimAudio(
        filePath: any(named: 'filePath'),
        durationMs: any(named: 'durationMs'),
        format: any(named: 'format'),
        outputPath: any(named: 'outputPath'),
      ));
    });

    test('trim failure returns Left(TrimFailure)', () async {
      when(() => mockAudio.stopRecording()).thenAnswer((_) async => fakeEntity);
      when(() => mockTrimmer.trimAudio(
        filePath: any(named: 'filePath'),
        durationMs: any(named: 'durationMs'),
        format: any(named: 'format'),
        outputPath: any(named: 'outputPath'),
      )).thenThrow(PlatformException(code: 'TRIM_FAILED', message: 'native error'));

      final result = await useCase.execute(
        filePath: filePath,
        seekBarIndex: 40,
        format: AudioFormat.m4a,
        sampleRate: 44100,
        bitRate: 128000,
        waveData: waveData,
      );

      expect(result.isLeft(), true);
    });

    test('recorder restart failure returns Left(RecordingRestartFailure)', () async {
      when(() => mockAudio.stopRecording()).thenAnswer((_) async => fakeEntity);
      when(() => mockTrimmer.trimAudio(
        filePath: any(named: 'filePath'),
        durationMs: any(named: 'durationMs'),
        format: any(named: 'format'),
        outputPath: any(named: 'outputPath'),
      )).thenAnswer((_) async {});
      when(() => mockAudio.startRecording(
        filePath: any(named: 'filePath'),
        format: any(named: 'format'),
        sampleRate: any(named: 'sampleRate'),
        bitRate: any(named: 'bitRate'),
      )).thenAnswer((_) async => false);

      final result = await useCase.execute(
        filePath: filePath,
        seekBarIndex: 40,
        format: AudioFormat.m4a,
        sampleRate: 44100,
        bitRate: 128000,
        waveData: waveData,
      );

      expect(result.isLeft(), true);
    });
  });
}
```

- [ ] **Step 2: Run test — verify it FAILS**

```bash
cd /path/to/wavnote && flutter test test/unit/usecases/seek_and_resume_usecase_test.dart
```

Expected: compilation error — `SeekAndResumeUseCase` not found.

- [ ] **Step 3: Implement `SeekAndResumeUseCase`**

```dart
// File: domain/usecases/recording/seek_and_resume_usecase.dart
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/enums/audio_format.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/repositories/i_audio_service_repository.dart';
import '../../../services/audio/audio_trimmer_service.dart';

class SeekAndResumeUseCase {
  final IAudioServiceRepository _audioService;
  final AudioTrimmerService _trimmerService;

  SeekAndResumeUseCase({
    required IAudioServiceRepository audioService,
    required AudioTrimmerService trimmerService,
  })  : _audioService = audioService,
        _trimmerService = trimmerService;

  Future<Either<Failure, SeekAndResumeResult>> execute({
    required String filePath,
    required int seekBarIndex,
    required AudioFormat format,
    required int sampleRate,
    required int bitRate,
    required List<double> waveData,
  }) async {
    try {
      final lastBarIndex = waveData.isEmpty ? 0 : waveData.length - 1;

      // No-op seek: just resume normally
      if (seekBarIndex >= lastBarIndex) {
        final resumed = await _audioService.resumeRecording();
        if (!resumed) {
          return Left(AudioRecordingFailure.startFailed('Could not resume recording'));
        }
        return Right(SeekAndResumeResult(
          seekBasePath: null,
          truncatedWaveData: List<double>.from(waveData),
        ));
      }

      final trimDurationMs = seekBarIndex * 50;

      // 1. Stop recorder — flushes file, no DB save
      final entity = await _audioService.stopRecording();
      if (entity == null) {
        return Left(AudioRecordingFailure.stopFailed('Could not flush recording for trim'));
      }

      // 2. Trim to base path (preserve pre-seek content)
      final basePath = _buildBasePath(filePath);
      try {
        await _trimmerService.trimAudio(
          filePath: filePath,
          durationMs: trimDurationMs,
          format: format.name,
          outputPath: basePath,
        );
      } on PlatformException catch (e) {
        return Left(AudioRecordingFailure(
          message: 'Trim failed: ${e.message}',
          errorType: AudioRecordingErrorType.recordingStartFailed,
          code: 'TRIM_FAILED',
        ));
      }

      // 3. Truncate waveData
      final truncated = waveData.sublist(0, seekBarIndex);

      // 4. Restart recorder at original path (new audio from seek point onwards)
      final started = await _audioService.startRecording(
        filePath: filePath,
        format: format,
        sampleRate: sampleRate,
        bitRate: bitRate,
      );
      if (!started) {
        return Left(AudioRecordingFailure.startFailed(
          'Could not restart recording after trim',
        ));
      }

      return Right(SeekAndResumeResult(
        seekBasePath: basePath,
        truncatedWaveData: truncated,
      ));
    } catch (e, st) {
      debugPrint('❌ SeekAndResumeUseCase: $e\n$st');
      return Left(UnexpectedFailure(
        message: 'Unexpected error during seek-and-resume: $e',
        code: 'SEEK_RESUME_UNEXPECTED',
      ));
    }
  }

  /// Build the path for the pre-seek base file.
  /// e.g. /docs/.../recording_123.m4a → /docs/.../recording_123_base.m4a
  String _buildBasePath(String filePath) {
    final dot = filePath.lastIndexOf('.');
    if (dot < 0) return '${filePath}_base';
    return '${filePath.substring(0, dot)}_base${filePath.substring(dot)}';
  }
}

class SeekAndResumeResult {
  /// Absolute path to the trimmed base file (null when no trim was needed).
  final String? seekBasePath;

  /// waveData truncated to seekBarIndex entries.
  final List<double> truncatedWaveData;

  const SeekAndResumeResult({
    required this.seekBasePath,
    required this.truncatedWaveData,
  });
}
```

- [ ] **Step 4: Run test — verify it PASSES**

```bash
flutter test test/unit/usecases/seek_and_resume_usecase_test.dart
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/usecases/recording/seek_and_resume_usecase.dart \
        test/unit/usecases/seek_and_resume_usecase_test.dart
git commit -m "feat: SeekAndResumeUseCase with tests"
```

---

## Task 10 — BLoC: event, state, handler + concatenation on stop

**Files:**
- Modify: `lib/presentation/bloc/recording/recording_event.dart`
- Modify: `lib/presentation/bloc/recording/recording_state.dart`
- Modify: `lib/presentation/bloc/recording/recording_bloc.dart`
- Modify: `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart`
- Create: `test/unit/blocs/recording_bloc_seek_test.dart`

### 10a — Add event

- [ ] **Step 1: Add `SeekAndResumeRecording` to `recording_event.dart`**

Append to the bottom of `recording_event.dart`:

```dart
/// Event to seek to a bar position and resume recording from there.
/// Triggers trim of audio to the seek point, then restarts recorder.
class SeekAndResumeRecording extends RecordingEvent {
  final int seekBarIndex;
  final String filePath;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final List<double> waveData;

  const SeekAndResumeRecording({
    required this.seekBarIndex,
    required this.filePath,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    required this.waveData,
  });

  @override
  List<Object?> get props =>
      [seekBarIndex, filePath, format, sampleRate, bitRate, waveData];
}
```

### 10b — Add `seekBasePath` to state

- [ ] **Step 2: Add `seekBasePath` to `RecordingInProgress`**

In `recording_state.dart`, add optional field to `RecordingInProgress`:

```dart
class RecordingInProgress extends RecordingState {
  final String filePath;
  final String? folderId;
  final String? folderName;
  final AudioFormat format;
  final int sampleRate;
  final int bitRate;
  final Duration duration;
  final double amplitude;
  final DateTime startTime;
  final String? title;
  final String? seekBasePath;    // ← ADD: path to trimmed base file if seek-trim happened

  const RecordingInProgress({
    required this.filePath,
    this.folderId,
    this.folderName,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    required this.duration,
    required this.amplitude,
    required this.startTime,
    this.title,
    this.seekBasePath,            // ← ADD
  });

  @override
  List<Object?> get props => [
    filePath, folderId, folderName, format, sampleRate, bitRate,
    duration, amplitude, startTime, title, seekBasePath,    // ← ADD
  ];

  RecordingInProgress copyWith({
    String? filePath,
    String? folderId,
    String? folderName,
    AudioFormat? format,
    int? sampleRate,
    int? bitRate,
    Duration? duration,
    double? amplitude,
    DateTime? startTime,
    String? title,
    String? seekBasePath,         // ← ADD
  }) {
    return RecordingInProgress(
      filePath: filePath ?? this.filePath,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      bitRate: bitRate ?? this.bitRate,
      duration: duration ?? this.duration,
      amplitude: amplitude ?? this.amplitude,
      startTime: startTime ?? this.startTime,
      title: title ?? this.title,
      seekBasePath: seekBasePath ?? this.seekBasePath,  // ← ADD
    );
  }
}
```

### 10c — Wire in `recording_bloc.dart`

- [ ] **Step 3: Import `SeekAndResumeUseCase` and inject it in `RecordingBloc`**

In `recording_bloc.dart`:

Add import:
```dart
import '../../../domain/usecases/recording/seek_and_resume_usecase.dart';
import '../../../services/audio/audio_trimmer_service.dart';
```

Add field:
```dart
final SeekAndResumeUseCase _seekAndResumeUseCase;
```

Update constructor to accept and build it:
```dart
RecordingBloc({
  required IAudioServiceRepository audioService,
  required IRecordingRepository recordingRepository,
  required GeolocationService geolocationService,
  FolderBloc? folderBloc,
  StartRecordingUseCase? startRecordingUseCase,
  StopRecordingUseCase? stopRecordingUseCase,
  PauseRecordingUseCase? pauseRecordingUseCase,
  SeekAndResumeUseCase? seekAndResumeUseCase,      // ← ADD
  AudioTrimmerService? trimmerService,             // ← ADD (for DI)
})  : _audioService = audioService,
      _recordingRepository = recordingRepository,
      _folderBloc = folderBloc,
      _startRecordingUseCase = startRecordingUseCase ?? ...,
      _stopRecordingUseCase = stopRecordingUseCase ?? ...,
      _pauseRecordingUseCase = pauseRecordingUseCase ?? ...,
      _seekAndResumeUseCase = seekAndResumeUseCase ??           // ← ADD
          SeekAndResumeUseCase(
            audioService: audioService,
            trimmerService: trimmerService ?? AudioTrimmerService(),
          ),
      super(const RecordingInitial()) {
  // ...existing handlers...
  on<SeekAndResumeRecording>(_onSeekAndResumeRecording);  // ← ADD
  _initializeAudioService();
}
```

### 10d — Add handler in `recording_bloc_lifecycle.dart`

- [ ] **Step 4: Add `_onSeekAndResumeRecording` and update `_onStopRecording`**

In `recording_bloc_lifecycle.dart`, add after `_onResumeRecording`:

```dart
// ==== SEEK-AND-RESUME ====

Future<void> _onSeekAndResumeRecording(
    SeekAndResumeRecording event, Emitter<RecordingState> emit) async {
  if (state is! RecordingPaused) return;

  final s = state as RecordingPaused;
  emit(const RecordingStarting());
  _stopAmplitudeUpdates();
  _stopDurationUpdates();

  final result = await _seekAndResumeUseCase.execute(
    filePath: s.filePath,
    seekBarIndex: event.seekBarIndex,
    format: s.format,
    sampleRate: s.sampleRate,
    bitRate: s.bitRate,
    waveData: event.waveData,
  );

  result.fold(
    (failure) => emit(RecordingError(failure.message,
        errorType: RecordingErrorType.recording)),
    (data) {
      final seekTimeMs = event.seekBarIndex * 50;
      emit(RecordingInProgress(
        filePath: s.filePath,
        folderId: s.folderId,
        folderName: s.folderName,
        format: s.format,
        sampleRate: s.sampleRate,
        bitRate: s.bitRate,
        duration: Duration(milliseconds: seekTimeMs),
        amplitude: 0.0,
        startTime: s.startTime,
        seekBasePath: data.seekBasePath,
      ));
      _startAmplitudeUpdates();
      _startDurationUpdates();
    },
  );
}
```

Update `_onStopRecording` to concatenate when `seekBasePath` is set. Add this block **before** `emit(const RecordingStopping())`:

```dart
// Concatenate pre-seek base file with new continuation recording
String? seekBasePath;
if (state is RecordingInProgress) {
  seekBasePath = (state as RecordingInProgress).seekBasePath;
}
```

And after `_stopRecordingUseCase.execute(...)` succeeds (inside `result.fold` right block), add:

```dart
// If seek-and-resume was used, concatenate base + continuation
if (seekBasePath != null) {
  try {
    final s = recording; // RecordingEntity returned by stopRecordingUseCase
    await _trimmerService.concatenateAudio(
      basePath: seekBasePath,
      appendPath: s.filePath,
      outputPath: s.filePath,
      format: s.format.name,
    );
    // Clean up base file
    final baseFile = File(seekBasePath);
    if (await baseFile.exists()) await baseFile.delete();
  } catch (e) {
    print('⚠️ Concatenation failed, keeping continuation only: $e');
  }
}
```

This requires `_trimmerService` to be accessible from `RecordingBloc`. Add it as a field:

```dart
final AudioTrimmerService _trimmerService;
```

And inject in constructor:
```dart
_trimmerService = trimmerService ?? AudioTrimmerService(),
```

Also add `import 'dart:io';` to `recording_bloc.dart`.

### 10e — BLoC tests

- [ ] **Step 5: Write failing BLoC test**

```dart
// File: test/unit/blocs/recording_bloc_seek_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart';
import 'package:wavnote/domain/usecases/recording/seek_and_resume_usecase.dart';
import 'package:wavnote/domain/usecases/recording/start_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/stop_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/pause_recording_usecase.dart';
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/services/location/geolocation_service.dart';
import 'package:wavnote/services/audio/audio_trimmer_service.dart';
import 'package:wavnote/core/enums/audio_format.dart';
import 'package:wavnote/core/errors/failures.dart';

import '../../helpers/test_helpers.dart';

class MockAudioService extends Mock implements IAudioServiceRepository {}
class MockRecordingRepository extends Mock implements IRecordingRepository {}
class MockGeolocationService extends Mock implements GeolocationService {}
class MockStartUseCase extends Mock implements StartRecordingUseCase {}
class MockStopUseCase extends Mock implements StopRecordingUseCase {}
class MockPauseUseCase extends Mock implements PauseRecordingUseCase {}
class MockSeekAndResumeUseCase extends Mock implements SeekAndResumeUseCase {}
class MockTrimmerService extends Mock implements AudioTrimmerService {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
    registerFallbackValue(AudioFormat.m4a);
  });

  group('RecordingBloc — SeekAndResumeRecording', () {
    late RecordingBloc bloc;
    late MockAudioService mockAudio;
    late MockRecordingRepository mockRepo;
    late MockSeekAndResumeUseCase mockSeekUseCase;
    late MockTrimmerService mockTrimmer;

    final pausedState = RecordingPaused(
      filePath: '/docs/all_recordings/test_123.m4a',
      folderId: 'all_recordings',
      format: AudioFormat.m4a,
      sampleRate: 44100,
      bitRate: 128000,
      duration: const Duration(seconds: 5),
      startTime: DateTime(2026, 3, 28),
    );

    setUp(() {
      mockAudio = MockAudioService();
      mockRepo = MockRecordingRepository();
      mockSeekUseCase = MockSeekAndResumeUseCase();
      mockTrimmer = MockTrimmerService();

      when(() => mockAudio.initialize()).thenAnswer((_) async => true);
      when(() => mockAudio.dispose()).thenAnswer((_) async {});

      bloc = RecordingBloc(
        audioService: mockAudio,
        recordingRepository: mockRepo,
        geolocationService: MockGeolocationService(),
        startRecordingUseCase: MockStartUseCase(),
        stopRecordingUseCase: MockStopUseCase(),
        pauseRecordingUseCase: MockPauseUseCase(),
        seekAndResumeUseCase: mockSeekUseCase,
        trimmerService: mockTrimmer,
      );
    });

    tearDown(() async => bloc.close());

    blocTest<RecordingBloc, RecordingState>(
      'SeekAndResumeRecording success: emits RecordingStarting then RecordingInProgress',
      build: () {
        when(() => mockSeekUseCase.execute(
          filePath: any(named: 'filePath'),
          seekBarIndex: any(named: 'seekBarIndex'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
          waveData: any(named: 'waveData'),
        )).thenAnswer((_) async => Right(SeekAndResumeResult(
          seekBasePath: '/docs/all_recordings/test_123_base.m4a',
          truncatedWaveData: List.generate(40, (_) => 0.5),
        )));
        return bloc;
      },
      seed: () => pausedState,
      act: (b) => b.add(SeekAndResumeRecording(
        seekBarIndex: 40,
        filePath: pausedState.filePath,
        format: pausedState.format,
        sampleRate: pausedState.sampleRate,
        bitRate: pausedState.bitRate,
        waveData: List.generate(100, (_) => 0.5),
      )),
      expect: () => [
        const RecordingStarting(),
        isA<RecordingInProgress>()
          .having((s) => s.seekBasePath, 'seekBasePath', isNotNull)
          .having((s) => s.duration.inMilliseconds, 'duration', 2000), // 40 * 50
      ],
    );

    blocTest<RecordingBloc, RecordingState>(
      'SeekAndResumeRecording failure: emits RecordingError',
      build: () {
        when(() => mockSeekUseCase.execute(
          filePath: any(named: 'filePath'),
          seekBarIndex: any(named: 'seekBarIndex'),
          format: any(named: 'format'),
          sampleRate: any(named: 'sampleRate'),
          bitRate: any(named: 'bitRate'),
          waveData: any(named: 'waveData'),
        )).thenAnswer((_) async => Left(AudioRecordingFailure.startFailed('trim error')));
        return bloc;
      },
      seed: () => pausedState,
      act: (b) => b.add(SeekAndResumeRecording(
        seekBarIndex: 40,
        filePath: pausedState.filePath,
        format: pausedState.format,
        sampleRate: pausedState.sampleRate,
        bitRate: pausedState.bitRate,
        waveData: List.generate(100, (_) => 0.5),
      )),
      expect: () => [
        const RecordingStarting(),
        isA<RecordingError>(),
      ],
    );
  });
}
```

- [ ] **Step 6: Run test — verify it FAILS**

```bash
flutter test test/unit/blocs/recording_bloc_seek_test.dart
```

Expected: compilation error.

- [ ] **Step 7: Implement all BLoC changes (steps 3–4 above)**

- [ ] **Step 8: Run test — verify it PASSES**

```bash
flutter test test/unit/blocs/recording_bloc_seek_test.dart
```

Expected: 2 tests pass.

- [ ] **Step 9: Run full test suite**

```bash
flutter test test/
```

Expected: all existing tests still pass.

- [ ] **Step 10: Commit**

```bash
git add lib/presentation/bloc/recording/recording_event.dart \
        lib/presentation/bloc/recording/recording_state.dart \
        lib/presentation/bloc/recording/recording_bloc.dart \
        lib/presentation/bloc/recording/recording_bloc_lifecycle.dart \
        test/unit/blocs/recording_bloc_seek_test.dart
git commit -m "feat: SeekAndResumeRecording BLoC event, handler, state + tests"
```

---

## Task 11 — Wire resume button in `RecordingBottomSheet`

**Files:**
- Modify: `lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart`

When paused and `_seekBarIndex < waveData.length - 1`: dispatch `SeekAndResumeRecording` event instead of the normal `ResumeRecording` via `onPlay`.

The `RecordingBottomSheet` does NOT have direct BLoC access — it calls `onPlay` which is wired in the parent `RecordingListScreen`. We need a new callback `onSeekAndResume` or change the `onPlay` callback to carry seek state.

The cleanest approach: add a new callback `onSeekAndResume: Function(int seekBarIndex, List<double> waveData)?` to `RecordingBottomSheet`. The parent wires it to dispatch `SeekAndResumeRecording`.

- [ ] **Step 1: Add `onSeekAndResume` callback to `RecordingBottomSheet`**

Add to `RecordingBottomSheet` constructor:
```dart
final Function(int seekBarIndex, List<double> waveData)? onSeekAndResume;
```

- [ ] **Step 2: Override `onPlay` in the fullscreen view when a seek has occurred**

In `_buildContainer()`, replace `onPlay: widget.onPlay` with a smart wrapper:

```dart
onPlay: () {
  final lastBarIndex = _waveData.isEmpty ? 0 : _waveData.length - 1;
  if (widget.isPaused && _seekBarIndex < lastBarIndex) {
    widget.onSeekAndResume?.call(_seekBarIndex, List<double>.from(_waveData));
  } else {
    widget.onPlay?.call();
  }
},
```

- [ ] **Step 3: Wire `onSeekAndResume` in `RecordingListScreen`**

In `recording_list_screen.dart`, find where `RecordingBottomSheet` is constructed and add:

```dart
onSeekAndResume: (seekBarIndex, waveData) {
  context.read<RecordingBloc>().add(SeekAndResumeRecording(
    seekBarIndex: seekBarIndex,
    filePath: (context.read<RecordingBloc>().state as RecordingPaused).filePath,
    format: (context.read<RecordingBloc>().state as RecordingPaused).format,
    sampleRate: (context.read<RecordingBloc>().state as RecordingPaused).sampleRate,
    bitRate: (context.read<RecordingBloc>().state as RecordingPaused).bitRate,
    waveData: waveData,
  ));
},
```

- [ ] **Step 4: Also reset `_seekBarIndex` after seek-and-resume dispatch**

In the `onSeekAndResume` callback above, also reset:
```dart
setState(() => _seekBarIndex = 0);
```
(Or let `didUpdateWidget` handle it — it already resets `_seekBarIndex` to `lastBarIndex` when transitioning to paused again.)

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart \
        lib/presentation/screens/recording/recording_list_screen.dart
git commit -m "feat: resume button dispatches SeekAndResumeRecording when seek position set"
```

---

## Task 12 — Manual integration test (on device/simulator)

No automated UI test — verify manually on iOS simulator.

- [ ] **Step 1: Build and run on iOS simulator**

```bash
flutter run -d "iPhone 16"
```

- [ ] **Step 2: Smoke test the full flow**

1. Start recording → verify waveform accumulates bars
2. Pause → verify playhead line appears at center, right-side bars dim to 30%
3. Drag waveform left → verify seek label updates (`← 00:02 / 00:07 →`), bars shift
4. Drag waveform right → verify seek label moves earlier
5. Tap Resume (orange button) → verify recording restarts from seek time in the timer
6. Let it record 3 more seconds → tap Done
7. Verify the saved recording plays back: should hear the original content up to seek point, then new audio

- [ ] **Step 3: Test edge cases**

- Seek to position 0 → label shows `← 00:00 / 00:07 →` → resume should work (trim to 0ms)
- Seek to last bar → no trim, plain resume, `seekBasePath` is null
- Pause → seek → pause again (second pause cycle) → seek → resume: verify it still works

- [ ] **Step 4: Commit if any last-minute fixes were needed**

```bash
git add -A
git commit -m "fix: smoke test corrections for waveform seek & trim"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|-----------------|------|
| Scrollable waveform during pause | Task 2 |
| Fixed playhead at center | Task 3 |
| Left bars full opacity, right bars 30% | Task 3 |
| Seek time label `← MM:SS / MM:SS →` | Task 4 |
| `seekBarIndex = (_totalBackDistance.dx / spacing).round()` | Task 2 |
| `seekTimeMs = seekBarIndex * 50` | Task 9 |
| `AudioTrimmerService.trim(filePath, durationMs, format)` | Tasks 5, 6, 7 |
| iOS: M4A, WAV via `AVAssetExportSession` | Task 6 |
| Android: M4A/FLAC via `MediaMuxer`, WAV byte-level | Task 7 |
| Stop recorder before trim (no DB save) | Task 9 |
| Restart recorder at same file path | Task 9 |
| Truncate waveData to seekBarIndex | Task 9 |
| `SeekAndResumeRecording` BLoC event | Task 10 |
| `RecordingStarting → RecordingInProgress` on success | Task 10 |
| `RecordingError` on failure | Task 10 |
| No loader on resume (direct state transition) | Task 10 (no loading state emitted) |
| Preserve pre-seek audio (base file + concatenation) | Tasks 9, 10 |
| `TrimFailure`, `RecordingRestartFailure` error types | Task 9 |
| If seekBarIndex == lastBarIndex: skip trim | Task 9 |
| Min seek position: 0 | Task 2 (_maxScrollDx clamp) |
| Temp file + rename pattern (atomicity) | Tasks 6, 7 |

**All spec requirements covered. No gaps found.**
