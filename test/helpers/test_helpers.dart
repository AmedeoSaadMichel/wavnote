// File: test/helpers/test_helpers.dart
// 
// Test Helpers - Testing Infrastructure
// ====================================
//
// Centralized testing utilities and helpers for the WavNote test suite.
// Provides common setup, mock objects, test data, and utility functions
// to ensure consistent and reliable testing across all test files.
//
// Key Features:
// - Test environment initialization and cleanup
// - Mock service and repository creation
// - Test data factories for entities
// - Widget testing utilities with proper BLoC setup
// - Database testing helpers with in-memory databases

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

// Import app components
import 'package:wavnote/presentation/bloc/folder/folder_bloc.dart';
import 'package:wavnote/presentation/bloc/recording/recording_bloc.dart';
import 'package:wavnote/presentation/bloc/settings/settings_bloc.dart';
import 'package:wavnote/domain/entities/recording_entity.dart';
import 'package:wavnote/domain/entities/folder_entity.dart';
import 'package:wavnote/core/enums/audio_format.dart';
import 'package:wavnote/core/enums/folder_type.dart';
import 'package:wavnote/domain/repositories/i_audio_service_repository.dart';
import 'package:wavnote/domain/repositories/i_recording_repository.dart';
import 'package:wavnote/services/location/geolocation_service.dart';
import 'package:wavnote/domain/usecases/recording/start_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/stop_recording_usecase.dart';
import 'package:wavnote/domain/usecases/recording/pause_recording_usecase.dart';

/// Test helpers and utilities for WavNote testing
class TestHelpers {
  // Private constructor to prevent instantiation
  TestHelpers._();

  /// Initialize test environment with necessary setups
  static Future<void> initializeTestEnvironment() async {
    // Register fallback values for Mocktail
    registerFallbackValue(AudioFormat.m4a);
    registerFallbackValue(const Duration(seconds: 30));
    registerFallbackValue(DateTime(2023, 1, 1));
    registerFallbackValue(FolderType.defaultFolder);

    // Ensure widget binding is initialized for tests
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  /// Create a test app widget with proper BLoC providers
  static Widget createTestApp({
    required Widget child,
    FolderBloc? folderBloc,
    RecordingBloc? recordingBloc,
    SettingsBloc? settingsBloc,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<FolderBloc>(
          create: (_) => folderBloc ?? createMockFolderBloc(),
        ),
        BlocProvider<RecordingBloc>(
          create: (_) => recordingBloc ?? createMockRecordingBloc(),
        ),
        BlocProvider<SettingsBloc>(
          create: (_) => settingsBloc ?? createMockSettingsBloc(),
        ),
      ],
      child: MaterialApp(
        home: child,
        theme: ThemeData.dark(), // Use dark theme for tests
      ),
    );
  }

  /// Create a mock FolderBloc for testing
  static FolderBloc createMockFolderBloc() {
    // For now, return a real FolderBloc
    // In the future, we'll create proper mocks
    return FolderBloc();
  }

  /// Create a mock RecordingBloc for testing
  static RecordingBloc createMockRecordingBloc() {
    // Create mocks for dependencies
    final mockAudioService = MockAudioServiceRepository();
    final mockRecordingRepository = MockRecordingRepository();
    final mockGeolocationService = MockGeolocationService();

    // Setup default mock behaviors
    when(() => mockAudioService.initialize()).thenAnswer((_) async => true);
    when(() => mockAudioService.dispose()).thenAnswer((_) async {});
    when(() => mockRecordingRepository.getAllRecordings())
        .thenAnswer((_) async => <RecordingEntity>[]);

    return RecordingBloc(
      audioService: mockAudioService,
      recordingRepository: mockRecordingRepository,
      geolocationService: mockGeolocationService,
    );
  }

  /// Create a mock SettingsBloc for testing
  static SettingsBloc createMockSettingsBloc() {
    return SettingsBloc();
  }

