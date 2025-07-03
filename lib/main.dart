// File: main.dart
// 
// WavNote Voice Recording App - Main Entry Point
// ============================================
//
// This file serves as the main entry point for the WavNote application,
// a Flutter-based voice memo recording app featuring:
// - Clean Architecture with BLoC pattern for state management
// - Real-time audio recording with waveform visualization
// - Folder-based organization with geolocation-based naming
// - Advanced search and filtering capabilities
// - Export and sharing functionality
// - Midnight gospel inspired UI design
//
// Architecture Overview:
// - Presentation Layer: Screens, Widgets, BLoCs
// - Domain Layer: Entities, Use Cases, Repository Interfaces
// - Data Layer: Repository Implementations, Data Sources, Models
// - Services: Audio, File Management, Location, Permissions
// - Core: Utilities, Constants, Routing, Error Handling

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// BLoC imports for state management
import 'presentation/bloc/folder/folder_bloc.dart';      // Manages folder operations
import 'presentation/bloc/recording/recording_bloc.dart'; // Manages recording operations
import 'presentation/bloc/settings/settings_bloc.dart';   // Manages app settings

// Database and repository imports
import 'data/database/database_helper.dart';    // SQLite database helper
import 'data/database/database_pool.dart';      // High-performance database connection pool
import 'data/repositories/recording_repository.dart'; // Recording data access layer

// Service imports
import 'services/audio/audio_service_coordinator.dart'; // Audio recording and playback coordination
import 'services/location/geolocation_service.dart';    // GPS location services for recording naming

// Core imports
import 'core/routing/app_router.dart';                   // GoRouter configuration
import 'presentation/widgets/common/skeleton_screen.dart'; // Loading screen while app initializes

// ============================================
// GLOBAL SERVICE INSTANCES
// ============================================
// These are singleton instances shared across the entire app
// for optimal performance and resource management

/// Global audio service coordinator for managing recording and playback
/// Handles coordination between recording and playback services
late final AudioServiceCoordinator globalAudioService;

/// Global recording repository for database operations
/// Provides CRUD operations for recordings and folders
late final RecordingRepository globalRecordingRepository;

/// Global geolocation service for location-based features
/// Used to generate location-based recording names
late final GeolocationService globalGeolocationService;

// ============================================
// MAIN APPLICATION ENTRY POINT
// ============================================

/// Main entry point for the WavNote voice recording app
/// 
/// This function performs the following initialization steps:
/// 1. Initialize Flutter bindings
/// 2. Set up high-performance database connection pool
/// 3. Initialize core services (audio, location, repository)
/// 4. Launch the main application widget
/// 
/// The initialization order is critical for optimal performance:
/// - Database pool first for fastest data access
/// - Audio services second for recording capabilities
/// - Location services last as they're used less frequently
void main() async {
  // Ensure Flutter binding is initialized before any other operations
  // This is required for platform channel communication
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ========================================
    // DATABASE INITIALIZATION
    // ========================================
    
    // Initialize ultra-fast database connection pool FIRST
    // This provides the fastest possible data access throughout the app
    await DatabasePool.initialize();
    print('✅ Database pool initialized successfully');

    // Initialize regular database helper for compatibility with existing code
    // TODO: Migrate all database access to use the pool for better performance
    await DatabaseHelper.database;
    print('✅ Database helper initialized successfully');

    // Print database information for debugging and monitoring
    final dbInfo = await DatabaseHelper.getDatabaseInfo();
    print('📊 Database Info: $dbInfo');
    
    // Print database pool statistics for performance monitoring
    print('🏊‍♂️ Database Pool Stats: ${DatabasePool.stats}');

    // ========================================
    // SERVICE INITIALIZATION
    // ========================================
    
    // Create global service instances
    // These singletons ensure consistent state across the app
    globalAudioService = AudioServiceCoordinator();
    globalRecordingRepository = RecordingRepository();
    globalGeolocationService = GeolocationService();

    // Initialize audio service for recording and playback capabilities
    // This sets up the audio engine and checks for required permissions
    final audioInitialized = await globalAudioService.initialize();
    if (!audioInitialized) {
      print('❌ Failed to initialize audio service - recording may not work');
    } else {
      print('✅ Audio service initialized successfully');
    }

  } catch (e) {
    // Log initialization errors but continue app startup
    // The app should still be functional even if some services fail
    print('❌ Initialization error: $e');
  }

  // Launch the main application widget
  runApp(const WavNoteApp());
}

// ============================================
// ROOT APPLICATION WIDGET
// ============================================

/// Root application widget that sets up BLoC providers and app lifecycle management
/// 
/// This widget serves as the foundation of the entire application and is responsible for:
/// - Setting up global BLoC providers for state management
/// - Managing app lifecycle events (pause, resume, terminate)
/// - Handling database pool lifecycle
/// - Configuring the router and theme
/// - Providing error handling for initialization failures
class WavNoteApp extends StatefulWidget {
  const WavNoteApp({super.key});

  @override
  State<WavNoteApp> createState() => _WavNoteAppState();
}

/// State class for the root application widget
/// Implements WidgetsBindingObserver to monitor app lifecycle events
class _WavNoteAppState extends State<WavNoteApp> with WidgetsBindingObserver {
  // Store router future to prevent recreation on every build
  late final Future<GoRouter> _routerFuture;
  
  @override
  void initState() {
    super.initState();
    // Create router future once during initialization
    _routerFuture = AppRouter.createRouterAsync();
    // Register this widget as an observer for app lifecycle events
    // This allows us to respond to app state changes (foreground, background, etc.)
    WidgetsBinding.instance.addObserver(this);
  }
  
