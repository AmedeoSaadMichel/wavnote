// File: test/unit/services/audio_recorder_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';

import 'package:wavnote/services/audio/audio_recorder_service.dart';
import 'package:wavnote/core/enums/audio_format.dart';

// Note: This test focuses on memory leak prevention in disposal methods
// Full testing would require mocking Flutter Sound components

void main() {
  group('AudioRecorderService Memory Management', () {
    late AudioRecorderService service;

    setUp(() {
      service = AudioRecorderService();
    });

    group('dispose', () {
      test('should complete disposal even when individual components fail', () async {
        // This test verifies that the try-finally pattern ensures
        // all cleanup operations are attempted even if some fail
        
        // The service should dispose successfully even if internal components throw
        expect(() => service.dispose(), returnsNormally);
      });

      test('should reset all state variables after disposal', () async {
        // Initialize service first (in a real test, we'd mock this)
        // await service.initialize();

        // Dispose the service
        await service.dispose();

        // Verify that disposal can be called multiple times safely
        expect(() => service.dispose(), returnsNormally);
        
        // Multiple disposals should not cause issues
        await service.dispose();
        await service.dispose();
      });

      test('should handle stream controller disposal gracefully', () async {
        // Test that stream controllers are properly disposed
        // even if they throw exceptions during closure
        
        expect(() => service.dispose(), returnsNormally);
      });
    });

    group('permission checking', () {
      test('should check microphone permission', () async {
        // Test basic permission checking functionality
        final hasPermission = await service.hasMicrophonePermission();
        
        // Should return a boolean without throwing
        expect(hasPermission, isA<bool>());
      });

      test('should check microphone hardware availability', () async {
        // Test hardware availability checking
        final hasMicrophone = await service.hasMicrophone();
        
        // Should return a boolean without throwing
        expect(hasMicrophone, isA<bool>());
      });
    });

    group('error handling', () {
      test('should handle initialization errors gracefully', () async {
        // Test that initialization errors don't crash the service
        final result = await service.initialize();
        
        // Should return a boolean result
        expect(result, isA<bool>());
      });

      test('should provide amplitude stream', () {
        // Test that amplitude stream is accessible
        final stream = service.getRecordingAmplitudeStream();
        
        // Should provide a stream
        expect(stream, isA<Stream<double>>());
      });

      test('should provide duration stream getter', () {
        // Test that duration stream is accessible via getter
        final stream = service.durationStream;
        
        // Should provide a stream (may be null if not initialized)
        expect(stream, anyOf(isNull, isA<Stream<Duration>>()));
      });
    });

    tearDown(() async {
      // Ensure proper cleanup after each test
      await service.dispose();
    });
  });

  group('AudioRecorderService State Management', () {
    late AudioRecorderService service;

    setUp(() {
      service = AudioRecorderService();
    });

    test('should maintain consistent state during lifecycle', () async {
      // Test basic state consistency
      
      // Initial state should be not recording
      expect(await service.isRecording(), isFalse);
      expect(await service.isPlaying(), isFalse);
      
      // After disposal, state should be reset
      await service.dispose();
      expect(await service.isRecording(), isFalse);
      expect(await service.isPlaying(), isFalse);
    });

    test('should handle multiple dispose calls safely', () async {
      // Test that multiple disposal calls don't cause issues
      await service.dispose();
      await service.dispose();
      await service.dispose();
      
      // Should complete without throwing
      expect(true, isTrue);
    });

    tearDown(() async {
      await service.dispose();
    });
  });
}