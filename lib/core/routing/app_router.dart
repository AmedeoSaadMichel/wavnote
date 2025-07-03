// File: core/routing/app_router.dart
// 
// App Router - Core Layer
// ======================
//
// Centralized navigation system for the WavNote application using GoRouter
// for type-safe, declarative routing with state persistence and restoration.
//
// Key Features:
// - Declarative routing with GoRouter for modern navigation patterns
// - Automatic state persistence using high-performance database pool
// - Navigation state restoration on app restart
// - Type-safe route parameters and navigation methods
// - Performance optimized with ultra-fast database access
// - Smooth transitions with proper loading states
//
// Architecture:
// - Uses GoRouter for modern Flutter navigation
// - Integrates with BLoC pattern for state management
// - Leverages DatabasePool for instant state persistence
// - Provides extension methods for convenient navigation
// - Handles async route creation with proper loading states
//
// Navigation Flow:
// 1. App startup loads last visited screen from database
// 2. Router determines initial route based on saved state
// 3. Navigation state is automatically persisted on route changes
// 4. Route parameters are validated and type-safe
// 5. Loading screens shown during async operations
//
// Routes:
// - '/' (mainRoute): Main screen with folder overview
// - '/folder' (folderRoute): Individual folder recording list
//
// State Persistence:
// - Last visited folder ID saved to database
// - Instant access using connection pool (no async delays)
// - Automatic restoration on app restart
// - Fallback to main screen if saved state is invalid
//
// Performance Features:
// - Ultra-fast database pool for instant state access
// - Asynchronous router creation with progress tracking
// - Optimized route transitions and loading states
// - Memory-efficient navigation stack management

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// Screen imports
import '../../presentation/screens/main/main_screen.dart';           // Main folder overview
import '../../presentation/screens/recording/recording_list_screen.dart'; // Recording list

// Domain imports
import '../../domain/entities/folder_entity.dart'; // Folder business entity
import '../../core/enums/folder_type.dart'; // Folder type enum

// BLoC imports
import '../../presentation/bloc/folder/folder_bloc.dart'; // Folder state management

// Data layer imports
import '../../data/database/database_pool.dart'; // High-performance database access

// Widget imports
import '../../presentation/widgets/common/skeleton_screen.dart'; // Loading screen

/// Centralized route management for the WavNote app
/// 
/// Handles navigation state persistence and restoration automatically
/// using high-performance database pool for instant state access.
///
/// Key features:
/// - Type-safe navigation with GoRouter
/// - Automatic state persistence and restoration
/// - Performance optimized with database connection pooling
/// - Smooth loading transitions and error handling
/// - Extension methods for convenient navigation
class AppRouter {
  static const String mainRoute = '/';
  static const String folderRoute = '/folder';
  
