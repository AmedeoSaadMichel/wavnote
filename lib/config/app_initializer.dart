// File: lib/config/app_initializer.dart
import 'package:flutter/foundation.dart';

import '../data/database/database_helper.dart';
import '../services/logging/swift_log_channel_service.dart';
import 'dependency_injection.dart';

/// Esegue tutta l'inizializzazione prima di `runApp`.
///
/// Ordine fisso:
/// 1. DatabaseHelper — apertura/PRAGMA SQLite
/// 2. setupDependencies — registrazione GetIt
/// 3. SwiftLogChannelService — bridge debug (solo dev)
Future<void> initializeApp() async {
  try {
    await DatabaseHelper.database;
    await setupDependencies();

    // TODO(debug): rimuovere prima del rilascio in produzione
    await SwiftLogChannelService.instance.initialize();
    SwiftLogChannelService.instance.logs.listen(
      (e) => debugPrint('SWIFT LOG: $e'),
    );
  } catch (e) {
    debugPrint('❌ Initialization error: $e');
  }
}
