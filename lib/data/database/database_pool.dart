// File: data/database/database_pool.dart
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

/// High-performance database connection pool for WavNote
/// 
/// Maintains a persistent database connection to eliminate connection overhead.
/// Provides ultra-fast queries for router initialization and app startup.
class DatabasePool {
  static Database? _pool;
  static bool _isInitialized = false;
  static final Completer<void> _initCompleter = Completer<void>();

  /// Initialize the database pool during app startup
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    final stopwatch = Stopwatch()..start();
    
    try {
      print('🏊‍♂️ DatabasePool: Initializing connection pool...');
      
      // Use the existing DatabaseHelper to get the database
      _pool = await DatabaseHelper.database;
      
      // Test the connection with a simple query to ensure it's ready
      final testResult = await _pool!.rawQuery('SELECT 1');
      print('🧪 DatabasePool: Connection test successful: $testResult');
      
      // Optimize the connection for performance
      await _optimizeConnection();
      
      _isInitialized = true;
      _initCompleter.complete();
      
      stopwatch.stop();
      print('✅ DatabasePool: Pool initialized in ${stopwatch.elapsedMilliseconds}ms');
      
    } catch (e) {
      stopwatch.stop();
      print('❌ DatabasePool: Initialization failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      _initCompleter.completeError(e);
      rethrow;
    }
  }

  /// Optimize database connection for better performance
  static Future<void> _optimizeConnection() async {
    if (_pool == null) return;
    
    try {
      // Enable Write-Ahead Logging for better concurrent performance
      await _pool!.execute('PRAGMA journal_mode = WAL');
      
      // Set synchronous mode to NORMAL for balanced safety/speed
      await _pool!.execute('PRAGMA synchronous = NORMAL');
      
      // Enable foreign key constraints
      await _pool!.execute('PRAGMA foreign_keys = ON');
      
      // Set cache size for better performance (negative value = KB)
      await _pool!.execute('PRAGMA cache_size = -2000'); // 2MB cache
      
      // Set temp store to memory
      await _pool!.execute('PRAGMA temp_store = MEMORY');
      
      print('⚡ DatabasePool: Connection optimized for performance');
      
    } catch (e) {
      print('⚠️ DatabasePool: Failed to optimize connection: $e');
      // Non-critical - continue without optimizations
    }
  }

  /// Get the pooled database connection (instant access)
  static Database get connection {
    if (!_isInitialized || _pool == null) {
      throw Exception('DatabasePool not initialized. Call DatabasePool.initialize() first.');
    }
    return _pool!;
  }

  /// Wait for pool initialization if needed
  static Future<void> waitForInitialization() async {
    if (_isInitialized) return;
    await _initCompleter.future;
  }

  /// Ultra-fast query to get last opened folder ID
  static Future<String> getLastFolderId() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check if pool is ready - if not, use fallback
      if (!_isInitialized || _pool == null) {
        stopwatch.stop();
        print('⚠️ DatabasePool: Pool not ready, using fallback in ${stopwatch.elapsedMilliseconds}ms');
        return 'main'; // Quick fallback
      }
      
      final result = await _pool!.query(
        DatabaseHelper.settingsTable,
        columns: [DatabaseHelper.settingValueColumn],
        where: '${DatabaseHelper.settingKeyColumn} = ?',
        whereArgs: ['lastOpenedFolderId'],
        limit: 1,
      );
      
      stopwatch.stop();
      
      if (result.isNotEmpty) {
        final rawValue = result.first[DatabaseHelper.settingValueColumn] as String?;
        final processedValue = (rawValue?.isEmpty == true || rawValue == null) ? 'main' : rawValue;
        
        print('⚡ DatabasePool: Ultra-fast folder query completed in ${stopwatch.elapsedMilliseconds}ms');
        print('📁 DatabasePool: Fast loading lastOpenedFolderId - Raw: "$rawValue", Processed: "$processedValue"');
        
        return processedValue;
      } else {
        print('⚡ DatabasePool: No lastOpenedFolderId found in ${stopwatch.elapsedMilliseconds}ms, defaulting to main');
        return 'main';
      }
      
    } catch (e) {
      stopwatch.stop();
      print('❌ DatabasePool: Fast folder query failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      return 'main'; // Safe fallback
    }
  }

  /// Ultra-fast query to save last opened folder ID
  static Future<void> saveLastFolderId(String folderId) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Ensure pool is ready
      await waitForInitialization();
      
      final now = DateTime.now().toIso8601String();
      
      await connection.execute('''
        INSERT OR REPLACE INTO ${DatabaseHelper.settingsTable} 
        (${DatabaseHelper.settingKeyColumn}, ${DatabaseHelper.settingValueColumn}, ${DatabaseHelper.settingUpdatedAtColumn}) 
        VALUES (?, ?, ?)
      ''', ['lastOpenedFolderId', folderId, now]);
      
      stopwatch.stop();
      print('⚡ DatabasePool: Ultra-fast folder save completed in ${stopwatch.elapsedMilliseconds}ms');
      print('💾 DatabasePool: Saved lastOpenedFolderId: "$folderId"');
      
    } catch (e) {
      stopwatch.stop();
      print('❌ DatabasePool: Fast folder save failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      // Non-critical failure - don't throw
    }
  }

  /// Check if pool is ready for use
  static bool get isReady => _isInitialized && _pool != null;

  /// Get pool statistics for debugging
  static Map<String, dynamic> get stats => {
    'initialized': _isInitialized,
    'has_connection': _pool != null,
    'database_path': _pool?.path ?? 'not_available',
    'is_open': _pool?.isOpen ?? false,
  };

  /// Dispose of the pool (call when app shuts down)
  static Future<void> dispose() async {
    if (_pool != null && _pool!.isOpen) {
      try {
        await _pool!.close();
        print('🏊‍♂️ DatabasePool: Connection pool closed');
      } catch (e) {
        print('⚠️ DatabasePool: Error closing pool: $e');
      }
    }
    
    _pool = null;
    _isInitialized = false;
  }

  /// Reset pool state (useful for testing)
  static void reset() {
    _pool = null;
    _isInitialized = false;
  }
}