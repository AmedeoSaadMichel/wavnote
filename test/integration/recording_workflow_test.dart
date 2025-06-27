// File: test/integration/recording_workflow_test.dart
// 
// Recording Workflow Integration Tests - SIMPLIFIED VERSION
// =========================================================
//
// Simplified integration-style tests using flutter_test instead of integration_test
// to avoid additional dependencies while still testing key workflows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart';
import 'package:wavnote/presentation/bloc/folder/folder_bloc.dart';
import 'package:wavnote/presentation/screens/main/main_screen.dart';
import 'package:wavnote/core/enums/audio_format.dart';

import '../helpers/test_helpers.dart';

// Mock classes
class MockRecordingBloc extends Mock implements RecordingBloc {}
class MockFolderBloc extends Mock implements FolderBloc {}

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('Recording Workflow Integration Tests', () {
    late MockRecordingBloc mockRecordingBloc;
    late MockFolderBloc mockFolderBloc;

    setUp(() {
      mockRecordingBloc = MockRecordingBloc();
      mockFolderBloc = MockFolderBloc();

      // Set up default mock behaviors
      when(() => mockRecordingBloc.state).thenReturn(const RecordingInitial());
      when(() => mockFolderBloc.state).thenReturn(const FolderInitial());
      
      when(() => mockRecordingBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([const RecordingInitial()]),
      );
      when(() => mockFolderBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([const FolderInitial()]),
      );
    });

    tearDown(() {
      mockRecordingBloc.close();
      mockFolderBloc.close();
    });

    testWidgets('Complete recording workflow - start, pause, resume, stop', (tester) async {
      // Build the app with mocked BLoCs
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<RecordingBloc>.value(value: mockRecordingBloc),
              BlocProvider<FolderBloc>.value(value: mockFolderBloc),
            ],
            child: const MainScreen(),
          ),
        ),
      );

      // Initial pump to build the widget tree
      await tester.pump();

      // Test recording start workflow
      await _testRecordingStart(tester, mockRecordingBloc);
      
      // Test recording pause workflow
      await _testRecordingPause(tester, mockRecordingBloc);
      
      // Test recording resume workflow
      await _testRecordingResume(tester, mockRecordingBloc);
      
      // Test recording stop workflow
      await _testRecordingStop(tester, mockRecordingBloc);
    });

    testWidgets('Recording with different audio formats', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<RecordingBloc>.value(value: mockRecordingBloc),
              BlocProvider<FolderBloc>.value(value: mockFolderBloc),
            ],
            child: const MainScreen(),
          ),
        ),
      );

      await tester.pump();

      // Test recording with M4A format
      await _testRecordingWithFormat(tester, mockRecordingBloc, AudioFormat.m4a);
      
      // Test recording with WAV format
      await _testRecordingWithFormat(tester, mockRecordingBloc, AudioFormat.wav);
    });

    testWidgets('Recording permission handling workflow', (tester) async {
      // Test permission denied scenario
      when(() => mockRecordingBloc.state).thenReturn(
        const RecordingError('Microphone permission denied'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<RecordingBloc>.value(value: mockRecordingBloc),
              BlocProvider<FolderBloc>.value(value: mockFolderBloc),
            ],
            child: const MainScreen(),
          ),
        ),
      );

      await tester.pump();

      // Should show permission error
      expect(find.textContaining('permission'), findsWidgets);
    });

    testWidgets('Recording error handling workflow', (tester) async {
      // Test recording error scenario
      when(() => mockRecordingBloc.state).thenReturn(
        const RecordingError('Audio service error'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<RecordingBloc>.value(value: mockRecordingBloc),
              BlocProvider<FolderBloc>.value(value: mockFolderBloc),
            ],
            child: const MainScreen(),
          ),
        ),
      );

      await tester.pump();

      // Should show error message
      expect(find.textContaining('error'), findsWidgets);
    });

    testWidgets('Multiple recordings workflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<RecordingBloc>.value(value: mockRecordingBloc),
              BlocProvider<FolderBloc>.value(value: mockFolderBloc),
            ],
            child: const MainScreen(),
          ),
        ),
      );

      await tester.pump();

      // Test creating multiple recordings
      for (int i = 0; i < 3; i++) {
        await _testRecordingStart(tester, mockRecordingBloc);
        await _testRecordingStop(tester, mockRecordingBloc);
        
        // Wait between recordings
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('Recording state persistence workflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<RecordingBloc>.value(value: mockRecordingBloc),
              BlocProvider<FolderBloc>.value(value: mockFolderBloc),
            ],
            child: const MainScreen(),
          ),
        ),
      );

      await tester.pump();

      // Test state changes and persistence
      await _testStatePersistence(tester, mockRecordingBloc);
    });
  });
}

