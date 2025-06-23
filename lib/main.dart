// File: main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'presentation/bloc/folder/folder_bloc.dart';
import 'presentation/bloc/recording/recording_bloc.dart';
import 'presentation/bloc/settings/settings_bloc.dart';
// Removed AudioPlayerBloc - using single AudioPlayer at screen level
import 'presentation/screens/main/main_screen.dart';
import 'data/database/database_helper.dart';
import 'data/repositories/recording_repository.dart';
import 'services/audio/audio_service_coordinator.dart';

/// Global singleton instances for the app
late final AudioServiceCoordinator globalAudioService;
late final RecordingRepository globalRecordingRepository;

/// Main entry point for the WavNote voice recording app
void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize database
    await DatabaseHelper.database;
    print('✅ Database initialized successfully');

    // Print database info for debugging
    final dbInfo = await DatabaseHelper.getDatabaseInfo();
    print('📊 Database Info: $dbInfo');

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
class WavNoteApp extends StatelessWidget {
  const WavNoteApp({super.key});

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
      child: MaterialApp(
        title: 'WavNote - Voice Memos',
        debugShowCheckedModeBanner: false,

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

        home: const DatabaseInitializer(),
      ),
    );
  }
}

/// Widget to initialize database and show main screen
class DatabaseInitializer extends StatefulWidget {
  const DatabaseInitializer({super.key});

  @override
  State<DatabaseInitializer> createState() => _DatabaseInitializerState();
}

class _DatabaseInitializerState extends State<DatabaseInitializer> {
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      // Ensure database is ready
      await DatabaseHelper.database;

      // Get database info for debugging
      final dbInfo = await DatabaseHelper.getDatabaseInfo();
      print('📊 Database ready: $dbInfo');

      setState(() {
        _isInitialized = true;
      });

    } catch (e) {
      print('❌ Database initialization failed: $e');
      setState(() {
        _isInitialized = false;
        _initError = 'Database error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized && _initError == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF8E2DE2),
                Color(0xFFDA22FF),
                Color(0xFFFF4E50),
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.yellowAccent),
                SizedBox(height: 24),
                Text(
                  'Initializing Database...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF8E2DE2),
                Color(0xFFDA22FF),
                Color(0xFFFF4E50),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  _initError!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeDatabase,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Database is ready, show main screen
    return const MainScreen();
  }
}