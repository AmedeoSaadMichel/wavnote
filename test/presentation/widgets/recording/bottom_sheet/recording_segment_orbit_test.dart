import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wavnote/services/audio/segment_playback_controller.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavnote/core/enums/audio_format.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/domain/entities/recording_session_segment.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_segment_orbit.dart';
import 'package:wavnote/presentation/widgets/recording/custom_waveform/recorder_wave_painter.dart';

List<RecordingSessionSegment> segments(int count) => List.generate(
  count,
  (i) => RecordingSessionSegment(
    sourcePath: 'take$i.wav',
    colorIndex: i,
    recording: RecordingEntity(
      id: 'session-segment-$i',
      name: 'Segmento ${i + 1}',
      filePath: '/tmp/take$i.wav',
      folderId: 'all_recordings',
      format: AudioFormat.wav,
      duration: Duration(seconds: i + 12),
      fileSize: 1000,
      sampleRate: 44100,
      createdAt: DateTime(2026),
      waveformData: List.generate(60, (j) => (j % 9) / 9),
    ),
  ),
);

void main() {
  testWidgets('only the active segment waveform follows the playback clock', (
    tester,
  ) async {
    final items = segments(2);
    final playback = ValueNotifier<Map<String, SegmentPlaybackState>>(const {});
    addTearDown(playback.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingSegmentOrbit(
            segments: items,
            playback: playback,
            onPlay: (_) async {},
            onSave: (_) async {},
            onClose: () {},
          ),
        ),
      ),
    );
    playback.value = {
      items[0].recording.id: const SegmentPlaybackState(
        isPlaying: true,
        position: Duration(milliseconds: 1500),
      ),
    };
    await tester.pump();
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SegmentWaveformPainter>()
        .toList();
    expect(painters[0].position, const Duration(milliseconds: 1500));
    expect(painters[0].playheadSample, 15);
    expect(painters[1].position, Duration.zero);
    playback.value = {
      items[0].recording.id: const SegmentPlaybackState(
        isPlaying: true,
        position: Duration(seconds: 2),
      ),
      items[1].recording.id: const SegmentPlaybackState(
        isPlaying: true,
        position: Duration(milliseconds: 500),
      ),
    };
    await tester.pump();
    final advanced = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SegmentWaveformPainter>()
        .first;
    expect(advanced.playheadSample, 20);
    expect(advanced.shouldRepaint(painters[0]), isTrue);
    final simultaneous = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SegmentWaveformPainter>()
        .toList();
    expect(simultaneous[1].playheadSample, 5);
    expect(find.byTooltip('Ferma segmento 1'), findsOneWidget);
    expect(find.byTooltip('Ferma segmento 2'), findsOneWidget);
  });

  testWidgets(
    'pages through more than four segments and keeps original colors',
    (tester) async {
      final items = segments(9);
      RecordingSessionSegment? played;
      RecordingSessionSegment? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordingSegmentOrbit(
              segments: items,
              onPlay: (s) async => played = s,
              onSave: (s) async => saved = s,
              onClose: () {},
            ),
          ),
        ),
      );
      expect(find.text('1–4 di 9'), findsOneWidget);
      expect(find.text('Segmento 5'), findsNothing);
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<SegmentWaveformPainter>()
          .toList();
      expect(painters.map((p) => p.color), [
        for (var i = 0; i < 4; i++) CustomRecorderWavePainter.segmentColor(i),
      ]);
      expect(painters[3].color, const Color(0xFFFFD54F));
      await tester.tap(find.byTooltip('Ascolta segmento 2'));
      await tester.pumpAndSettle();
      expect(played, items[1]);
      await tester.tap(find.byTooltip('Salva segmento 2'));
      await tester.pumpAndSettle();
      expect(saved, items[1]);
      expect(find.byTooltip('Segmento salvato'), findsOneWidget);
      await tester.tap(find.byTooltip('Segmenti successivi'));
      await tester.pumpAndSettle();
      expect(find.text('5–8 di 9'), findsOneWidget);
      await tester.drag(
        find.byType(RecordingSegmentOrbit),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('9–9 di 9'), findsOneWidget);
      expect(find.text('Segmento 9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only paused expanded view shows the button and closes on resume',
    (tester) async {
      var stopped = 0;
      Widget view(bool paused) => MaterialApp(
        home: Scaffold(
          body: RecordingFullscreenView(
            title: 'New Recording',
            elapsed: const Duration(seconds: 25),
            isRecording: !paused,
            isPaused: paused,
            amplitude: 0,
            waveData: List.filled(30, .5),
            onToggle: () {},
            pulseAnimation: const AlwaysStoppedAnimation(1),
            sessionSegments: segments(2),
            onPlaySegment: (_) async {},
            onSaveSegment: (_) async {},
            onStopSegment: () async {
              stopped++;
            },
          ),
        ),
      );
      await tester.pumpWidget(view(false));
      expect(find.byTooltip('Segmenti (2)'), findsNothing);
      await tester.pumpWidget(view(true));
      await tester.tap(find.byTooltip('Segmenti (2)'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordingSegmentOrbit), findsOneWidget);
      expect(stopped, 1);
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      expect(find.byType(RecordingSegmentOrbit), findsNothing);
      expect(stopped, 2);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('orbit fits $size without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8E2DE2),
                      Color(0xFFDA22FF),
                      Color(0xFFFF4E50),
                    ],
                  ),
                ),
                child: RecordingSegmentOrbit(
                  segments: segments(12),
                  onPlay: (_) async {},
                  onSave: (_) async {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width == 390 && const bool.fromEnvironment('SEGMENT_PREVIEW')) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/wavnote-segments-preview.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
