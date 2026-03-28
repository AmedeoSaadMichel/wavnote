# Waveform Seek & Trim on Pause — Design Spec

**Date:** 2026-03-28
**Status:** Approved

---

## Overview

When a recording is paused, the user can scroll the waveform horizontally to select any point in the recording. Tapping "Resume" trims the audio file to that point and continues recording from there, discarding everything after the selected position.

---

## Architecture

Four layers are involved:

```
UI (RecordingFullscreenView)
  ↓ scroll offset → seekBarIndex
RecordingBottomSheet
  ↓ SeekAndResumeRecording(seekBarIndex, filePath, waveData)
RecordingBlocLifecycle
  ↓
SeekAndResumeUseCase
  ├── AudioTrimmerService.trim(filePath, durationMs, format)
  ├── AudioRecorderService.stopRecording()  [no DB save]
  ├── AudioRecorderService.startRecording() [same file path]
  └── waveData truncated to seekBarIndex items
```

### New files
| File | Responsibility |
|------|---------------|
| `lib/services/audio/audio_trimmer_service.dart` | Flutter-side platform channel wrapper |
| `lib/domain/usecases/recording/seek_and_resume_usecase.dart` | Orchestrates trim + restart |
| `ios/Runner/AudioTrimmerPlugin.swift` | Native iOS trim (AVAssetExportSession) |
| `android/app/src/main/kotlin/.../AudioTrimmerPlugin.kt` | Native Android trim (MediaExtractor + MediaMuxer) |

### Modified files
| File | Change |
|------|--------|
| `lib/presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart` | Enable manual drag scroll when paused; expose seek bar index |
| `lib/presentation/widgets/recording/custom_waveform/recorder_wave_painter.dart` | Draw playhead line + left/right bar opacity split |
| `lib/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart` | Wire drag → scroll, show seek time label, trigger SeekAndResume on resume tap |
| `lib/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart` | Track `_seekBarIndex`, pass to BLoC on resume |
| `lib/domain/usecases/recording/pause_recording_usecase.dart` | No change |
| `lib/presentation/bloc/recording/recording_event.dart` | Add `SeekAndResumeRecording` event |
| `lib/presentation/bloc/recording/recording_bloc_lifecycle.dart` | Add `_onSeekAndResumeRecording` handler |

---

## UI Behaviour

### Paused state — waveform interaction
- A fixed vertical cyan/white line (playhead) is rendered at the horizontal center of the waveform
- The user drags the waveform left/right; `_totalBackDistance` updates manually (same mechanism as auto-scroll during recording)
- Bars to the **left** of the playhead: full opacity (already recorded, will be kept)
- Bars to the **right** of the playhead: reduced opacity (~0.3) (will be discarded)
- A small time label updates in real-time below the playhead: `"← 00:03 / 00:07 →"` showing seek position / total duration

### Seek position calculation
```
seekBarIndex = (_totalBackDistance.dx / spacing).round()
seekTimeMs   = seekBarIndex * 50   // 50ms per amplitude sample
```

### Resume flow (no loader)
1. User taps the orange Resume button while waveform is in paused+scrolled state
2. `RecordingBottomSheet` dispatches `SeekAndResumeRecording(seekBarIndex, filePath, waveData)`
3. BLoC transitions directly `RecordingPaused → RecordingStarting → RecordingInProgress`
4. `_waveData` is truncated to `seekBarIndex` items — waveform visually jumps to the cut point

---

## SeekAndResumeUseCase

**Location:** `lib/domain/usecases/recording/seek_and_resume_usecase.dart`

**Signature:**
```dart
Future<Either<Failure, void>> execute({
  required String filePath,
  required int seekBarIndex,
  required AudioFormat format,
  required List<double> waveData,
})
```

**Steps:**
1. `trimDurationMs = seekBarIndex * 50`
2. `AudioRecorderService.stopRecording()` — flushes the file, does NOT save to DB
3. `AudioTrimmerService.trim(filePath, trimDurationMs, format)`
4. Truncate `waveData` to `seekBarIndex` (passed back to BLoC via return value)
5. `AudioRecorderService.startRecording(filePath, format)` — resumes on same file

**Return:** `Either<Failure, List<double>>` — trimmed waveData on success

**Error cases:**
- `TrimFailure` — native trim failed (file locked, unsupported format)
- `RecordingRestartFailure` — could not restart recorder after trim

---

## AudioTrimmerService

**Location:** `lib/services/audio/audio_trimmer_service.dart`

**Channel name:** `wavnote/audio_trimmer`

**Method:** `trimAudio`
```dart
await _channel.invokeMethod('trimAudio', {
  'filePath': filePath,       // absolute path
  'durationMs': durationMs,   // trim to this many ms from start
  'format': format.name,      // 'wav', 'm4a', 'flac'
});
```

Both native implementations:
1. Export/extract from `0` to `durationMs` into a temp file
2. Delete original
3. Rename temp file to original path

---

## Native Implementations

### iOS — `AudioTrimmerPlugin.swift`

| Format | Strategy |
|--------|----------|
| M4A | `AVAssetExportSession` → `AVFileTypeAppleM4A` |
| WAV | `AVAssetExportSession` → `AVFileTypeWAVE` |
| FLAC | `AVAssetExportSession` → `AVFileTypeWAVE` (lossless, renames extension) |

`AVAssetExportSession.timeRange = CMTimeRange(start: .zero, duration: CMTime(value: durationMs, timescale: 1000))`

### Android — `AudioTrimmerPlugin.kt`

| Format | Strategy |
|--------|----------|
| M4A/AAC | `MediaExtractor` + `MediaMuxer` (MPEG_4 container) |
| FLAC | `MediaExtractor` + `MediaMuxer` (FLAC supported API 21+) |
| WAV | Byte-level truncation: calculate PCM frame offset, truncate file, update RIFF header size |

Both use temp file + rename pattern for atomicity.

---

## BLoC Changes

### New event (`recording_event.dart`)
```dart
class SeekAndResumeRecording extends RecordingEvent {
  final int seekBarIndex;
  final String filePath;
  final AudioFormat format;
  final List<double> waveData;
}
```

### New handler (`recording_bloc_lifecycle.dart`)
- On `SeekAndResumeRecording`:
  - Emit `RecordingStarting`
  - Call `SeekAndResumeUseCase.execute(...)`
  - On success: emit `RecordingInProgress` with truncated waveData, restart amplitude/duration streams
  - On failure: emit `RecordingError`

---

## Error Handling

All failures follow the existing `Either<Failure, T>` pattern.

| Failure | Cause | UI result |
|---------|-------|-----------|
| `TrimFailure` | Native trim failed | `RecordingError` state, recording stays paused |
| `RecordingRestartFailure` | Could not restart after trim | `RecordingError` state |

On error, the original file is left untouched (trim uses temp file pattern).

---

## Constraints

- Minimum seek position: bar index 0 (start of recording) — cannot seek before start
- Maximum seek position: last bar index (end of recording) — equivalent to normal resume
- If `seekBarIndex == lastBarIndex` (no scroll): skip trim entirely, call normal `resumeRecording()`
- WAV files on Android: RIFF header update must set `ChunkSize` and `Subchunk2Size` correctly
