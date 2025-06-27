// File: core/utils/performance_logger.dart
import 'package:flutter/foundation.dart';

/// Performance monitoring utilities for debug mode
class PerformanceLogger {
  static final Map<String, DateTime> _timers = {};
  static final Map<String, int> _buildCounts = {};

  /// Start timing an operation
  static void startTimer(String operation) {
    if (kDebugMode) {
      _timers[operation] = DateTime.now();
    }
  }

  /// End timing and log duration
  static void endTimer(String operation) {
    if (kDebugMode && _timers.containsKey(operation)) {
      final duration = DateTime.now().difference(_timers[operation]!);
      print('⏱️ PERF: $operation took ${duration.inMilliseconds}ms');
      _timers.remove(operation);
    }
  }

  /// Log widget rebuild
  static void logRebuild(String widgetName) {
    if (kDebugMode) {
      _buildCounts[widgetName] = (_buildCounts[widgetName] ?? 0) + 1;
      print('🔄 REBUILD: $widgetName (count: ${_buildCounts[widgetName]})');
    }
  }

  /// Log memory usage estimation
  static void logMemoryUsage(String context) {
    if (kDebugMode) {
      // Simple memory estimation based on object counts
      final now = DateTime.now();
      print('💾 MEMORY: $context at ${now.millisecondsSinceEpoch}');
    }
  }

  /// Print rebuild statistics
  static void printRebuildStats() {
    if (kDebugMode && _buildCounts.isNotEmpty) {
      print('📊 REBUILD STATS:');
      _buildCounts.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..forEach((entry) {
            print('  ${entry.key}: ${entry.value} rebuilds');
          });
    }
  }

  /// Clear all stats
  static void clearStats() {
    _timers.clear();
    _buildCounts.clear();
  }
}