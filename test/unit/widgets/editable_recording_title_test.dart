// File: test/unit/widgets/editable_recording_title_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_compact_view.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart';

void main() {
  for (final fullscreen in [false, true]) {
    testWidgets('tap titolo durante registrazione, vista fullscreen=$fullscreen', (tester) async {
      var title = 'Registrazione iniziale';
      var toggles = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
        builder: (context, setState) {
          void rename(String name) => setState(() => title = name);
          return fullscreen
              ? RecordingFullscreenView(title: title, onTitleChanged: rename,
                  elapsed: const Duration(seconds: 30), isRecording: true,
                  amplitude: 0, waveData: const [], onToggle: () => toggles++,
                  pulseAnimation: const AlwaysStoppedAnimation(1))
              : RecordingCompactView(title: title, onTitleChanged: rename,
                  elapsed: const Duration(seconds: 30), isRecording: true,
                  amplitude: 0, waveData: const [], onToggle: () => toggles++,
                  pulseAnimation: const AlwaysStoppedAnimation(1));
        },
      ))));
      await tester.tap(find.text(title));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text, title);
      await tester.enterText(find.byType(TextFormField), ' ');
      await tester.tap(find.text('Salva'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Titolo da annullare');
      await tester.tap(find.text('Annulla'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Registrazione iniziale'), findsOneWidget);
      await tester.tap(find.text(title));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(find.byType(TextFormField), '  Titolo scelto  ');
      await tester.tap(find.text('Salva'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Titolo scelto'), findsOneWidget);
      expect(toggles, 0, reason: 'La modifica del titolo non pausa né ferma la registrazione');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
