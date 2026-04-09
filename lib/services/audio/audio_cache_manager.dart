// File: services/audio/audio_cache_manager.dart
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// LRU (Least Recently Used) cache manager for AudioSource objects.
///
/// Helps to preload and cache audio files to reduce latency when
/// users play or switch between recordings.
class AudioCacheManager {
  final Map<String, AudioSource> _preloadedSources = {};
  final List<String> _accessOrder = [];
  final int _maxCacheSize;

  AudioCacheManager({int maxCacheSize = 5}) : _maxCacheSize = maxCacheSize;

  /// Get cached audio source and update access order
  AudioSource? getCachedSource(String filePath) {
    if (_preloadedSources.containsKey(filePath)) {
      // Move to end of access order (most recently used)
      _accessOrder.remove(filePath);
      _accessOrder.add(filePath);
      return _preloadedSources[filePath];
    }
    return null;
  }

  /// Cache audio source with LRU eviction
  void cacheSource(String filePath, AudioSource audioSource) {
    // If already cached, just update access order
    if (_preloadedSources.containsKey(filePath)) {
      _accessOrder.remove(filePath);
      _accessOrder.add(filePath);
      return;
    }

    // If cache is full, remove least recently used
    if (_preloadedSources.length >= _maxCacheSize) {
      final lruFilePath = _accessOrder.removeAt(0);
      _preloadedSources.remove(lruFilePath);
      debugPrint('🗑️ Evicted LRU audio source: $lruFilePath');
    }

    // Add new source to cache
    _preloadedSources[filePath] = audioSource;
    _accessOrder.add(filePath);
    debugPrint(
      '💾 Cached audio source: $filePath (cache size: ${_preloadedSources.length})',
    );
  }

  /// Preload an audio source directly from a file path
  Future<bool> preloadAudioSource(String filePath) async {
    try {
      // Check if already cached
      if (_preloadedSources.containsKey(filePath)) {
        debugPrint('✅ Audio source already cached: $filePath');
        // Update access order
        _accessOrder.remove(filePath);
        _accessOrder.add(filePath);
        return true;
      }

      // Create new audio source
      debugPrint('🔄 Preloading new audio source: $filePath');
      final audioSource = AudioSource.file(filePath);

      // Cache it
      cacheSource(filePath, audioSource);
      return true;
    } catch (e) {
      debugPrint('❌ Error preloading audio source: $e');
      return false;
    }
  }

  /// Clear all cached sources
  void clearCache() {
    _preloadedSources.clear();
    _accessOrder.clear();
    debugPrint('🗑️ Audio source cache cleared');
  }

  /// Get statistics about the cache
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _preloadedSources.length,
      'maxSize': _maxCacheSize,
      'cachedFiles': _accessOrder.toList(), // Return a copy
    };
  }

  /// Dispose the cache manager
  void dispose() {
    clearCache();
  }
}
