// File: test/unit/widgets/recording_bottom_sheet_calibration_test.dart
//
// Test della calibrazione waveform al primo tick dopo avvio/resume.
//
// Problema originale: il motore nativo parte prima che il BLoC emetta
// isRecording=true. Al primo tick del timer Dart (100ms dopo l'avvio),
// widget.elapsed è già a ~300ms. Senza calibrazione:
//   _seekTimeOffsetMs=500 (5 barre), elapsed=300 → expectedBars=(500+300)/100=8
//   → 3 barre aggiunte di colpo invece di 0.
//
// Soluzione: al primo tick, _needsCalibration ricalcola _seekTimeOffsetMs
// in modo che expectedBars == _waveData.length. Il tick successivo aggiunge
// esattamente 1 barra.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_bottom_sheet_main.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_compact_view.dart';
import 'package:wavnote/presentation/widgets/recording/bottom_sheet/recording_fullscreen_view.dart';

/// Legge waveData dall'unica vista attiva (fullscreen o compact).
List<double> _getWaveData(WidgetTester tester) {
  final fs = find.byType(RecordingFullscreenView);
  if (fs.evaluate().isNotEmpty) {
    return tester.widget<RecordingFullscreenView>(fs).waveData;
  }
  return tester
      .widget<RecordingCompactView>(find.byType(RecordingCompactView))
      .waveData;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────────────────────
  // Test puri: formula di calibrazione (nessun widget)
  // ─────────────────────────────────────────────────────────────────
  group('Formula di calibrazione — test puri', () {
    /// Simula un singolo ciclo: calibrazione + N tick successivi.
    /// Verifica che al primo tick non vengano aggiunte barre e che
    /// ogni tick successivo ne aggiunga esattamente 1.
    void verifyCalibration({
      required int waveDataLength,
      required int elapsedAtFirstTickMs,
      int tickDeltaMs = 100,
      int extraTicks = 2,
    }) {
      // Calibrazione (esattamente come in _syncWaveformToElapsedTime)
      final calibratedOffset = waveDataLength * 100 - elapsedAtFirstTickMs;
      final elapsedMs = elapsedAtFirstTickMs + calibratedOffset;
      final expectedBarsFirst = (elapsedMs / 100).floor();

      expect(
        expectedBarsFirst,
        equals(waveDataLength),
        reason: 'waveDataLength=$waveDataLength, elapsed=${elapsedAtFirstTickMs}ms '
            '→ calibratedOffset=$calibratedOffset, expectedBars=$expectedBarsFirst (deve essere $waveDataLength)',
      );

      // Tick successivi: ciascuno deve aggiungere esattamente 1 barra
      for (int n = 1; n <= extraTicks; n++) {
        final nextElapsedMs = elapsedAtFirstTickMs + n * tickDeltaMs;
        final nextExpected = ((nextElapsedMs + calibratedOffset) / 100).floor();
        expect(
          nextExpected,
          equals(waveDataLength + n),
          reason: 'Tick #$n dopo calibrazione: waveDataLength=${waveDataLength + n} atteso',
        );
      }
    }

    test('nuova registrazione (0 barre): elapsed 0ms al primo tick', () {
      verifyCalibration(waveDataLength: 0, elapsedAtFirstTickMs: 0);
    });

    test('nuova registrazione (0 barre): elapsed 100ms al primo tick', () {
      verifyCalibration(waveDataLength: 0, elapsedAtFirstTickMs: 100);
    });

    test('nuova registrazione (0 barre): elapsed 300ms al primo tick', () {
      verifyCalibration(waveDataLength: 0, elapsedAtFirstTickMs: 300);
    });

    test('resume semplice (5 barre): elapsed 300ms al primo tick', () {
      verifyCalibration(waveDataLength: 5, elapsedAtFirstTickMs: 300);
    });

    test('resume semplice (77 barre): elapsed 200ms al primo tick', () {
      verifyCalibration(waveDataLength: 77, elapsedAtFirstTickMs: 200);
    });

    test('resume semplice (77 barre): elapsed 300ms al primo tick', () {
      verifyCalibration(waveDataLength: 77, elapsedAtFirstTickMs: 300);
    });

    test('resume semplice (77 barre): elapsed 400ms al primo tick', () {
      verifyCalibration(waveDataLength: 77, elapsedAtFirstTickMs: 400);
    });

    test('seek-and-resume (50 barre su 85): elapsed 200ms al primo tick', () {
      verifyCalibration(waveDataLength: 50, elapsedAtFirstTickMs: 200);
    });

    test('seek-and-resume (50 barre su 85): elapsed 300ms al primo tick', () {
      verifyCalibration(waveDataLength: 50, elapsedAtFirstTickMs: 300);
    });

    test('comportamento SENZA calibrazione: documenta il salto di barre', () {
      // Questo test documenta il bug originale per confronto storico.
      // Senza calibrazione _seekTimeOffsetMs = waveDataLength * 100 fisso.
      const waveDataLength = 5;
      const seekTimeOffsetMs = 500; // = 5 * 100
      const elapsedAtFirstTick = 300;

      final expectedBarsWithoutCalibration =
          ((elapsedAtFirstTick + seekTimeOffsetMs) / 100).floor();
      final barJump = expectedBarsWithoutCalibration - waveDataLength;

      // Senza calibrazione: 3 barre aggiunte di colpo
      expect(barJump, equals(3),
          reason: 'Il bug originale causava un salto di 3 barre al primo tick');
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Test widget: verifica il comportamento end-to-end sul widget reale
  //
  // Pattern "safe tick": per ogni avanzamento temporale fare sempre
  //   setOuter(() => elapsed = ...);
  //   await tester.pump();            // 1. flush rebuild → widget ha il nuovo elapsed
  //   await tester.pump(100ms);       // 2. avanza clock → timer legge elapsed aggiornato
  //
  // Senza il pump() intermedio il timer fire può leggere l'elapsed precedente.
  // ─────────────────────────────────────────────────────────────────
  group('RecordingBottomSheet — calibrazione waveform (widget test)', () {
    /// Costruisce lo scaffold minimo con uno StatefulBuilder che espone
    /// [setOuter] per controllare isRec/isPaused/elapsed dall'esterno.
    Future<void> buildSheet(
      WidgetTester tester, {
      required void Function(StateSetter) onSetState,
      required bool Function() isRec,
      required bool Function() isPaused,
      required Duration Function() elapsed,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              StatefulBuilder(
                builder: (ctx, ss) {
                  onSetState(ss);
                  return RecordingBottomSheet(
                    title: 'Test',
                    isRecording: isRec(),
                    isPaused: isPaused(),
                    elapsed: elapsed(),
                    amplitude: 0.5,
                    width: 400,
                    onToggle: () {},
                  );
                },
              ),
            ],
          ),
        ),
      ));
    }

    /// Safe tick: aggiorna elapsed, flush rebuild, poi avanza il clock.
    Future<void> safeTick(
      WidgetTester tester,
      StateSetter setOuter,
      Duration newElapsed,
    ) async {
      setOuter(() {}); // cattura il setter (no-op, già catturato nella closure)
      await tester.pump(); // flush rebuild con elapsed già aggiornato
      await tester.pump(const Duration(milliseconds: 100)); // timer fire
    }

    testWidgets(
      'nuova registrazione: elapsed già a 300ms → 0 barre al primo tick, 1 al secondo',
      (tester) async {
        late StateSetter setOuter;
        bool isRec = false;
        Duration elapsed = Duration.zero;

        await buildSheet(
          tester,
          onSetState: (ss) => setOuter = ss,
          isRec: () => isRec,
          isPaused: () => false,
          elapsed: () => elapsed,
        );

        // Avvia registrazione
        setOuter(() => isRec = true);
        await tester.pump(); // didUpdateWidget → _startWaveformTimer, _needsCalibration=true

        // Tick 1: elapsed già a 300ms (ritardo nativo) → calibrazione → 0 barre
        setOuter(() => elapsed = const Duration(milliseconds: 300));
        await tester.pump(); // flush rebuild (widget.elapsed=300ms)
        await tester.pump(const Duration(milliseconds: 100)); // timer fire → CALIBRATION

        expect(
          _getWaveData(tester).length,
          equals(0),
          reason: 'Primo tick: calibrazione → nessuna barra aggiunta',
        );

        // Tick 2: elapsed=400ms → exactamente 1 barra
        setOuter(() => elapsed = const Duration(milliseconds: 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          _getWaveData(tester).length,
          equals(1),
          reason: 'Secondo tick: esattamente 1 barra aggiunta',
        );

        // Tick 3: elapsed=500ms → 2 barre totali
        setOuter(() => elapsed = const Duration(milliseconds: 500));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          _getWaveData(tester).length,
          equals(2),
          reason: 'Terzo tick: 2 barre totali',
        );
      },
    );

    testWidgets(
      'resume da pausa: elapsed 300ms → nessun salto al primo tick, +1 al secondo',
      (tester) async {
        late StateSetter setOuter;
        bool isRec = false;
        bool isPaused = false;
        Duration elapsed = Duration.zero;

        await buildSheet(
          tester,
          onSetState: (ss) => setOuter = ss,
          isRec: () => isRec,
          isPaused: () => isPaused,
          elapsed: () => elapsed,
        );

        // ── Fase 1: accumula barre (tick senza ritardo nativo) ────
        setOuter(() => isRec = true);
        await tester.pump(); // _startWaveformTimer, _needsCalibration=true

        // Tick 1 calibrazione (elapsed=0ms → offset=0, expectedBars=0)
        await tester.pump(const Duration(milliseconds: 100));

        // Tick 2–4: 3 barre reali (elapsed avanza da 100 a 300ms senza ritardo)
        for (int i = 1; i <= 3; i++) {
          setOuter(() => elapsed = Duration(milliseconds: i * 100));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }
        // Totale: 3 barre (offset=0 da calibrazione, elapsed 100→300 → 3 barre)
        final barsAfterRecording = _getWaveData(tester).length;
        expect(barsAfterRecording, equals(3),
            reason: 'Devono esserci 3 barre dopo 3 tick reali');

        // ── Fase 2: pausa ─────────────────────────────────────────
        setOuter(() {
          isRec = false;
          isPaused = true;
          elapsed = const Duration(milliseconds: 300);
        });
        await tester.pump();
        final barsBeforeResume = _getWaveData(tester).length;

        // ── Fase 3: resume con elapsed già a 300ms ────────────────
        // Bug originale: _seekTimeOffsetMs=300 fisso → expectedBars=(300+300)/100=6 → +3 barre
        // Con calibrazione: offset=3*100-300=0, expectedBars=(300+0)/100=3 → +0 barre ✓
        setOuter(() {
          isRec = true;
          isPaused = false;
          elapsed = const Duration(milliseconds: 300);
        });
        await tester.pump(); // _startWaveformTimer, _needsCalibration=true

        // Primo tick post-resume
        await tester.pump(); // flush
        await tester.pump(const Duration(milliseconds: 100)); // timer → calibrazione

        expect(
          _getWaveData(tester).length,
          equals(barsBeforeResume),
          reason:
              'Primo tick post-resume: nessun salto (rimane $barsBeforeResume barre)',
        );

        // Secondo tick: elapsed=400ms → +1 barra
        setOuter(() => elapsed = const Duration(milliseconds: 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          _getWaveData(tester).length,
          equals(barsBeforeResume + 1),
          reason: 'Secondo tick post-resume: +1 barra',
        );
      },
    );

    testWidgets(
      'tick consecutivi: ogni tick (dopo calibrazione) aggiunge esattamente 1 barra',
      (tester) async {
        late StateSetter setOuter;
        bool isRec = false;
        Duration elapsed = Duration.zero;

        await buildSheet(
          tester,
          onSetState: (ss) => setOuter = ss,
          isRec: () => isRec,
          isPaused: () => false,
          elapsed: () => elapsed,
        );

        setOuter(() => isRec = true);
        await tester.pump(); // _needsCalibration=true

        // Tick 1 (calibrazione con elapsed=200ms): 0 barre aggiunte
        setOuter(() => elapsed = const Duration(milliseconds: 200));
        await tester.pump(); // flush rebuild
        await tester.pump(const Duration(milliseconds: 100)); // CALIBRATION

        expect(_getWaveData(tester).length, equals(0),
            reason: 'Primo tick: calibrazione → 0 barre');

        // Tick 2–5: ciascuno deve aggiungere esattamente 1 barra
        for (int n = 1; n <= 4; n++) {
          setOuter(() => elapsed = Duration(milliseconds: 200 + n * 100));
          await tester.pump(); // flush rebuild
          await tester.pump(const Duration(milliseconds: 100)); // timer fire
          expect(
            _getWaveData(tester).length,
            equals(n),
            reason: 'Tick ${n + 1}: attese $n barre totali',
          );
        }
      },
    );
  });
}
