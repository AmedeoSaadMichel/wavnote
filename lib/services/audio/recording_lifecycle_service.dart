// File: lib/services/audio/recording_lifecycle_service.dart
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'audio_service_coordinator.dart';

class RecordingLifecycleService with WidgetsBindingObserver {
  RecordingLifecycleService({required AudioServiceCoordinator coordinator})
    : _coordinator = coordinator;

  final AudioServiceCoordinator _coordinator;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
  }

  Future<void> dispose() async {
    if (!_isInitialized) return;
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncNativeRecordingStatus());
    }
  }

  Future<void> _syncNativeRecordingStatus() async {
    try {
      await _coordinator.syncNativeRecordingStatus();
    } catch (e) {
      debugPrint('❌ RecordingLifecycleService sync failed: $e');
    }
  }
}