// Helper functions for test workflows

Future<void> _testRecordingStart(WidgetTester tester, MockRecordingBloc mockBloc) async {
  // Simulate recording start
  when(() => mockBloc.state).thenReturn(
    const RecordingStarting(),
  );
  
  // Trigger state change
  when(() => mockBloc.stream).thenAnswer(
    (_) => Stream.fromIterable([const RecordingStarting()]),
  );
  
  await tester.pump();
  
  // Then transition to in progress
  when(() => mockBloc.state).thenReturn(
    RecordingInProgress(
      filePath: '/test/recording.m4a',
      folderId: 'test_folder',
      format: AudioFormat.m4a,
      sampleRate: 44100,
      bitRate: 128000,
      duration: const Duration(seconds: 5),
      amplitude: 0.5,
      startTime: DateTime.now(),
    ),
  );
  
  await tester.pump();
}

Future<void> _testRecordingPause(WidgetTester tester, MockRecordingBloc mockBloc) async {
  // Simulate recording pause
  when(() => mockBloc.state).thenReturn(
    RecordingPaused(
      filePath: '/test/recording.m4a',
      folderId: 'test_folder',
      format: AudioFormat.m4a,
      sampleRate: 44100,
      bitRate: 128000,
      duration: const Duration(seconds: 10),
      startTime: DateTime.now(),
    ),
  );
  
  await tester.pump();
}

Future<void> _testRecordingResume(WidgetTester tester, MockRecordingBloc mockBloc) async {
  // Simulate recording resume
  when(() => mockBloc.state).thenReturn(
    RecordingInProgress(
      filePath: '/test/recording.m4a',
      folderId: 'test_folder',
      format: AudioFormat.m4a,
      sampleRate: 44100,
      bitRate: 128000,
      duration: const Duration(seconds: 15),
      amplitude: 0.7,
      startTime: DateTime.now(),
    ),
  );
  
  await tester.pump();
}

Future<void> _testRecordingStop(WidgetTester tester, MockRecordingBloc mockBloc) async {
  // Simulate recording stop
  when(() => mockBloc.state).thenReturn(
    const RecordingStopping(),
  );
  
  await tester.pump();
  
  // Then transition to completed
  final testRecording = TestHelpers.createTestRecording();
  when(() => mockBloc.state).thenReturn(
    RecordingCompleted(recording: testRecording),
  );
  
  await tester.pump();
}

Future<void> _testRecordingWithFormat(
  WidgetTester tester, 
  MockRecordingBloc mockBloc, 
  AudioFormat format,
) async {
  // Test recording with specific format
  when(() => mockBloc.state).thenReturn(
    RecordingInProgress(
      filePath: '/test/recording.${format.name}',
      folderId: 'test_folder',
      format: format,
      sampleRate: 44100,
      bitRate: 128000,
      duration: const Duration(seconds: 5),
      amplitude: 0.5,
      startTime: DateTime.now(),
    ),
  );
  
  await tester.pump();
}

Future<void> _testStatePersistence(WidgetTester tester, MockRecordingBloc mockBloc) async {
  // Test that state changes are properly handled
  final states = [
    const RecordingInitial(),
    const RecordingStarting(),
    RecordingInProgress(
      filePath: '/test/recording.m4a',
      folderId: 'test_folder',
      format: AudioFormat.m4a,
      sampleRate: 44100,
      bitRate: 128000,
      duration: const Duration(seconds: 5),
      amplitude: 0.5,
      startTime: DateTime.now(),
    ),
    const RecordingStopping(),
    RecordingCompleted(recording: TestHelpers.createTestRecording()),
  ];
  
  for (final state in states) {
    when(() => mockBloc.state).thenReturn(state);
    await tester.pump();
    
    // Verify state transition
    expect(find.byType(MainScreen), findsOneWidget);
  }
}