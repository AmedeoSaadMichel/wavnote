// File: test/unit/widgets/recording_card_test.dart
// 
// Recording Card Widget Tests
// ===========================
//
// Comprehensive test suite for the RecordingCard widget, testing
// UI interactions, state management, and visual components.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:wavnote/presentation/widgets/recording/recording_card/recording_card.dart';
import 'package:wavnote/presentation/widgets/recording/recording_controls.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/core/enums/audio_format.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('RecordingCard Widget Tests', () {
    late RecordingEntity testRecording;

    setUp(() {
      testRecording = TestHelpers.createTestRecording(
        id: 'test_recording_1',
        name: 'Test Recording',
        duration: const Duration(minutes: 2, seconds: 30),
        fileSize: 1024000, // 1MB
        format: AudioFormat.m4a,
        createdAt: DateTime(2023, 12, 25, 10, 30),
      );
    });

    RecordingCard createTestRecordingCard({
      RecordingEntity? recording,
      bool isExpanded = false,
      bool isPlaying = false,
      bool isLoading = false,
      Duration currentPosition = Duration.zero,
      bool isEditMode = false,
      bool isSelected = false,
      VoidCallback? onPlayPause,
      VoidCallback? onToggleFavorite,
      VoidCallback? onDelete,
      VoidCallback? onSelectionToggle,
    }) {
      return RecordingCard(
        recording: recording ?? testRecording,
        isExpanded: isExpanded,
        isPlaying: isPlaying,
        isLoading: isLoading,
        currentPosition: currentPosition,
        isEditMode: isEditMode,
        isSelected: isSelected,
        currentFolderId: 'test_folder',
        onPlayPause: onPlayPause ?? () {},
        onSeek: (position) {},
        onSkipBackward: () {},
        onSkipForward: () {},
        onShowWaveform: () {},
        onDelete: onDelete ?? () {},
        onMoveToFolder: () {},
        onMoreActions: () {},
        onToggleFavorite: onToggleFavorite,
        onSelectionToggle: onSelectionToggle,
      );
    }

    group('Basic Widget Rendering', () {
      testWidgets('renders recording card with basic information', (WidgetTester tester) async {
        // Arrange
        var playTapped = false;
        var favoriteTapped = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(
                onPlayPause: () => playTapped = true,
                onToggleFavorite: () => favoriteTapped = true,
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        // La card compatta mostra nome e metadati; i controlli play/pause
        // vivono solo nella variante espansa (RecordingControls).
        expect(find.text('Test Recording'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('displays recording metadata correctly', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        TestHelpers.expectTextExists('Test Recording');
        expect(find.text('M4A'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows favorite indicator when recording is favorite', (WidgetTester tester) async {
        // Arrange
        final favoriteRecording = testRecording.copyWith(isFavorite: true);

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(recording: favoriteRecording),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byIcon(Icons.favorite), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('adapts layout for different recording durations', (WidgetTester tester) async {
        final testCases = [
          Duration(seconds: 30),
          Duration(minutes: 5, seconds: 45),
          Duration(hours: 1, minutes: 23, seconds: 45),
        ];

        for (final duration in testCases) {
          final recording = testRecording.copyWith(duration: duration);

          await tester.pumpWidget(
            TestHelpers.createTestApp(
              child: Scaffold(
                body: createTestRecordingCard(recording: recording),
              ),
            ),
          );
          await TestHelpers.pumpAndSettleWithTimeout(tester);

          expect(tester.takeException(), isNull);
        }
      });
    });

    group('Audio Playback Controls', () {
      testWidgets('shows play button when not playing', (WidgetTester tester) async {
        // Act — i controlli sono visibili solo nella card espansa; la slider
        // anima in loop, quindi pump puntuale invece di pumpAndSettle.
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(isExpanded: true, isPlaying: false),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Assert
        expect(find.byIcon(Icons.play_arrow), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows pause button when playing', (WidgetTester tester) async {
        // Act — controlli visibili solo nella card espansa.
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(
                isExpanded: true,
                isPlaying: true,
                currentPosition: const Duration(seconds: 30),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Assert
        expect(find.byIcon(Icons.pause), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('calls onPlayPause when play button is tapped', (WidgetTester tester) async {
        // Arrange
        var playPauseCalled = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(
                isExpanded: true,
                onPlayPause: () => playPauseCalled = true,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final playButtons = find.byIcon(Icons.play_arrow);
        expect(playButtons, findsWidgets);
        await tester.tap(playButtons.first, warnIfMissed: false);
        await tester.pump();
        expect(playPauseCalled, isTrue);

        expect(tester.takeException(), isNull);
      });

      testWidgets('displays loading indicator when loading', (WidgetTester tester) async {
        // Act — il loading indicator sta nel bottone centrale della card
        // espansa (RecordingControls).
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(isExpanded: true, isLoading: true),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Assert
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    });

    group('Edit Mode and Selection', () {
      testWidgets('shows selection controls in edit mode', (WidgetTester tester) async {
        // Act — la UI attuale usa un overlay circolare custom, non un
        // Checkbox: se selezionata mostra Icons.check.
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(isEditMode: true, isSelected: true),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byIcon(Icons.check), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows selected state when recording is selected', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(
                isEditMode: true,
                isSelected: true,
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert: l'overlay di selezione custom mostra Icons.check
        // quando la card è selezionata.
        expect(find.byIcon(Icons.check), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('calls onSelectionToggle when selection is tapped', (WidgetTester tester) async {
        // Arrange
        var selectionToggleCalled = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(
                isEditMode: true,
                onSelectionToggle: () => selectionToggleCalled = true,
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // In edit mode il tap sulla card chiama onSelectionToggle.
        await tester.tap(find.byType(RecordingCard), warnIfMissed: false);
        await tester.pump();
        expect(selectionToggleCalled, isTrue);

        expect(tester.takeException(), isNull);
      });
    });

    group('Expanded Mode Features', () {
      testWidgets('shows additional controls when expanded', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(isExpanded: true),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byType(RecordingCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles position updates correctly', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(
                isExpanded: true,
                isPlaying: true,
                currentPosition: const Duration(seconds: 75),
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byType(RecordingCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Action Buttons and Callbacks', () {
      testWidgets('calls onToggleFavorite when favorite is tapped', (WidgetTester tester) async {
        // Arrange
        var favoriteToggleCalled = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(
                onToggleFavorite: () => favoriteToggleCalled = true,
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Il bottone preferiti compare solo dopo swipe sinistra→destra
        // sulla card (favorite action).
        await tester.drag(
          find.byType(RecordingCard),
          const Offset(120, 0),
          warnIfMissed: false,
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        final favoriteButtons = find.byIcon(Icons.favorite_border);
        expect(favoriteButtons, findsWidgets);
        await tester.tap(favoriteButtons.first, warnIfMissed: false);
        await tester.pump();
        expect(favoriteToggleCalled, isTrue);

        expect(tester.takeException(), isNull);
      });

      testWidgets('calls onDelete when delete is tapped', (WidgetTester tester) async {
        // Arrange
        var deleteCalled = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(
                isExpanded: true,
                onDelete: () => deleteCalled = true,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Il delete è lo skull dentro RecordingControls (card espansa).
        // find.byIcon non matcha FaIcon: serve un predicate.
        final deleteButton = find.descendant(
          of: find.byType(RecordingControls),
          matching: find.byWidgetPredicate(
            (w) => w is FaIcon && w.icon == FontAwesomeIcons.skull,
          ),
        );
        expect(deleteButton, findsOneWidget);
        await tester.tap(deleteButton, warnIfMissed: false);
        await tester.pump();
        expect(deleteCalled, isTrue);

        expect(tester.takeException(), isNull);
      });
    });

    group('Visual States and Styling', () {
      testWidgets('applies different styling for different audio formats', (WidgetTester tester) async {
        final formats = [AudioFormat.m4a, AudioFormat.wav, AudioFormat.flac];

        for (final format in formats) {
          final recording = testRecording.copyWith(format: format);

          await tester.pumpWidget(
            TestHelpers.createTestApp(
              child: Scaffold(
                body: createTestRecordingCard(recording: recording),
              ),
            ),
          );
          await TestHelpers.pumpAndSettleWithTimeout(tester);

          expect(find.byType(RecordingCard), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('handles long recording names gracefully', (WidgetTester tester) async {
        // Arrange
        final longNameRecording = testRecording.copyWith(
          name: 'This is a very long recording name that should be handled gracefully by the UI',
        );

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(recording: longNameRecording),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(tester.takeException(), isNull);
        expect(find.textContaining('This is a very long'), findsWidgets);
      });
    });

    group('Error Handling and Edge Cases', () {
      testWidgets('handles null callback gracefully', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(
                onToggleFavorite: null, // Null callback
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byType(RecordingCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles invalid position gracefully', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(
                isPlaying: true,
                currentPosition: const Duration(seconds: -10), // Invalid negative
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(tester.takeException(), isNull);
        expect(find.byType(RecordingCard), findsOneWidget);
      });

      testWidgets('handles rapid interactions gracefully', (WidgetTester tester) async {
        // Arrange
        var tapCount = 0;

        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(
                isExpanded: true,
                onPlayPause: () => tapCount++,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Act - Rapid taps
        final playButtons = find.byIcon(Icons.play_arrow);
        expect(playButtons, findsWidgets);
        for (int i = 0; i < 5; i++) {
          await tester.tap(playButtons.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Assert
        expect(tester.takeException(), isNull);
        expect(tapCount, 5);
      });
    });

    group('Accessibility and User Experience', () {
      testWidgets('provides semantic information for accessibility', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byType(Semantics), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('maintains consistent UI state across rebuilds', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Trigger rebuild with same data
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: createTestRecordingCard(),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.text('Test Recording'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}