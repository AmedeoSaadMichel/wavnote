import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wavnote/config/dependency_injection.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart';
import 'package:wavnote/presentation/bloc/folder/folder_bloc.dart';
import 'package:wavnote/presentation/widgets/common/shared_audio_import_listener.dart';
import 'package:wavnote/services/file/voice_memo_import_service.dart';

class _RecordingBloc extends MockBloc<RecordingEvent, RecordingState>
    implements RecordingBloc {}

class _FolderBloc extends MockBloc<FolderEvent, FolderState>
    implements FolderBloc {}

class _Repository extends Mock implements IRecordingRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    sl.registerSingleton<IRecordingRepository>(_Repository());
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await sl.unregister<IRecordingRepository>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(VoiceMemoImportService.channel, null);
  });

  testWidgets(
    'cold launch and resume defer shared imports until recording is idle',
    (tester) async {
      final states = StreamController<RecordingState>.broadcast();
      final recordingBloc = _RecordingBloc();
      final folderBloc = _FolderBloc();
      whenListen(
        recordingBloc,
        states.stream,
        initialState: const RecordingStarting(),
      );
      when(() => folderBloc.state).thenReturn(const FolderInitial());
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VoiceMemoImportService.channel, (
            call,
          ) async {
            calls.add(call);
            return <dynamic>[];
          });
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Library')),
          ),
        ],
      );
      final messenger = GlobalKey<ScaffoldMessengerState>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<RecordingBloc>.value(value: recordingBloc),
            BlocProvider<FolderBloc>.value(value: folderBloc),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            scaffoldMessengerKey: messenger,
            builder: (_, child) => SharedAudioImportListener(
              router: router,
              messengerKey: messenger,
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      states.add(const RecordingInitial());
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), ['pendingSharedAudio']);
      states.add(const RecordingStarting());
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls.length, 1);
      states.add(const RecordingInitial());
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await states.close();
      await recordingBloc.close();
      await folderBloc.close();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
