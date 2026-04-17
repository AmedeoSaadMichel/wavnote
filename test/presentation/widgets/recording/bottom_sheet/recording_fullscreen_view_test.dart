import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart';
import 'package:wavnote/presentation/widgets/recording/custom_waveform/flutter_sound_waveform.dart';

void main() {
  group('RecordingFullscreenView Widget Tests', () {
    testWidgets(
      'RecordingWaveform gets a new ValueKey when sessionCounter changes, preventing state recycling',
      (WidgetTester tester) async {
        // Helper per costruire la UI in modo pulito nel test
        Widget buildTestView({required int sessionCounter}) {
          return MaterialApp(
            home: Scaffold(
              body: RecordingFullscreenView(
                title: 'Test Recording',
                elapsed: Duration.zero,
                isRecording: true,
                amplitude: 0.0,
                waveData: const [],
                onToggle: () {},
                pulseAnimation: const AlwaysStoppedAnimation(1.0),
                sessionCounter: sessionCounter,
              ),
            ),
          );
        }

        // --- 1. PRIMA REGISTRAZIONE ---
        await tester.pumpWidget(buildTestView(sessionCounter: 0));

        // Trova il widget della waveform nell'albero
        final waveformFinder1 = find.byType(RecordingWaveform);
        expect(waveformFinder1, findsOneWidget);

        // Estrai l'istanza e verifica che la sua chiave sia ValueKey(0)
        RecordingWaveform waveformWidget = tester.widget(waveformFinder1);
        expect(
          waveformWidget.key,
          equals(const ValueKey<int>(0)),
          reason: 'La waveform deve usare sessionCounter come ValueKey',
        );

        // --- 2. SECONDA REGISTRAZIONE ---
        // Simuliamo l'utente che preme Stop e poi di nuovo Start (nuovo contatore)
        await tester.pumpWidget(buildTestView(sessionCounter: 1));

        // Trova di nuovo la waveform dopo l'aggiornamento
        final waveformFinder2 = find.byType(RecordingWaveform);
        expect(waveformFinder2, findsOneWidget);

        // Estrai la nuova istanza e verifica che la chiave SIA CAMBIATA
        waveformWidget = tester.widget(waveformFinder2);
        expect(
          waveformWidget.key,
          equals(const ValueKey<int>(1)),
          reason:
              'La chiave deve aggiornarsi con il nuovo sessionCounter per forzare Flutter a distruggere il vecchio widget (bug fix stato residuo)',
        );

        // Verifica esplicita che la vecchia chiave e la nuova siano diverse
        expect(const ValueKey<int>(0) != const ValueKey<int>(1), isTrue);
      },
    );
  });
}