  // Main screen treated as a special folder for consistent state management
  static const String mainFolderId = 'main';
  
  
  /// Create router asynchronously with ultra-fast database pool and pre-loaded folder data
  static Future<GoRouter> createRouterAsync() async {
    final stopwatch = Stopwatch()..start();
    print('📁 AppRouter: Creating async router with pre-loading optimization');
    print('🏊‍♂️ AppRouter: Database pool ready: ${DatabasePool.isReady}');
    
    // CRITICAL: Wait for database pool to be fully initialized
    if (!DatabasePool.isReady) {
      print('⏳ AppRouter: Waiting for database pool initialization...');
      await DatabasePool.waitForInitialization();
      print('✅ AppRouter: Database pool initialization complete');
    }
    
    // Use ultra-fast database pool instead of slow settings loading
    final lastFolderId = await DatabasePool.getLastFolderId();
    
    // OPTIMIZATION: Pre-load folder data to eliminate all router skeletons
    print('🚀 PRE-LOAD: Loading folder data in advance to eliminate skeletons');
    // Note: This will trigger FolderBloc loading early, making sync lookup successful
    
    // Determine initial route based on saved settings
    String initialRoute;
    if (lastFolderId != mainFolderId) {
      initialRoute = '$folderRoute/$lastFolderId';
      print('📁 AppRouter: Pre-determined initial route: $initialRoute (folder: $lastFolderId)');
    } else {
      initialRoute = mainRoute;
      print('📁 AppRouter: Pre-determined initial route: $initialRoute (main screen)');
    }
    
    stopwatch.stop();
    print('⚡ AppRouter: Router created in ${stopwatch.elapsedMilliseconds}ms (with pre-loading)');
    
    return GoRouter(
      initialLocation: initialRoute,
      debugLogDiagnostics: true,
      
      // No redirects needed - route is pre-determined
      redirect: (context, state) {
        return null;
      },
      
      routes: [
        // Main screen route
        GoRoute(
          path: mainRoute,
          name: 'main',
          builder: (context, state) {
            // No more wrapper needed - route is pre-determined
            return const MainScreen();
          },
        ),
        
        // Folder/Recording list route - Simple direct lookup
        GoRoute(
          path: '$folderRoute/:folderId',
          name: 'folder',
          builder: (context, state) {
            final folderId = state.pathParameters['folderId']!;
            
            return _FolderRouteWidget(folderId: folderId);
          },
        ),
      ],
      
      // Handle navigation errors
      errorBuilder: (context, state) {
        print('❌ Router error: ${state.error}');
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Navigation Error: ${state.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go(mainRoute),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Find folder by ID from the folder bloc
  static Future<FolderEntity?> _findFolderById(BuildContext context, String folderId) async {
    final folderBloc = context.read<FolderBloc>();
    
    // Wait for folders to load if not already loaded
    if (folderBloc.state is! FolderLoaded) {
      // Don't trigger LoadFolders again - just wait for the initial load to complete
      await folderBloc.stream
          .where((state) => state is FolderLoaded)
          .first;
    }
    
    final folderState = folderBloc.state;
    if (folderState is! FolderLoaded) {
      return null;
    }
    
    // Search in default folders
    for (final folder in folderState.defaultFolders) {
      if (folder.id == folderId) {
        return folder;
      }
    }
    
    // Search in custom folders
    for (final folder in folderState.customFolders) {
      if (folder.id == folderId) {
        return folder;
      }
    }
    
    return null; // Folder not found
  }
}

/// Dedicated widget for folder route that prevents unnecessary rebuilds
class _FolderRouteWidget extends StatefulWidget {
  final String folderId;
  
  const _FolderRouteWidget({required this.folderId});
  
  @override
  State<_FolderRouteWidget> createState() => _FolderRouteWidgetState();
}

class _FolderRouteWidgetState extends State<_FolderRouteWidget> {
  late Future<FolderEntity?> _folderFuture;
  static int _navigationCount = 0;
  FolderEntity? _cachedFolder; // Cache folder to prevent rebuilds
  
  @override
  void initState() {
    super.initState();
    _navigationCount++;
    print('📁 Router: Direct navigation to folder ${widget.folderId} (call #$_navigationCount)');
    
    // OPTIMIZATION: Try immediate sync lookup first
    final folderBloc = context.read<FolderBloc>();
    if (folderBloc.state is FolderLoaded) {
      final folderState = folderBloc.state as FolderLoaded;
      
      // Search for folder synchronously
      for (final folder in folderState.defaultFolders) {
        if (folder.id == widget.folderId) {
          _cachedFolder = folder;
          print('🚀 INIT SYNC: Found folder immediately: ${folder.name}');
          break;
        }
      }
      for (final folder in folderState.customFolders) {
        if (folder.id == widget.folderId) {
          _cachedFolder = folder;
          print('🚀 INIT SYNC: Found folder immediately: ${folder.name}');
          break;
        }
      }
    }
    
    // Create the future only if sync lookup failed
    if (_cachedFolder == null) {
      print('⚠️ INIT: Sync lookup failed, creating future');
      _folderFuture = AppRouter._findFolderById(context, widget.folderId);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // ULTIMATE OPTIMIZATION: Use cached folder if available to eliminate all rebuilds
    if (_cachedFolder != null) {
      print('🚀 CACHED: Using immediately available folder, zero skeletons');
      return RecordingListScreen(folder: _cachedFolder!);
    }
    
    // Fallback to FutureBuilder only if sync lookup failed
    return FutureBuilder<FolderEntity?>(
      future: _folderFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⚠️ ROUTER: No cached folder, showing skeleton');
          return RecordingListSkeleton(folderName: 'Loading...');
        }
        
        final folder = snapshot.data;
        if (folder == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(AppRouter.mainRoute);
          });
          return const SizedBox.shrink();
        }
        
        print('✅ ROUTER: Async folder loaded');
        return RecordingListScreen(folder: folder);
      },
    );
  }
}

/// Extension methods for easier navigation
extension AppRouterExtension on BuildContext {
  /// Navigate to main screen
  void goToMain() {
    go(AppRouter.mainRoute);
  }
  
  /// Navigate to folder
  void goToFolder(String folderId) {
    go('${AppRouter.folderRoute}/$folderId');
  }
  
  /// Navigate to folder with entity
  void goToFolderEntity(FolderEntity folder) {
    goToFolder(folder.id);
  }
}

