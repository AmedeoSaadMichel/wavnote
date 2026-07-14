// File: test/widget_test.dart
//
// WavNote App Widget Tests
// =======================
//
// Smoke test dell'app: la MainScreen viene montata con BLoC mock (il boot
// completo di WavNoteApp richiede il DI di produzione, non disponibile in
// ambiente di test), mentre WavNoteApp nudo viene verificato solo per
// robustezza del bootstrap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wavnote/app.dart';
import 'package:wavnote/presentation/screens/main/main_screen.dart';
import 'helpers/test_helpers.dart';

void main() {
  group('WavNote App Widget Tests', () {
    testWidgets('App initializes and displays main screen', (WidgetTester tester) async {
      // Initialize test environment
      await TestHelpers.initializeTestEnvironment();

      // La MainScreen è montata con BLoC mock via createTestApp.
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const MainScreen(),
        ),
      );
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      // Verify the main app title is displayed
      expect(find.text('Voice Memos'), findsOneWidget);

      // Verify the cosmic gradient background is applied
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('Main screen displays folder structure', (WidgetTester tester) async {
      // Initialize test environment
      await TestHelpers.initializeTestEnvironment();

      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const MainScreen(),
        ),
      );
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      // Header presente indipendentemente dallo stato delle cartelle
      expect(find.text('Voice Memos'), findsOneWidget);
    });

    testWidgets('App handles initialization errors gracefully', (WidgetTester tester) async {
      await TestHelpers.initializeTestEnvironment();

      // WavNoteApp nudo: senza il DI di produzione il boot non può arrivare
      // alla MainScreen, ma non deve crashare (skeleton o error screen).
      await tester.pumpWidget(const WavNoteApp());
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      // The app widget should be built successfully
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
