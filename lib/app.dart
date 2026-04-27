// File: lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'config/dependency_injection.dart';
import 'core/routing/app_router.dart';
import 'data/database/database_helper.dart';
import 'domain/repositories/i_audio_recording_repository.dart';
import 'domain/repositories/i_folder_repository.dart';
import 'domain/repositories/i_location_repository.dart';
import 'domain/repositories/i_recording_repository.dart';
import 'domain/repositories/i_settings_repository.dart';
import 'presentation/bloc/folder/folder_bloc.dart';
import 'presentation/bloc/recording/recording_bloc.dart';
import 'presentation/bloc/settings/settings_bloc.dart';
import 'presentation/widgets/common/skeleton_screen.dart';

class WavNoteApp extends StatefulWidget {
  const WavNoteApp({super.key});

  @override
  State<WavNoteApp> createState() => _WavNoteAppState();
}

class _WavNoteAppState extends State<WavNoteApp> with WidgetsBindingObserver {
  late final Future<GoRouter> _routerFuture;

  @override
  void initState() {
    super.initState();
    _routerFuture = AppRouter.createRouterAsync();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      DatabaseHelper.closeDatabase();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              FolderBloc(folderRepository: sl<IFolderRepository>())
                ..add(const LoadFolders()),
        ),
        BlocProvider(
          create: (context) => RecordingBloc(
            audioService: sl<IAudioRecordingRepository>(),
            recordingRepository: sl<IRecordingRepository>(),
            locationRepository: sl<ILocationRepository>(),
            folderBloc: context.read<FolderBloc>(),
          ),
        ),
        BlocProvider(
          create: (context) =>
              SettingsBloc(settingsRepository: sl<ISettingsRepository>())
                ..add(const LoadSettings()),
        ),
      ],
      child: FutureBuilder<GoRouter>(
        future: _routerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MaterialApp(
              title: 'WavNote - Voice Memos',
              debugShowCheckedModeBanner: false,
              home: SimpleSkeletonScreen(),
            );
          }

          if (snapshot.hasError) {
            debugPrint('❌ Router creation error: ${snapshot.error}');
            return MaterialApp(
              title: 'WavNote - Voice Memos',
              debugShowCheckedModeBanner: false,
              home: _RouterErrorScreen(error: snapshot.error),
            );
          }

          return MaterialApp.router(
            title: 'WavNote - Voice Memos',
            debugShowCheckedModeBanner: false,
            showPerformanceOverlay: false,
            showSemanticsDebugger: false,
            routerConfig: snapshot.data!,
            theme: _buildTheme(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
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
        style: TextButton.styleFrom(foregroundColor: Colors.cyan),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.yellowAccent),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.yellowAccent, width: 2),
        ),
      ),
    );
  }
}

class _RouterErrorScreen extends StatelessWidget {
  const _RouterErrorScreen({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF8E2DE2),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'Failed to load app\n$error',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: null,
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
    );
  }
}
