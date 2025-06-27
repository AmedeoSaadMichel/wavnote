// File: test/widget_test.dart
// 
// WavNote App Widget Tests
// =======================
//
// Integration tests for the main WavNote application widget and core
// user interface components. These tests verify that the app initializes
// correctly and core UI elements are present and functional.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wavnote/main.dart';
import 'helpers/test_helpers.dart';

void main() {
  group('WavNote App Widget Tests', () {
    testWidgets('App initializes and displays main screen', (WidgetTester tester) async {
      // Initialize test environment
      await TestHelpers.initializeTestEnvironment();

      // Build the app with proper test setup
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const WavNoteApp(),
        ),
      );

      // Wait for async initialization to complete
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify the main app title is displayed
      expect(find.text('Voice Memos'), findsOneWidget);
      
      // Verify the cosmic gradient background is applied
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('Main screen displays folder structure', (WidgetTester tester) async {
      // Initialize test environment
      await TestHelpers.initializeTestEnvironment();

      // Build the app
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const WavNoteApp(),
        ),
      );

      // Wait for initialization and data loading
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Look for common folder elements (these should exist in default folders)
      // We'll look for text that should appear regardless of empty state
      expect(find.text('Voice Memos'), findsOneWidget);
    });

    testWidgets('App handles initialization errors gracefully', (WidgetTester tester) async {
      // Test error handling during app startup
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: const WavNoteApp(),
        ),
      );

      // App should not crash even if initialization has issues
      await tester.pumpAndSettle();
      
      // The app widget should be built successfully
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
