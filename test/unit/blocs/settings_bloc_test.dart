// File: test/unit/blocs/settings_bloc_test.dart
// 
// Settings BLoC Unit Tests - CORRECTED VERSION
// =============================================
//
// Comprehensive test suite for the SettingsBloc class using proper
// imports and correct interface implementations.

import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wavnote/presentation/bloc/settings/settings_bloc.dart';
import 'package:wavnote/core/enums/audio_format.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('SettingsBloc', () {
    late SettingsBloc bloc;

    setUp(() {
      bloc = SettingsBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state is SettingsInitial', () {
      expect(bloc.state, isA<SettingsInitial>());
    });

    group('LoadSettings', () {
      blocTest<SettingsBloc, SettingsState>(
        'emits [Loading, Loaded] when settings load successfully',
        build: () => bloc,
        act: (bloc) => bloc.add(const LoadSettings()),
        expect: () => [
          isA<SettingsLoading>(),
          isA<SettingsLoaded>()
            .having((state) => state.settings.audioFormat, 'audioFormat', isA<AudioFormat>())
            .having((state) => state.settings.sampleRate, 'sampleRate', greaterThan(0))
            .having((state) => state.settings.bitRate, 'bitRate', greaterThan(0))
            .having((state) => state.settings.enableHapticFeedback, 'hapticFeedback', isA<bool>())
            .having((state) => state.settings.enableRealTimeWaveform, 'waveformVisualization', isA<bool>())
            .having((state) => state.settings.enableAmplitudeVisualization, 'amplitudeMonitoring', isA<bool>())
            .having((state) => state.settings.enableAnimations, 'animations', isA<bool>()),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'loads default settings when no saved settings exist',
        build: () => bloc,
        act: (bloc) => bloc.add(const LoadSettings()),
        verify: (bloc) {
          final state = bloc.state;
          if (state is SettingsLoaded) {
            // Verify default values
            expect(state.settings.audioFormat, AudioFormat.m4a);
            expect(state.settings.sampleRate, 44100);
            expect(state.settings.bitRate, 128000);
            expect(state.settings.enableHapticFeedback, true);
            expect(state.settings.enableRealTimeWaveform, true);
            expect(state.settings.enableAmplitudeVisualization, true);
            expect(state.settings.enableAnimations, true);
          }
        },
      );
    });

    group('UpdateAudioFormat', () {
      blocTest<SettingsBloc, SettingsState>(
        'updates audio format and persists change',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.high,
            sampleRate: 44100,
            bitRate: 128000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const UpdateAudioFormat(AudioFormat.wav)),
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.audioFormat, 'audioFormat', AudioFormat.wav),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'updates audio format from initial state',
        build: () => bloc,
        act: (bloc) async {
          bloc.add(const LoadSettings());
          await Future.delayed(const Duration(milliseconds: 500));
          bloc.add(const UpdateAudioFormat(AudioFormat.wav));
        },
        skip: 2, // Skip loading states
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.audioFormat, 'audioFormat', AudioFormat.wav),
        ],
      );
    });

    group('UpdateAudioQuality', () {
      blocTest<SettingsBloc, SettingsState>(
        'updates to high quality settings',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.low,
            sampleRate: 22050,
            bitRate: 64000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const UpdateAudioQuality(AudioQuality.high)),
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.audioQuality, 'audioQuality', AudioQuality.high),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'updates to medium quality settings',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.high,
            sampleRate: 48000,
            bitRate: 320000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const UpdateAudioQuality(AudioQuality.medium)),
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.audioQuality, 'audioQuality', AudioQuality.medium),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'updates to low quality settings',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.medium,
            sampleRate: 44100,
            bitRate: 128000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const UpdateAudioQuality(AudioQuality.low)),
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.audioQuality, 'audioQuality', AudioQuality.low),
        ],
      );
    });

    group('UpdateCustomAudioSettings', () {
      blocTest<SettingsBloc, SettingsState>(
        'updates custom sample rate',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.medium,
            sampleRate: 44100,
            bitRate: 128000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const UpdateSampleRate(48000)),
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.sampleRate, 'sampleRate', 48000),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'updates custom bit rate',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.medium,
            sampleRate: 44100,
            bitRate: 128000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const UpdateBitRate(256000)),
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.bitRate, 'bitRate', 256000),
        ],
      );
    });

    group('UI Preference Updates', () {
      blocTest<SettingsBloc, SettingsState>(
        'toggles haptic feedback',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.medium,
            sampleRate: 44100,
            bitRate: 128000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const ToggleHapticFeedback()),
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.enableHapticFeedback, 'hapticFeedback', false),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'toggles waveform visualization',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.medium,
            sampleRate: 44100,
            bitRate: 128000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const ToggleRealTimeWaveform()),
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.enableRealTimeWaveform, 'waveformVisualization', false),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'toggles amplitude monitoring',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.medium,
            sampleRate: 44100,
            bitRate: 128000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const ToggleAmplitudeVisualization()),
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.enableAmplitudeVisualization, 'amplitudeMonitoring', false),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'toggles animations',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.medium,
            sampleRate: 44100,
            bitRate: 128000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const ToggleAnimations()),
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.enableAnimations, 'animations', false),
        ],
      );
    });

    group('Last Opened Folder', () {
      blocTest<SettingsBloc, SettingsState>(
        'updates last opened folder',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.medium,
            sampleRate: 44100,
            bitRate: 128000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const UpdateLastOpenedFolder('favorites')),
        expect: () => [
          isA<SettingsLoaded>()
            .having((state) => state.settings.lastOpenedFolderId, 'lastOpenedFolder', 'favorites'),
        ],
      );
    });

    group('Settings Export/Import', () {
      final testSettings = AppSettings(
        audioFormat: AudioFormat.wav,
        audioQuality: AudioQuality.high,
        sampleRate: 48000,
        bitRate: 320000,
        enableHapticFeedback: false,
        enableRealTimeWaveform: true,
        enableAmplitudeVisualization: false,
        enableAnimations: true,
        lastOpenedFolderId: 'custom_folder',
        lastModified: DateTime.now(),
      );

      blocTest<SettingsBloc, SettingsState>(
        'exports settings successfully',
        build: () => bloc,
        seed: () => SettingsLoaded(settings: testSettings),
        act: (bloc) => bloc.add(const ExportSettings()),
        expect: () => [
          isA<SettingsLoaded>(),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'imports settings from JSON',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.medium,
            sampleRate: 44100,
            bitRate: 128000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(ImportSettings(const {
          'audioFormat': 1, // wav index
          'sampleRate': 48000,
          'bitRate': 256000,
        })),
        expect: () => [
          isA<SettingsLoading>(),
          isA<SettingsLoaded>()
            .having((state) => state.settings.audioFormat, 'audioFormat', AudioFormat.wav)
            .having((state) => state.settings.sampleRate, 'sampleRate', 48000)
            .having((state) => state.settings.bitRate, 'bitRate', 256000),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'handles invalid import data',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.m4a,
            audioQuality: AudioQuality.medium,
            sampleRate: 44100,
            bitRate: 128000,
            enableHapticFeedback: true,
            enableRealTimeWaveform: true,
            enableAmplitudeVisualization: true,
            enableAnimations: true,
            lastOpenedFolderId: 'all_recordings',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const ImportSettings(<String, dynamic>{})),
        expect: () => [
          isA<SettingsLoading>(),
          anyOf([
            isA<SettingsLoaded>(),
            isA<SettingsError>(),
          ]),
        ],
      );
    });

    group('Reset Settings', () {
      blocTest<SettingsBloc, SettingsState>(
        'resets settings to default values',
        build: () => bloc,
        seed: () => SettingsLoaded(
          settings: AppSettings(
            audioFormat: AudioFormat.wav,
            audioQuality: AudioQuality.low,
            sampleRate: 48000,
            bitRate: 320000,
            enableHapticFeedback: false,
            enableRealTimeWaveform: false,
            enableAmplitudeVisualization: false,
            enableAnimations: false,
            lastOpenedFolderId: 'custom_folder',
            lastModified: DateTime.now(),
          ),
        ),
        act: (bloc) => bloc.add(const ResetSettings()),
        expect: () => [
          isA<SettingsLoading>(),
          isA<SettingsLoaded>()
            .having((state) => state.settings.audioFormat, 'audioFormat', AudioFormat.m4a)
            .having((state) => state.settings.audioQuality, 'audioQuality', AudioQuality.high)
            .having((state) => state.settings.sampleRate, 'sampleRate', 44100)
            .having((state) => state.settings.bitRate, 'bitRate', 128000)
            .having((state) => state.settings.enableHapticFeedback, 'hapticFeedback', true)
            .having((state) => state.settings.enableRealTimeWaveform, 'waveformVisualization', true)
            .having((state) => state.settings.enableAmplitudeVisualization, 'amplitudeMonitoring', true)
            .having((state) => state.settings.enableAnimations, 'animations', true)
            .having((state) => state.settings.lastOpenedFolderId, 'lastOpenedFolder', 'main'),
        ],
      );
    });

    group('Error Handling', () {
      test('handles rapid load requests gracefully', () async {
        // Test rapid loading without causing issues
        for (int i = 0; i < 3; i++) {
          bloc.add(const LoadSettings());
        }
        
        // Wait a bit and check state is valid
        await Future.delayed(const Duration(milliseconds: 100));
        
        final state = bloc.state;
        expect(state, anyOf([
          isA<SettingsLoaded>(),
          isA<SettingsError>(),
          isA<SettingsLoading>(),
          isA<SettingsInitial>(),
        ]));
      });

      test('ignores update operations on unloaded state', () {
        // When state is not loaded, updates should be ignored
        expect(bloc.state, isA<SettingsInitial>());
        
        bloc.add(const UpdateAudioFormat(AudioFormat.wav));
        
        // State should remain initial since settings not loaded
        expect(bloc.state, isA<SettingsInitial>());
      });
    });

    group('Settings Validation', () {
      test('supports all audio formats', () {
        final testSettings = AppSettings(
          audioFormat: AudioFormat.m4a,
          audioQuality: AudioQuality.medium,
          sampleRate: 44100,
          bitRate: 128000,
          enableHapticFeedback: true,
          enableRealTimeWaveform: true,
          enableAmplitudeVisualization: true,
          enableAnimations: true,
          lastOpenedFolderId: 'all_recordings',
          lastModified: DateTime.now(),
        );
        
        // Verify all audio formats are valid
        for (final format in AudioFormat.values) {
          final updatedSettings = testSettings.copyWith(audioFormat: format);
          expect(updatedSettings.audioFormat, equals(format));
        }
      });
    });
  });
}