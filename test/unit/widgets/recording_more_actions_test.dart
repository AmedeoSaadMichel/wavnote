// File: test/unit/widgets/recording_more_actions_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavnote/presentation/widgets/recording/recording_more_actions.dart';
import 'package:wavnote/services/file/recording_file_actions_service.dart';
import '../../helpers/test_helpers.dart';

void main() {
  const channel = MethodChannel('wavnote/file_actions');
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  final recording = TestHelpers.createTestRecording(
    filePath: '/documents/audio.m4a',
  );
  Future<void> open(
    WidgetTester tester, {
    ValueChanged<String>? onRename,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRecordingMoreActions(
                context,
                recording,
                fileActions: RecordingFileActionsService(),
                onRename: onRename ?? (_) {},
              ),
              child: const Text('Azioni'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Azioni'));
    await tester.pumpAndSettle();
  }

  testWidgets('menu iPhone con rinomina, File e condivisione', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await open(tester);
    expect(find.text('Rinomina'), findsOneWidget);
    expect(find.text('Mostra file'), findsOneWidget);
    expect(find.text('Condividi'), findsOneWidget);
    await tester.tap(find.text('Mostra file'));
    await tester.pumpAndSettle();
    expect(calls.single.method, 'reveal');
    expect(calls.single.arguments, {'path': recording.filePath});
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('Finder su macOS e condivisione del file reale', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await open(tester);
    expect(find.text('Mostra nel Finder'), findsOneWidget);
    await tester.tap(find.text('Condividi'));
    await tester.pumpAndSettle();
    expect(calls.single.method, 'share');
    expect(calls.single.arguments, {'path': recording.filePath});
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'rinomina valida invia il nome ripulito; nome vuoto resta nel dialogo',
    (tester) async {
      String? renamed;
      await open(tester, onRename: (name) => renamed = name);
      await tester.tap(find.text('Rinomina'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), ' ');
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      expect(renamed, isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '  Nome nuovo  ');
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      expect(renamed, 'Nome nuovo');
      expect(calls, isEmpty);
    },
  );
  testWidgets('annullare la rinomina non salva', (tester) async {
    String? renamed;
    await open(tester, onRename: (name) => renamed = name);
    await tester.tap(find.text('Rinomina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(renamed, isNull);
  });
  testWidgets('file mancante mostra errore recuperabile', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(
            code: 'FILE_NOT_FOUND',
            message: 'File non disponibile',
          ),
        );
    await open(tester);
    await tester.tap(find.text('Condividi'));
    await tester.pumpAndSettle();
    expect(find.text('File non disponibile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
