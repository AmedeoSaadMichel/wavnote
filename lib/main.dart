// File: main.dart - Added RecordingBloc provider

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'presentation/blocs/folder/folder_bloc.dart';
import 'presentation/blocs/recording/recording_bloc.dart';  // ✅ Added import
import 'presentation/screens/main/main_screen.dart';
import 'services/audio/audio_recorder_service.dart';  // ✅ Added import

/// Main entry point for the WavNote voice recording app
void main() {
  runApp(const WavNoteApp());
}

/// Root application widget
class WavNoteApp extends StatelessWidget {
  const WavNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            color: Colors.white.withOpacity(0.5),
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.yellowAccent),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.yellowAccent, width: 2),
          ),
        ),
      ),

      // ✅ FIXED: Added MultiBlocProvider with both FolderBloc and RecordingBloc
      home: MultiBlocProvider(
        providers: [
          // Folder management
          BlocProvider<FolderBloc>(
            create: (context) => FolderBloc()..add(const LoadFolders()),
          ),

          // Recording management
          BlocProvider<RecordingBloc>(
            create: (context) {
              final audioService = AudioRecorderService();
              return RecordingBloc(audioService: audioService)
                ..add(const CheckRecordingPermissions());
            },
          ),
        ],
        child: const AudioServiceInitializer(),
      ),
    );
  }
}

/// Widget to initialize audio service and show main screen
class AudioServiceInitializer extends StatefulWidget {
  const AudioServiceInitializer({super.key});

  @override
  State<AudioServiceInitializer> createState() => _AudioServiceInitializerState();
}

class _AudioServiceInitializerState extends State<AudioServiceInitializer> {
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeAudioService();
  }

  Future<void> _initializeAudioService() async {
    try {
      // Get the audio service from the RecordingBloc
      final recordingBloc = context.read<RecordingBloc>();
      // For now, just mark as initialized since our service is simple
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _initError = 'Audio service error: $e';
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
                  'Initializing Audio Service...',
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
                  onPressed: _initializeAudioService,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const MainScreen();
  }
}