  /// Handle app lifecycle state changes for optimal resource management
  /// 
  /// This method is called whenever the app transitions between states:
  /// - paused: App goes to background (home button pressed, notification, etc.)
  /// - resumed: App returns to foreground 
  /// - detached: App is being terminated by the system
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App going to background - keep database pool alive for fast resume
        // This ensures instant data access when user returns to the app
        print('🏊‍♂️ App paused - keeping database pool alive for fast resume');
        break;
        
      case AppLifecycleState.resumed:
        // App resumed from background - verify pool is still ready
        // Log pool status for debugging performance issues
        print('🏊‍♂️ App resumed - database pool ready: ${DatabasePool.isReady}');
        break;
        
      case AppLifecycleState.detached:
        // App is being terminated by the system - clean up resources
        // Properly dispose of database connections to prevent memory leaks
        print('🏊‍♂️ App terminating - disposing database pool');
        DatabasePool.dispose();
        break;
        
      default:
        // Handle other states (inactive, hidden) - no action needed
        break;
    }
  }
  
  @override
  void dispose() {
    // Clean up when the widget is destroyed
    WidgetsBinding.instance.removeObserver(this);
    DatabasePool.dispose();
    super.dispose();
  }

  /// Build the root widget tree with BLoC providers and routing
  /// 
  /// This method sets up the entire application structure:
  /// 1. MultiBlocProvider - Provides global BLoCs to all child widgets
  /// 2. FutureBuilder - Handles async router creation
  /// 3. MaterialApp.router - Main app with routing configuration
  /// 4. Theme configuration - Midnight gospel inspired dark theme
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      // ========================================
      // GLOBAL BLOC PROVIDERS
      // ========================================
      // These BLoCs are available throughout the entire app
      providers: [
        // FolderBloc: Manages folder operations (create, delete, organize)
        BlocProvider(
          create: (context) => FolderBloc()..add(const LoadFolders()),
        ),
        
        // RecordingBloc: Manages recording operations (record, play, save, delete)
        // Injected with global services for audio, data, and location
        BlocProvider(
          create: (context) => RecordingBloc(
            audioService: globalAudioService,          // Audio recording and playback
            recordingRepository: globalRecordingRepository, // Data persistence
            geolocationService: globalGeolocationService,   // Location-based naming
          ),
        ),
        
        // SettingsBloc: Manages app settings (audio format, quality, preferences)
        BlocProvider(
          create: (context) => SettingsBloc()..add(const LoadSettings()),
        ),
        
        // Note: AudioPlayerBloc removed - using single AudioPlayer at screen level
        // This improves performance and reduces complexity
      ],
      
      // ========================================
      // ROUTER SETUP
      // ========================================
      // Use FutureBuilder to handle async router creation
      child: FutureBuilder<GoRouter>(
        future: _routerFuture,
        builder: (context, snapshot) {
          
          // Show loading screen while router is being created
          if (snapshot.connectionState == ConnectionState.waiting) {
            return MaterialApp(
              title: 'WavNote - Voice Memos',
              debugShowCheckedModeBanner: false,
              home: const SimpleSkeletonScreen(), // Beautiful skeleton instead of spinner
            );
          }
          
          // Show error screen if router creation fails
          if (snapshot.hasError) {
            print('❌ Router creation error: ${snapshot.error}');
            return MaterialApp(
              title: 'WavNote - Voice Memos',
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: Container(
                  // Use app's primary gradient color even in error state
                  color: const Color(0xFF8E2DE2),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load app\n${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            // Trigger a rebuild to retry router creation
                            // setState(() {}) would work here but this button is currently non-functional
                            // TODO: Implement proper retry mechanism
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.yellowAccent,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          
          // ========================================
          // MAIN APPLICATION WITH ROUTER
          // ========================================
          // Router is ready - create the main application
          return MaterialApp.router(
            title: 'WavNote - Voice Memos',
            debugShowCheckedModeBanner: false,
            
            // Development flags for debugging and performance monitoring
            showPerformanceOverlay: false, // Set to true to see FPS/GPU metrics
            showSemanticsDebugger: false, // Set to true to see accessibility info
            
            // Use the router configuration created asynchronously
            routerConfig: snapshot.data!,

            // ========================================
            // MIDNIGHT GOSPEL INSPIRED THEME
            // ========================================
            // Dark theme with cosmic/mystical color palette
            theme: ThemeData(
              // Base theme settings
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.transparent, // Allow gradient backgrounds
              fontFamily: 'Roboto', // Clean, readable font
              
              // Color scheme inspired by midnight gospel aesthetics
              colorScheme: const ColorScheme.dark(
                primary: Colors.yellowAccent,      // Bright accent for CTAs
                secondary: Colors.cyan,            // Cool accent for secondary actions
                surface: Color(0xFF5A2B8C),       // Deep purple for surfaces
                onSurface: Colors.white,          // White text on dark surfaces
              ),
              
              // App bar styling - transparent to show gradient backgrounds
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,                     // Flat design
                centerTitle: true,
                titleTextStyle: TextStyle(
                  color: Colors.yellowAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // Primary button styling - bright yellow for important actions
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellowAccent,
                  foregroundColor: Colors.black,  // Black text on yellow background
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  elevation: 4,                   // Subtle shadow for depth
                ),
              ),
              
              // Secondary button styling - cyan for secondary actions
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.cyan,
                ),
              ),
              
              // Input field styling - consistent with cosmic theme
              inputDecorationTheme: InputDecorationTheme(
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.yellowAccent),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.yellowAccent, width: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

