// File: presentation/screens/main/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import '../../bloc/folder/folder_bloc.dart';
import '../../widgets/folder/folder_item.dart';
import '../../widgets/dialogs/create_folder_dialog.dart';
import '../../widgets/dialogs/audio_format_dialog.dart';
import '../recording/recording_list_screen.dart';

import '../../../domain/entities/folder_entity.dart';
import '../../../core/enums/audio_format.dart';

/// Main screen displaying voice memo folders with enhanced recording integration
///
/// This screen shows default and custom folders using the Bloc pattern
/// for state management and includes a floating action button for quick recording.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _selectedAudioFormat = 'M4A'; // Default to M4A for iOS
  FolderEntity? _selectedFolder;

  @override
  void initState() {
    super.initState();

    // Load folders when screen initializes
    BlocProvider.of<FolderBloc>(context).add(const LoadFolders());
    _loadAudioFormat();
  }

  /// Load current audio format from settings
  void _loadAudioFormat() {
    setState(() {
      _selectedAudioFormat = 'M4A'; // Default for iOS
    });
  }

  /// Show dialog to create a new custom folder
  void _showCreateFolderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return CreateFolderDialog(
          onFolderCreated: (String name, Color color, IconData icon) {
            BlocProvider.of<FolderBloc>(context).add(CreateFolder(
              name: name,
              color: color,
              icon: icon,
            ));
          },
        );
      },
    );
  }

  /// Show dialog to select audio recording format
  void _showAudioFormatDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AudioFormatDialog(
          currentFormat: _getAudioFormatFromString(_selectedAudioFormat),
          onFormatSelected: (AudioFormat format) {
            setState(() {
              _selectedAudioFormat = format.name;
            });
            // TODO: Save to settings service when implemented
          },
        );
      },
    );
  }

  /// Convert string to AudioFormat enum
  AudioFormat _getAudioFormatFromString(String formatString) {
    switch (formatString.toLowerCase()) {
      case 'wav':
        return AudioFormat.wav;
      case 'm4a':
        return AudioFormat.m4a;
      case 'flac':
        return AudioFormat.flac;
      default:
        return AudioFormat.m4a; // Default to M4A for iOS
    }
  }

  /// Handle folder tap navigation
  void _onFolderTap(FolderEntity folder) {
    setState(() {
      _selectedFolder = folder;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordingListScreen(folder: folder),
      ),
    );
  }

  /// Handle folder deletion with confirmation
  void _onFolderDelete(FolderEntity folder) {
    if (!folder.canBeDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${folder.name} cannot be deleted'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final mainContext = context;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Delete Folder',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                BlocProvider.of<FolderBloc>(mainContext).add(DeleteFolder(folderId: folder.id));
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              _buildHeader(),

              // Folders List Section - Made scrollable
              Expanded(
                child: _buildFoldersContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the header with title, format selector, and quick record button
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Main header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Voice Memos',
                    style: TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Audio Format Selector
                  GestureDetector(
                    onTap: _showAudioFormatDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A2B8C).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getAudioFormatFromString(_selectedAudioFormat).icon,
                            color: _getAudioFormatFromString(_selectedAudioFormat).color,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _selectedAudioFormat,
                            style: TextStyle(
                              color: _getAudioFormatFromString(_selectedAudioFormat).color,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Edit Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A2B8C).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.cyan,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Selected folder indicator (if any)
          if (_selectedFolder != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedFolder!.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedFolder!.color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedFolder!.icon,
                    color: _selectedFolder!.color,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Selected: ${_selectedFolder!.name}',
                    style: TextStyle(
                      color: _selectedFolder!.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _selectedFolder = null),
                    child: Icon(
                      Icons.close,
                      color: _selectedFolder!.color,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build the main folders content with Bloc state management
  Widget _buildFoldersContent() {
    return BlocConsumer<FolderBloc, FolderState>(
      listener: (context, state) {
        if (state is FolderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is FolderCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created folder: ${state.createdFolder.name}'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is FolderDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted folder: ${state.deletedFolderName}'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is FolderLoading) {
          return _buildLoadingState();
        }

        if (state is FolderError) {
          return _buildErrorState(state);
        }

        if (state is FolderLoaded) {
          return _buildLoadedState(state);
        }

        return _buildInitialState();
      },
    );
  }

  /// Build loading state widget
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.yellowAccent,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading your folders...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Build error state widget
  Widget _buildErrorState(FolderError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
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
            onPressed: () {
              BlocProvider.of<FolderBloc>(context).add(const LoadFolders());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellowAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Build loaded state with folders - SCROLLABLE CONTENT WITHOUT ADD BUTTON
  Widget _buildLoadedState(FolderLoaded state) {
    return Column(
      children: [
        // SCROLLABLE FOLDERS SECTION
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CustomScrollView(
              slivers: [
                // Default Folders Section
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final folder = state.defaultFolders[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => _onFolderTap(folder),
                          onLongPress: () => setState(() => _selectedFolder = folder),
                          child: FolderItem(
                            folder: folder,
                            onTap: () => _onFolderTap(folder),
                          ),
                        ),
                      );
                    },
                    childCount: state.defaultFolders.length,
                  ),
                ),

                // Custom Folders Section Header
                if (state.hasCustomFolders) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 16),
                      child: Text(
                        'MY FOLDERS',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  // Custom Folders List - SCROLLABLE
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final folder = state.customFolders[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Dismissible(
                            key: Key(folder.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                FontAwesome5.skull,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              _onFolderDelete(folder);
                              return false; // Don't auto-dismiss, let the Bloc handle it
                            },
                            child: GestureDetector(
                              onTap: () => _onFolderTap(folder),
                              onLongPress: () => setState(() => _selectedFolder = folder),
                              child: FolderItem(
                                folder: folder,
                                onTap: () => _onFolderTap(folder),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: state.customFolders.length,
                    ),
                  ),
                ],

                // Extra space at bottom for better scrolling
                SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            ),
          ),
        ),

        // FIXED ADD FOLDER BUTTON AT BOTTOM
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildAddFolderButton(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  /// Build initial loading state
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

  /// Build the add folder button
  Widget _buildAddFolderButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF5A2B8C).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showCreateFolderDialog,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_outlined, size: 20, color: Colors.yellowAccent),
                SizedBox(width: 8),
                Text(
                  'Add Folder',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.yellowAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}