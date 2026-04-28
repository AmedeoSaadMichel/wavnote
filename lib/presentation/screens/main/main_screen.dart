// File: lib/presentation/screens/main/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/folder/folder_bloc.dart';
import '../../bloc/recording/recording_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../widgets/dialogs/create_folder_dialog.dart';
import '../../widgets/dialogs/audio_format_dialog.dart';
import '../../../core/routing/app_router.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../../core/enums/audio_format.dart';
import 'main_screen_header.dart';
import 'main_screen_folders.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  FolderEntity? _selectedFolder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleExpiredRecordingsCleanup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      BlocProvider.of<FolderBloc>(context).add(const RefreshFolders());
    }
  }

  void _scheduleExpiredRecordingsCleanup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingBloc>().add(const CleanupExpiredRecordings());
    });
  }

  void _showCreateFolderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return CreateFolderDialog(
          onFolderCreated: (String name, Color color, IconData icon) {
            BlocProvider.of<FolderBloc>(context).add(CreateFolder(
              name: name,
              iconCodePoint: icon.codePoint,
              colorValue: color.toARGB32(),
            ));
          },
        );
      },
    );
  }

  void _showAudioFormatDialog() {
    AudioFormat currentFormat = AudioFormat.m4a;
    final settingsState = context.read<SettingsBloc>().state;
    if (settingsState is SettingsLoaded) {
      currentFormat = settingsState.settings.audioFormat;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AudioFormatDialog(
          currentFormat: currentFormat,
          onFormatSelected: (AudioFormat format) {
            context.read<SettingsBloc>().add(UpdateAudioFormat(format));
          },
        );
      },
    );
  }

  void _toggleEditMode() {
    context.read<FolderBloc>().add(const ToggleFolderEditMode());
  }

  void _deleteSelectedFolders() {
    final folderBloc = context.read<FolderBloc>();
    final folderState = folderBloc.state;
    if (folderState is! FolderLoaded || !folderState.hasSelectedFolders) return;

    final selectedFolders = folderState.selectedFolders;
    final selectedFolderIds = folderState.selectedFolderIds.toList();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Delete Folders',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete ${selectedFolders.length} folder${selectedFolders.length == 1 ? '' : 's'}? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                folderBloc.add(
                  DeleteSelectedFolders(folderIds: selectedFolderIds),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _onFolderDelete(FolderEntity folder) {
    if (!folder.canBeDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${folder.name} cannot be deleted'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final mainContext = context;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Delete Folder',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${folder.name}"? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                BlocProvider.of<FolderBloc>(mainContext)
                    .add(DeleteFolder(folderId: folder.id));
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _onFolderTap(FolderEntity folder) {
    setState(() => _selectedFolder = folder);
    context.read<SettingsBloc>().add(UpdateLastOpenedFolder(folder.id));
    context.goToFolderEntity(folder);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8E2DE2), Color(0xFFDA22FF), Color(0xFFFF4E50)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              MainScreenHeader(
                selectedFolder: _selectedFolder,
                onFolderDeselected: () =>
                    setState(() => _selectedFolder = null),
                onToggleEditMode: _toggleEditMode,
                onDeleteSelected: _deleteSelectedFolders,
                onShowFormatDialog: _showAudioFormatDialog,
              ),
              Expanded(child: _buildFoldersContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoldersContent() {
    return BlocConsumer<FolderBloc, FolderState>(
      listener: (context, state) {
        if (state is FolderError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        } else if (state is FolderCreated) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Created folder: ${state.createdFolder.name}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        } else if (state is FolderDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Deleted folder: ${state.deletedFolderName}'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ));
        } else if (state is FoldersDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Deleted ${state.deletedCount} folder${state.deletedCount == 1 ? '' : 's'}',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      builder: (context, state) {
        if (state is FolderLoading) return _buildLoadingState();
        if (state is FolderError) return _buildErrorState(state);
        if (state is FolderLoaded) {
          return MainScreenFoldersContent(
            state: state,
            onFolderTap: _onFolderTap,
            onFolderLongPress: (folder) =>
                setState(() => _selectedFolder = folder),
            onFolderDelete: _onFolderDelete,
            onCreateFolder: _showCreateFolderDialog,
          );
        }
        return _buildInitialState();
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.yellowAccent, strokeWidth: 3),
          SizedBox(height: 16),
          Text(
            'Loading your folders...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(FolderError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Error loading folders',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () =>
                BlocProvider.of<FolderBloc>(context).add(const LoadFolders()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellowAccent,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Text(
        'Initializing...',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 16,
        ),
      ),
    );
  }
}