  /// Create test recording entity
  static RecordingEntity createTestRecording({
    String? id,
    String? name,
    String? filePath,
    String? folderId,
    AudioFormat? format,
    Duration? duration,
    int? fileSize,
    DateTime? createdAt,
    bool? isFavorite,
  }) {
    return RecordingEntity(
      id: id ?? 'test_recording_1',
      name: name ?? 'Test Recording',
      filePath: filePath ?? '/test/path/recording.m4a',
      folderId: folderId ?? 'test_folder',
      format: format ?? AudioFormat.m4a,
      duration: duration ?? const Duration(minutes: 2, seconds: 30),
      fileSize: fileSize ?? 1024000, // 1MB
      sampleRate: 44100,
      createdAt: createdAt ?? DateTime(2023, 1, 1),
      isFavorite: isFavorite ?? false,
    );
  }

  /// Create test folder entity
  static FolderEntity createTestFolder({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    int? recordingCount,
    FolderType? type,
    bool? isDeletable,
  }) {
    return FolderEntity(
      id: id ?? 'test_folder_1',
      name: name ?? 'Test Folder',
      icon: icon ?? Icons.folder,
      color: color ?? Colors.blue,
      recordingCount: recordingCount ?? 0,
      type: type ?? FolderType.customFolder,
      isDeletable: isDeletable ?? true,
      createdAt: DateTime(2023, 1, 1),
    );
  }

  /// Create a list of test recordings
  static List<RecordingEntity> createTestRecordings(int count) {
    return List.generate(count, (index) {
      return createTestRecording(
        id: 'test_recording_$index',
        name: 'Test Recording $index',
        duration: Duration(minutes: index + 1),
      );
    });
  }

  /// Create a list of test folders
  static List<FolderEntity> createTestFolders(int count) {
    return List.generate(count, (index) {
      return createTestFolder(
        id: 'test_folder_$index',
        name: 'Test Folder $index',
        recordingCount: index * 2,
      );
    });
  }

  /// Pump and settle with error handling
  static Future<void> pumpAndSettleWithTimeout(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      await tester.pumpAndSettle(timeout);
    } catch (e) {
      // Handle timeout gracefully in tests
      await tester.pump();
    }
  }

  /// Find widget by key safely
  static Finder findByKeyString(String keyString) {
    return find.byKey(Key(keyString));
  }

  /// Verify text exists with custom error message
  static void expectTextExists(String text, {String? reason}) {
    expect(
      find.text(text),
      findsOneWidget,
      reason: reason ?? 'Expected to find text: "$text"',
    );
  }

  /// Verify widget type exists with custom error message
  static void expectWidgetExists<T extends Widget>({String? reason}) {
    expect(
      find.byType(T),
      findsWidgets,
      reason: reason ?? 'Expected to find widget of type: ${T.toString()}',
    );
  }
}

/// Mock classes for testing
class MockAudioServiceRepository extends Mock implements IAudioServiceRepository {}

class MockRecordingRepository extends Mock implements IRecordingRepository {}

class MockGeolocationService extends Mock implements GeolocationService {}

/// Test constants
class TestConstants {
  static const String testDatabasePath = ':memory:';
  static const Duration defaultTimeout = Duration(seconds: 5);
  static const String testRecordingPath = '/test/recordings/';
  static const String testFolderPrefix = 'test_folder_';
  static const String testRecordingPrefix = 'test_recording_';
}

/// Test matchers for custom expectations
class TestMatchers {
  /// Matcher for audio format validation
  static Matcher isValidAudioFormat() {
    return predicate<AudioFormat>(
      (format) => AudioFormat.values.contains(format),
      'is a valid audio format',
    );
  }

  /// Matcher for duration validation
  static Matcher isPositiveDuration() {
    return predicate<Duration>(
      (duration) => duration.inMilliseconds > 0,
      'is a positive duration',
    );
  }

  /// Matcher for file size validation
  static Matcher isValidFileSize() {
    return predicate<int>(
      (size) => size >= 0,
      'is a valid file size (>= 0)',
    );
  }
}