// File: test/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_trim_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart';
import 'package:wavnote/presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart';
import 'package:wavnote/presentation/widgets/recording/custom_waveform/recorder_wave_painter.dart';

void main() {
  testWidgets(
    'seek resume preserves previous bars and colors across overwrites',
    (tester) async {
      Future<void> update({
        bool recording = false,
        bool paused = false,
        bool starting = false,
        int elapsedMs = 0,
        int session = 0,
        double amplitude = 0.7,
        List<double>? truncated,
        List<double>? full,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  RecordingBottomSheet(
                    title: 'Test',
                    isRecording: recording,
                    isPaused: paused,
                    isStarting: starting,
                    isOverwrite: truncated != null,
                    elapsed: Duration(milliseconds: elapsedMs),
                    amplitude: amplitude,
                    sessionCounter: session,
                    width: 800,
                    onToggle: () {},
                    truncatedWaveData: truncated,
                    fullWaveData: full,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
      }

      RecordingFullscreenView view() =>
          tester.widget(find.byType(RecordingFullscreenView).last);

      await update(recording: true);
      await update(recording: true, elapsedMs: 1000, amplitude: 0.8);
      await update(paused: true, elapsedMs: 1000);
      final waveformState = tester.state(find.byType(RecordingWaveform).last);
      final original = List<double>.of(view().waveData);
      expect(original, hasLength(10));
      expect(original, everyElement(0.8));

      // Il resume riceve la stessa lista posseduta dal bottom sheet.
      final sharedWaveData = view().waveData;
      await update(starting: true);
      final firstTrim = original.take(4).toList();
      await update(recording: true, truncated: firstTrim, full: sharedWaveData);
      expect(view().waveData, original);
      expect(view().waveSegments, List.filled(10, 0));
      expect(view().futureBarsCount, 6);
      expect(
        tester.state(find.byType(RecordingWaveform).last),
        same(waveformState),
      );

      await update(recording: true, elapsedMs: 200, truncated: firstTrim);
      expect(view().waveData.take(4), original.take(4));
      expect(view().waveSegments, [0, 0, 0, 0, 1, 1, 0, 0, 0, 0]);
      await update(paused: true, elapsedMs: 200, truncated: firstTrim);
      final beforeSecondTrim = List<double>.of(view().waveData);
      await update(starting: true, truncated: firstTrim);
      final secondTrim = beforeSecondTrim.take(2).toList();
      await update(
        recording: true,
        truncated: secondTrim,
        // La schermata non passa fullWaveData nei trim successivi.
        full: null,
      );
      expect(view().waveData, beforeSecondTrim);
      expect(view().waveSegments, [0, 0, 0, 0, 1, 1, 0, 0, 0, 0]);
      await update(recording: true, elapsedMs: 100, truncated: secondTrim);
      expect(view().waveSegments, [0, 0, 2, 0, 1, 1, 0, 0, 0, 0]);
      // Una nuova sessione deve comunque azzerare la waveform precedente.
      await update(session: 1);
      await update(recording: true, session: 1);
      await update(recording: true, session: 1, elapsedMs: 100, amplitude: 0.4);
      await update(paused: true, session: 1, elapsedMs: 100);
      expect(view().waveData, [0.4]);
      expect(view().waveSegments, [0]);
      expect(view().futureBarsCount, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final verificaTitolo in [false, true]) {
    testWidgets(
      verificaTitolo
          ? 'il trim conserva il titolo durante RecordingStarting'
          : 'il trim conserva geometria e playhead nei frame intermedi',
      (tester) async {
        Future<void> aggiorna({
          bool recording = false,
          bool paused = false,
          bool starting = false,
          int elapsedMs = 0,
          int? seek,
          List<double>? truncated,
          String title = 'La mia registrazione',
        }) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    RecordingBottomSheet(
                      title: title,
                      isRecording: recording,
                      isPaused: paused,
                      isStarting: starting,
                      isOverwrite: truncated != null,
                      elapsed: Duration(milliseconds: elapsedMs),
                      amplitude: elapsedMs > 0 ? 0.8 : 0.0,
                      width: 800,
                      onToggle: () {},
                      blocSeekBarIndex: seek,
                      truncatedWaveData: truncated,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        Finder onda() => find.byType(RecordingWaveform).last;
        CustomRecorderWavePainter painter() => tester
            .widgetList<CustomPaint>(
              find.descendant(of: onda(), matching: find.byType(CustomPaint)),
            )
            .map((widget) => widget.painter)
            .whereType<CustomRecorderWavePainter>()
            .single;

        await aggiorna(recording: true);
        await aggiorna(recording: true, elapsedMs: 2000);
        await aggiorna(paused: true, elapsedMs: 2000);
        await tester.pump(const Duration(milliseconds: 600));
        await aggiorna(paused: true, elapsedMs: 2000, seek: 9);
        final geometria = tester.getRect(onda());
        final offset = painter().totalBackDistance;
        final stato = tester.state(onda());
        final barre = List<double>.of(painter().waveData);

        // Parametri realmente passati dalla schermata in RecordingStarting:
        // niente titolo, durata, seek o nuova truncatedWaveData dal BLoC.
        await aggiorna(starting: true, title: 'New Recording');
        for (final ms in [16, 150, 400]) {
          await tester.pump(Duration(milliseconds: ms));
          if (verificaTitolo) {
            expect(find.text('La mia registrazione'), findsOneWidget);
            expect(find.text('New Recording'), findsNothing);
          } else {
            expect(tester.getRect(onda()), geometria);
            expect(painter().totalBackDistance, offset);
            expect(painter().waveData, barre);
            expect(tester.state(onda()), same(stato));
          }
        }
        await aggiorna(recording: true, truncated: barre.take(10).toList());
        for (final ms in [16, 150, 400]) {
          await tester.pump(Duration(milliseconds: ms));
          if (!verificaTitolo) {
            expect(tester.getRect(onda()), geometria);
            expect(painter().totalBackDistance, offset);
            expect(painter().waveData, barre);
            expect(tester.state(onda()), same(stato));
          }
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
