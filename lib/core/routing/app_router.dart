// File: core/routing/app_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/main/main_screen.dart';
import '../../presentation/screens/recording/recording_list_screen.dart';
import '../../domain/entities/folder_entity.dart';
import '../../presentation/bloc/folder/folder_bloc.dart';
import '../../data/database/database_pool.dart';

/// Centralized route management for the WavNote app
/// 
/// Handles navigation state persistence and restoration automatically
class AppRouter {
  static const String mainRoute = '/';
  static const String folderRoute = '/folder';
  
  // Main screen treated as a special folder for consistent state management
  static const String mainFolderId = 'main';
  
  /// Create router asynchronously with ultra-fast database pool
  static Future<GoRouter> createRouterAsync() async {
    final stopwatch = Stopwatch()..start();
    print('📁 AppRouter: Creating async router with ultra-fast database pool');
    print('🏊‍♂️ AppRouter: Database pool ready: ${DatabasePool.isReady}');
    
    // CRITICAL: Wait for database pool to be fully initialized
    if (!DatabasePool.isReady) {
      print('⏳ AppRouter: Waiting for database pool initialization...');
      await DatabasePool.waitForInitialization();
      print('✅ AppRouter: Database pool initialization complete');
    }
    
    // Use ultra-fast database pool instead of slow settings loading
    final lastFolderId = await DatabasePool.getLastFolderId();
    
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
    print('⚡ AppRouter: Router created in ${stopwatch.elapsedMilliseconds}ms (database pool enabled)');
    
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
        
        // Folder/Recording list route
        GoRoute(
          path: '$folderRoute/:folderId',
          name: 'folder',
          builder: (context, state) {
            final folderId = state.pathParameters['folderId']!;
            
            // Router only handles navigation, no state saving
            print('📁 Router: Navigating to folder $folderId (no auto-save)');
            
            return FutureBuilder<FolderEntity?>(
              future: _findFolderById(context, folderId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                final folder = snapshot.data;
                if (folder == null) {
                  // Folder not found, redirect to main
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    context.go(mainRoute);
                  });
                  return const SizedBox.shrink();
                }
                
                return RecordingListScreen(folder: folder);
              },
            );
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
    
    // Ensure folders are loaded
    if (folderBloc.state is! FolderLoaded) {
      folderBloc.add(const LoadFolders());
      
      // Wait for folders to load
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

