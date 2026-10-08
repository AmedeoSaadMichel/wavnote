import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavnote/services/audio/segment_playback_controller.dart';
import '../../../test/presentation/widgets/recording/bottom_sheet/recording_segment_orbit_test.dart'
    show segments;

void main() {
  const channel = MethodChannel('com.wavnote/audio_engine');
  final calls = <MethodCall>[];
  var statuses = <String, dynamic>{};
  Completer<void>? pendingPlay;
  String? failingId;
  setUp(() {
    calls.clear();
    statuses = {};
    pendingPlay = null;
    failingId = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'playSegment') {
            if ((call.arguments as Map)['id'] == failingId) {
              throw PlatformException(code: 'PLAYBACK_ERROR');
            }
            await pendingPlay?.future;
          }
          if (call.method == 'segmentPlaybackStatus') return statuses;
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets('plays multiple segments and stops only the requested segment', (
    tester,
  ) async {
    final controller = SegmentPlaybackController(useNative: true);
    final items = segments(2);
    await controller.toggle(items[0]);
    await controller.toggle(items[1]);
    expect(
      controller.state.value.keys.toSet(),
      items.map((s) => s.recording.id).toSet(),
    );
    expect(calls.where((c) => c.method == 'stopSegment'), isEmpty);
    statuses = {
      items[0].recording.id: {'playing': true, 'positionMs': 1200},
      items[1].recording.id: {'playing': true, 'positionMs': 300},
    };
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      controller.state.value[items[0].recording.id]!.position,
      const Duration(milliseconds: 1200),
    );
    expect(
      controller.state.value[items[1].recording.id]!.position,
      const Duration(milliseconds: 300),
    );
    await controller.toggle(items[0]);
    expect(controller.state.value.keys, [items[1].recording.id]);
    await controller.dispose();
  });

  testWidgets('completion removes only the finished segment', (tester) async {
    final controller = SegmentPlaybackController(useNative: true);
    final items = segments(2);
    await controller.toggle(items[0]);
    await controller.toggle(items[1]);
    statuses = {
      items[0].recording.id: {'playing': false, 'positionMs': 0},
      items[1].recording.id: {'playing': true, 'positionMs': 500},
    };
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.state.value.keys, [items[1].recording.id]);
    await controller.dispose();
  });

  testWidgets('closing during load cannot restart playback afterward', (
    tester,
  ) async {
    final controller = SegmentPlaybackController(useNative: true);
    pendingPlay = Completer<void>();
    final start = controller.toggle(segments(1).first);
    await tester.pump();
    final stop = controller.stopAll();
    pendingPlay!.complete();
    await start;
    await stop;
    expect(controller.state.value, isEmpty);
    expect(calls.last.method, 'stopAllSegments');
    await controller.dispose();
  });

  testWidgets('a failed player leaves other segments playing', (tester) async {
    final controller = SegmentPlaybackController(useNative: true);
    final items = segments(2);
    await controller.toggle(items[0]);
    failingId = items[1].recording.id;
    await expectLater(
      controller.toggle(items[1]),
      throwsA(isA<PlatformException>()),
    );
    expect(controller.state.value.keys, [items[0].recording.id]);
    await controller.dispose();
  });
}
