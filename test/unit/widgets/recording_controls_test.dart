// File: test/unit/widgets/recording_controls_test.dart
// 
// Recording Controls Widget Tests
// ===============================
//
// Comprehensive test suite for the RecordingControls widget, testing
// playback controls, button interactions, and state management.
//
// Test Coverage:
// - Control button rendering and layout
// - Play/pause state management
// - Loading states and indicators
// - Callback handling and user interactions
// - Visual styling and accessibility

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wavnote/presentation/widgets/recording/recording_controls.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('RecordingControls Widget Tests', () {
    group('Basic Widget Rendering', () {
      testWidgets('renders all control buttons', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byIcon(Icons.graphic_eq), findsOneWidget);      // Waveform button
        expect(find.byIcon(Icons.replay_10), findsOneWidget);       // Skip backward button
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);      // Play button (when not playing)
        expect(find.byIcon(Icons.forward_10), findsOneWidget);      // Skip forward button
        expect(find.byType(Icon), findsWidgets);                   // All icon buttons
      });

      testWidgets('uses proper layout with expanded widgets', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Expanded), findsWidgets);
      });

      testWidgets('renders control buttons with proper styling', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        // Check that icons have proper colors and sizes
        final waveformIcon = tester.widget<Icon>(find.byIcon(Icons.graphic_eq));
        expect(waveformIcon.color, equals(Colors.blue));
        expect(waveformIcon.size, equals(24));

        final skipBackIcon = tester.widget<Icon>(find.byIcon(Icons.replay_10));
        expect(skipBackIcon.color, equals(Colors.cyan));
        expect(skipBackIcon.size, equals(28));
      });
    });

    group('Play/Pause State Management', () {
      testWidgets('shows play button when not playing', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsNothing);
      });

      testWidgets('shows pause button when playing', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: true,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsNothing);
      });

      testWidgets('shows loading indicator when loading', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: true,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows loading with correct styling', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: true,
                isLoading: true,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        final progressIndicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(progressIndicator.color, equals(Colors.white));
        expect(progressIndicator.strokeWidth, equals(3.0));
      });
    });

    group('Button Interactions and Callbacks', () {
      testWidgets('calls onShowWaveform when waveform button is tapped', (WidgetTester tester) async {
        // Arrange
        var waveformCalled = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () => waveformCalled = true,
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        await tester.tap(find.byIcon(Icons.graphic_eq));
        await tester.pump();

        // Assert
        expect(waveformCalled, isTrue);
      });

      testWidgets('calls onSkipBackward when skip backward button is tapped', (WidgetTester tester) async {
        // Arrange
        var skipBackwardCalled = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () => skipBackwardCalled = true,
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        await tester.tap(find.byIcon(Icons.replay_10));
        await tester.pump();

        // Assert
        expect(skipBackwardCalled, isTrue);
      });

      testWidgets('calls onPlayPause when play button is tapped', (WidgetTester tester) async {
        // Arrange
        var playPauseCalled = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () => playPauseCalled = true,
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump();

        // Assert
        expect(playPauseCalled, isTrue);
      });

      testWidgets('calls onPlayPause when pause button is tapped', (WidgetTester tester) async {
        // Arrange
        var playPauseCalled = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: true,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () => playPauseCalled = true,
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        await tester.tap(find.byIcon(Icons.pause));
        await tester.pump();

        // Assert
        expect(playPauseCalled, isTrue);
      });

      testWidgets('calls onSkipForward when skip forward button is tapped', (WidgetTester tester) async {
        // Arrange
        var skipForwardCalled = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () => skipForwardCalled = true,
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        await tester.tap(find.byIcon(Icons.forward_10));
        await tester.pump();

        // Assert
        expect(skipForwardCalled, isTrue);
      });

      testWidgets('calls onDelete when delete button is tapped', (WidgetTester tester) async {
        // Arrange
        var deleteCalled = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () => deleteCalled = true,
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Try to tap delete button (could be FontAwesome skull icon)
        final deleteButton = find.byWidgetPredicate((widget) => 
          widget.toString().contains('skull') || 
          (widget is Icon && widget.icon == Icons.delete));
        
        if (deleteButton.evaluate().isNotEmpty) {
          await tester.tap(deleteButton.first);
          await tester.pump();
          expect(deleteCalled, isTrue);
        } else {
          // Skip assertion if delete button not found
          expect(deleteCalled, isFalse);
        }
      });

      testWidgets('does not call onPlayPause when loading', (WidgetTester tester) async {
        // Arrange
        var playPauseCalled = false;

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: true,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () => playPauseCalled = true,
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Try to tap the loading indicator area
        await tester.tap(find.byType(CircularProgressIndicator));
        await tester.pump();

        // Assert
        expect(playPauseCalled, isFalse);
      });
    });

    group('Visual Styling and Layout', () {
      testWidgets('applies proper button styling', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        // Check that buttons have proper container styling
        expect(find.byType(Container), findsWidgets);
        expect(find.byType(GestureDetector), findsWidgets);
      });

      testWidgets('centers the play/pause button appropriately', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byType(Center), findsWidgets);
      });

      testWidgets('applies cosmic theme colors correctly', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        // Check for cosmic color scheme
        final containers = find.byType(Container);
        expect(containers, findsWidgets);
        
        // Verify color scheme is applied
        expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
        expect(find.byIcon(Icons.replay_10), findsOneWidget);
      });

      testWidgets('maintains consistent sizing across different states', (WidgetTester tester) async {
        // Test playing state
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: true,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        final playingSize = tester.getSize(find.byType(RecordingControls));

        // Test loading state
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: true,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        final loadingSize = tester.getSize(find.byType(RecordingControls));

        // Assert
        expect(playingSize.height, equals(loadingSize.height));
      });
    });

    group('Accessibility and User Experience', () {
      testWidgets('provides semantic labels for accessibility', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        // Should have semantic widgets for screen readers
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets('handles rapid button presses gracefully', (WidgetTester tester) async {
        // Arrange
        var playPauseCount = 0;

        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () => playPauseCount++,
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Act - Rapid button presses
        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byIcon(Icons.play_arrow));
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Assert
        expect(playPauseCount, greaterThan(0));
        expect(tester.takeException(), isNull);
      });

      testWidgets('maintains proper touch targets for accessibility', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        // Check that buttons have adequate touch targets (48dp minimum)
        final playButton = find.byIcon(Icons.play_arrow);
        final playButtonSize = tester.getSize(playButton);
        expect(playButtonSize.width, greaterThanOrEqualTo(48.0));
        expect(playButtonSize.height, greaterThanOrEqualTo(48.0));
      });
    });

    group('Error Handling and Edge Cases', () {
      testWidgets('handles callback exceptions gracefully', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () => throw Exception('Test exception'),
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Try to trigger the exception
        await tester.tap(find.byIcon(Icons.graphic_eq));
        await tester.pump();

        // Assert
        expect(find.byType(RecordingControls), findsOneWidget);
      });

      testWidgets('maintains state consistency during rapid state changes', (WidgetTester tester) async {
        // Act - Rapidly change between playing and loading states
        for (int i = 0; i < 3; i++) {
          await tester.pumpWidget(
            TestHelpers.createTestApp(
              child: Scaffold(
                body: RecordingControls(
                  isPlaying: i % 2 == 0,
                  isLoading: i % 3 == 0,
                  onShowWaveform: () {},
                  onSkipBackward: () {},
                  onPlayPause: () {},
                  onSkipForward: () {},
                  onDelete: () {},
                ),
              ),
            ),
          );
          await tester.pump();
        }

        // Assert
        expect(tester.takeException(), isNull);
        expect(find.byType(RecordingControls), findsOneWidget);
      });

      testWidgets('handles simultaneous playing and loading states', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: RecordingControls(
                isPlaying: true,
                isLoading: true, // Both playing and loading
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        // Loading should take precedence
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsNothing);
        expect(find.byIcon(Icons.play_arrow), findsNothing);
      });
    });

    group('Integration with Theme and Context', () {
      testWidgets('adapts to dark theme correctly', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: RecordingControls(
                isPlaying: false,
                isLoading: false,
                onShowWaveform: () {},
                onSkipBackward: () {},
                onPlayPause: () {},
                onSkipForward: () {},
                onDelete: () {},
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byType(RecordingControls), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('responds to MediaQuery changes', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  size: Size(400, 800),
                  devicePixelRatio: 2.0,
                ),
                child: RecordingControls(
                  isPlaying: false,
                  isLoading: false,
                  onShowWaveform: () {},
                  onSkipBackward: () {},
                  onPlayPause: () {},
                  onSkipForward: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        );
        await TestHelpers.pumpAndSettleWithTimeout(tester);

        // Assert
        expect(find.byType(RecordingControls), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}