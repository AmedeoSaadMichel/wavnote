// File: main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'presentation/bloc/folder/folder_bloc.dart';
import 'presentation/bloc/recording/recording_bloc.dart';
import 'presentation/bloc/settings/settings_bloc.dart';
// Removed AudioPlayerBloc - using single AudioPlayer at screen level
import 'data/database/database_helper.dart';
import 'data/database/database_pool.dart';
import 'data/repositories/recording_repository.dart';
import 'services/audio/audio_service_coordinator.dart';
import 'core/routing/app_router.dart';
import 'presentation/widgets/common/skeleton_screen.dart';

/// Global singleton instances for the app
late final AudioServiceCoordinator globalAudioService;
late final RecordingRepository globalRecordingRepository;

/// Main entry point for the WavNote voice recording app
void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize database connection pool FIRST for fastest startup
    await DatabasePool.initialize();
    print('✅ Database pool initialized successfully');

    // Initialize regular database helper (for compatibility)
    await DatabaseHelper.database;
    print('✅ Database helper initialized successfully');

    // Print database info for debugging
    final dbInfo = await DatabaseHelper.getDatabaseInfo();
    print('📊 Database Info: $dbInfo');
    
    // Print pool stats
    print('🏊‍♂️ Database Pool Stats: ${DatabasePool.stats}');

    // Create and initialize global services
    globalAudioService = AudioServiceCoordinator();
    globalRecordingRepository = RecordingRepository();

    // Initialize audio service
    final audioInitialized = await globalAudioService.initialize();
    if (!audioInitialized) {
      print('❌ Failed to initialize audio service');
    } else {
      print('✅ Audio service initialized successfully');
    }

  } catch (e) {
    print('❌ Initialization error: $e');
  }

  runApp(const WavNoteApp());
}

/// Root application widget with BLoC providers
class WavNoteApp extends StatefulWidget {
  const WavNoteApp({super.key});

  @override
  State<WavNoteApp> createState() => _WavNoteAppState();
}

class _WavNoteAppState extends State<WavNoteApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background - keep database pool alive for fast resume
      print('🏊‍♂️ App paused - keeping database pool alive');
    } else if (state == AppLifecycleState.resumed) {
      // App resumed - pool should still be ready
      print('🏊‍♂️ App resumed - database pool ready: ${DatabasePool.isReady}');
    } else if (state == AppLifecycleState.detached) {
      // App is being terminated - dispose pool
      print('🏊‍♂️ App terminating - disposing database pool');
      DatabasePool.dispose();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DatabasePool.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => FolderBloc()..add(const LoadFolders()),
        ),
        BlocProvider(
          create: (context) => RecordingBloc(
            audioService: globalAudioService,
            recordingRepository: globalRecordingRepository,
          ),
        ),
        BlocProvider(
          create: (context) => SettingsBloc()..add(const LoadSettings()),
        ),
        // Removed AudioPlayerBloc - using single AudioPlayer at screen level
      ],
      child: FutureBuilder<GoRouter>(
        future: AppRouter.createRouterAsync(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return MaterialApp(
              title: 'WavNote - Voice Memos',
              debugShowCheckedModeBanner: false,
              home: const SimpleSkeletonScreen(), // Beautiful skeleton instead of spinner
            );
          }
          
          if (snapshot.hasError) {
            print('❌ Router creation error: ${snapshot.error}');
            return MaterialApp(
              title: 'WavNote - Voice Memos',
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: Container(
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
                            // Trigger a rebuild to retry
                            // This is a simple way to retry the router creation
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
          
          return MaterialApp.router(
            title: 'WavNote - Voice Memos',
            debugShowCheckedModeBanner: false,
            
            routerConfig: snapshot.data!,

            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.transparent,
              fontFamily: 'Roboto',
              colorScheme: const ColorScheme.dark(
                primary: Colors.yellowAccent,
                secondary: Colors.cyan,
                surface: Color(0xFF5A2B8C),
                onSurface: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: TextStyle(
                  color: Colors.yellowAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellowAccent,
                  foregroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  elevation: 4,
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.cyan,
                ),
              ),
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

