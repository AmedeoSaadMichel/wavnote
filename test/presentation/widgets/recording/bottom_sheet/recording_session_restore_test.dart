import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavnote/domain/entities/recording_session_view_snapshot.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_compact_view.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart';

void main() {
  testWidgets(
    'folder recreation preserves compact pause, waveform colors and next trim identity',
    (tester) async {
      RecordingSessionViewSnapshot? snapshot = RecordingSessionViewSnapshot(
        waveData: [.2, .3, .8, .7, .4, .2],
        waveSegments: [0, 0, 1, 1, 0, 0],
        segmentColors: {'first': 0, 'second': 1},
        currentSegment: 1,
        overwriteCount: 1,
        seekBarIndex: 3,
        seekVersion: 1,
        futureBarsCount: 0,
        seekTimeOffsetMs: 0,
        consumedSampleCount: 0,
        sheetOffset: 0,
        hasPausedInSession: true,
      );
      Future<void> show({
        bool paused = true,
        List<double>? trimmed,
        int ms = 600,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  RecordingBottomSheet(
                    title: 'Sessione conservata',
                    isRecording: !paused,
                    isPaused: paused,
                    isOverwrite: trimmed != null,
                    elapsed: Duration(milliseconds: ms),
                    amplitude: .6,
                    width: 800,
                    onToggle: () {},
                    viewSnapshot: snapshot,
                    onViewSnapshotChanged: (value) => snapshot = value,
                    truncatedWaveData: trimmed,
                    blocSeekBarIndex: paused ? 3 : null,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
      }

      await show();
      final before = tester.widget<RecordingCompactView>(
        find.byType(RecordingCompactView),
      );
      expect(before.isPaused, true);
      expect(before.seekBarIndex, 3);
      final originalWave = List<double>.of(before.waveData);
      final originalColors = List<int>.of(before.waveSegments);
      await tester.pumpWidget(const SizedBox()); // leave the folder
      expect(snapshot!.sheetOffset, 0);
      expect(snapshot!.segmentColors, {'first': 0, 'second': 1});
      await show(); // return to the folder
      final after = tester.widget<RecordingCompactView>(
        find.byType(RecordingCompactView),
      );
      expect(find.byType(RecordingFullscreenView), findsNothing);
      expect(after.isPaused, true);
      expect(after.waveData, originalWave);
      expect(after.waveSegments, originalColors);
      expect(after.seekBarIndex, 3);
      final trim = originalWave.take(2).toList();
      await show(paused: false, trimmed: trim, ms: 0);
      await show(paused: false, trimmed: trim, ms: 100);
      final resumed = tester.widget<RecordingCompactView>(
        find.byType(RecordingCompactView),
      );
      expect(
        resumed.waveSegments[2],
        2,
      ); // no color counter reset after navigation
      await tester.pumpWidget(const SizedBox());
    },
  );
}
