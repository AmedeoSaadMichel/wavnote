import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/presentation/widgets/dialogs/voice_memo_import_dialog.dart';
import 'package:wavnote/services/file/voice_memo_import_service.dart';
import '../../helpers/test_helpers.dart';

class _Repository extends Mock implements IRecordingRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(VoiceMemoImportService.channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(VoiceMemoImportService.channel, null);
  });
  Future<void> showGuide(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => VoiceMemoImportDialog(
                  folder: TestHelpers.createTestFolder(),
                  service: VoiceMemoImportService(_Repository()),
                ),
              ),
              child: const Text('Importa'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Importa'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'iPhone guide explains sharing multiple memos and fallback opening',
    (tester) async {
      await showGuide(tester);
      expect(find.textContaining('Condividi e scegli WavNote'), findsOneWidget);
      expect(find.textContaining('Tutte le registrazioni'), findsOneWidget);
      expect(find.textContaining('schermata Home'), findsOneWidget);
      expect(find.text('Apri Memo Vocali'), findsNothing);
      expect(calls, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
