import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_compact_view.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart';
import 'package:wavnote/presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart';

void main() {
  testWidgets(
    'compact review starts only after pause and resets next session',
    (tester) async {
      var done = 0;
      var pauses = 0;
      var previews = 0;
      Future<void> update({
        bool paused = false,
        int session = 0,
        bool preview = false,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  RecordingBottomSheet(
                    title: 'Test',
                    isRecording: !paused,
                    isPaused: paused,
                    elapsed: const Duration(seconds: 1),
                    amplitude: 0.5,
                    width: 800,
                    sessionCounter: session,
                    onToggle: () {},
                    isPlayingPreview: preview,
                    onPlayFromPosition: () => previews++,
                    onStopPreview: () => previews--,
                    onPause: () => pauses++,
                    onDone: () => done++,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 500));
      }

      await update();
      expect(
        tester
            .widget<RecordingCompactView>(find.byType(RecordingCompactView))
            .isReviewMode,
        isFalse,
      );
      expect(find.byTooltip('Done'), findsNothing);
      await update(paused: true);
      expect(find.byType(RecordingFullscreenView), findsOneWidget);
      await tester.drag(
        find.byType(RecordingFullscreenView),
        const Offset(0, 350),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RecordingCompactView), findsOneWidget);
      final waveform = tester.widget<RecordingWaveform>(
        find.byType(RecordingWaveform),
      );
      expect(waveform.isPaused, isTrue);
      expect(waveform.showPlayhead, isTrue);
      expect(waveform.onSeekBarIndexChanged, isNotNull);
      await tester.tap(find.byTooltip('Done'));
      expect(done, 1);
      await update();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      expect(pauses, 1);
      await update(paused: true);
      expect(find.byType(RecordingCompactView), findsOneWidget);
      expect(find.byType(RecordingFullscreenView), findsNothing);
      await tester.tap(find.byTooltip('Play preview'));
      expect(previews, 1);
      final playIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byTooltip('Play preview'),
          matching: find.byType(Icon),
        ),
      );
      expect(playIcon.color, Colors.cyan);
      expect(
        tester.getCenter(find.byTooltip('Play preview')).dx,
        greaterThan(tester.getCenter(find.byType(RecordingWaveform)).dx),
      );
      await update(paused: true, preview: true);
      expect(find.byTooltip('Pause preview'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byTooltip('Pause preview'),
          matching: find.byIcon(Icons.pause_rounded),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Pause preview'));
      expect(previews, 0);
      await update(session: 1);
      expect(find.byTooltip('Done'), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    },
  );
}
