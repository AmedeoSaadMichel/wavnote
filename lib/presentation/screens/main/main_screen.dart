// File: presentation/screens/main/main_screen.dart
// 
// Main Screen - Presentation Layer
// ===============================
//
// The primary screen of the WavNote app, displaying the folder organization interface.
// This screen serves as the main entry point where users can:
//
// Core Features:
// - View all voice memo folders (default and custom)
// - Create new custom folders with icons and colors
// - Navigate to individual folder contents
// - Configure audio recording settings (format, quality)
// - Perform bulk operations on folders (multi-select delete)
// - Access app settings and preferences
//
// Architecture:
// - Uses BLoC pattern for state management
// - Implements Clean Architecture principles
// - Responsive design with midnight gospel inspired UI
// - Optimized performance with database connection pooling
//
// Key BLoCs:
// - FolderBloc: Manages folder CRUD operations
// - RecordingBloc: Handles recording lifecycle and cleanup
// - SettingsBloc: Manages app configuration
//
// UI Features:
// - Gradient background with cosmic color scheme
// - Card-based folder layout with glassmorphism effects
// - Edit mode with multi-selection capabilities
// - Real-time folder count updates
// - Smooth animations and transitions

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// BLoC imports for state management
import '../../bloc/folder/folder_bloc.dart';      // Folder operations
import '../../bloc/recording/recording_bloc.dart'; // Recording operations
import '../../bloc/settings/settings_bloc.dart';   // App settings

// Widget imports
import '../../widgets/folder/folder_item.dart';           // Individual folder display
import '../../widgets/dialogs/create_folder_dialog.dart'; // Folder creation dialog
import '../../widgets/dialogs/audio_format_dialog.dart';  // Audio format selection

// Core imports
import '../../../core/routing/app_router.dart';       // Navigation routing
import '../../../data/database/database_pool.dart';   // High-performance database access

// Domain imports
import '../../../domain/entities/folder_entity.dart'; // Folder business entity
import '../../../core/enums/audio_format.dart';       // Audio format options

/// Main screen displaying voice memo folders with enhanced recording integration
///
/// This screen shows default and custom folders using the Bloc pattern
/// for state management and includes a floating action button for quick recording.
///
/// Key responsibilities:
/// - Display folder hierarchy with real-time count updates
/// - Handle folder creation, deletion, and organization
/// - Provide access to audio format configuration
/// - Manage app lifecycle events for optimal performance
/// - Coordinate with database pool for ultra-fast data access
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

    // Note: LoadFolders is already called in main.dart when creating the FolderBloc provider
    // No need to call it again here to avoid double loading
    
    // Clean up expired recordings (15+ days old) on app start
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
    
    // Refresh folder counts when app resumes
    if (state == AppLifecycleState.resumed && mounted) {
      print('📱 App resumed - refreshing folder counts');
      BlocProvider.of<FolderBloc>(context).add(const RefreshFolders());
    }
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
    // Get current format from settings
    AudioFormat currentFormat = AudioFormat.m4a; // Default fallback
    final settingsBloc = context.read<SettingsBloc>();
    final settingsState = settingsBloc.state;
    
    if (settingsState is SettingsLoaded) {
      currentFormat = settingsState.settings.audioFormat;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AudioFormatDialog(
          currentFormat: currentFormat,
          onFormatSelected: (AudioFormat format) {
            // Update settings with selected format
            context.read<SettingsBloc>().add(UpdateAudioFormat(format));
          },
        );
      },
    );
  }

  /// Schedule cleanup of expired recordings (15+ days old)
  void _scheduleExpiredRecordingsCleanup() {
    // Clean up expired recordings in Recently Deleted folder
    // This runs once when the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🧹 Scheduling expired recordings cleanup...');
      context.read<RecordingBloc>().add(const CleanupExpiredRecordings());
    });
  }

  /// Handle folder tap navigation using GoRouter
  void _onFolderTap(FolderEntity folder) {
    setState(() {
      _selectedFolder = folder;
    });

    // Save folder choice using ultra-fast database pool
    print('📁 MainScreen: User selected folder ${folder.name}, saving with pool');
    DatabasePool.saveLastFolderId(folder.id); // Ultra-fast save
    context.read<SettingsBloc>().add(UpdateLastOpenedFolder(folder.id)); // Also update BLoC

    // Navigate to folder
    context.goToFolderEntity(folder);
  }

  /// Toggle edit mode for multi-selection
  void _toggleEditMode() {
    context.read<FolderBloc>().add(const ToggleFolderEditMode());
  }

  /// Delete selected folders with confirmation
  void _deleteSelectedFolders() {
    final folderBloc = context.read<FolderBloc>();
    final folderState = folderBloc.state;
    
    if (folderState is! FolderLoaded || !folderState.hasSelectedFolders) {
      return;
    }

    final selectedFolders = folderState.selectedFolders;
    final selectedFolderIds = folderState.selectedFolderIds.toList();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Delete Folders',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                folderBloc.add(DeleteSelectedFolders(folderIds: selectedFolderIds));
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

  /// Build the header with title, format selector, and edit button
  Widget _buildHeader() {
    return BlocBuilder<FolderBloc, FolderState>(
      builder: (context, folderState) {
        final isEditMode = folderState is FolderLoaded ? folderState.isEditMode : false;
        final hasSelectedFolders = folderState is FolderLoaded ? folderState.hasSelectedFolders : false;

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
                      // Audio Format Selector (hidden in edit mode)
                      if (!isEditMode) BlocBuilder<SettingsBloc, SettingsState>(
                        builder: (context, settingsState) {
                          AudioFormat currentFormat = AudioFormat.m4a; // Default
                          if (settingsState is SettingsLoaded) {
                            currentFormat = settingsState.settings.audioFormat;
                          }
                          
                          return GestureDetector(
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
                                    currentFormat.icon,
                                    color: currentFormat.color,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    currentFormat.name,
                                    style: TextStyle(
                                      color: currentFormat.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  // Edit Button or action buttons
                  Row(
                    children: [
                      if (isEditMode && hasSelectedFolders) ...[
                        // Delete selected folders button
                        GestureDetector(
                          onTap: _deleteSelectedFolders,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              children: [
                                FaIcon(FontAwesomeIcons.skull, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Edit/Done toggle button
                      GestureDetector(
                        onTap: _toggleEditMode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A2B8C).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isEditMode ? 'Done' : 'Edit',
                            style: const TextStyle(
                              color: Colors.cyan,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Selection status indicator in edit mode
              if (isEditMode) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${folderState.selectedFoldersCount} folder${folderState.selectedFoldersCount == 1 ? '' : 's'} selected',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              // Selected folder indicator (if any and not in edit mode)
              if (_selectedFolder != null && !isEditMode) ...[
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
      },
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
        } else if (state is FoldersDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${state.deletedCount} folder${state.deletedCount == 1 ? '' : 's'}'),
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

                  // Custom Folders List - SCROLLABLE with edit mode support
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final folder = state.customFolders[index];
                        final isSelected = state.isFolderSelected(folder.id);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: state.isEditMode
                              ? _buildEditableFolderItem(folder, isSelected, state)
                              : _buildNormalFolderItem(folder),
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

        // FIXED ADD FOLDER BUTTON AT BOTTOM (hidden in edit mode)
        if (!state.isEditMode) Padding(
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

  /// Build folder item in normal mode (with dismissible delete)
  Widget _buildNormalFolderItem(FolderEntity folder) {
    return Dismissible(
      key: Key(folder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const FaIcon(
          FontAwesomeIcons.skull,
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
    );
  }

  /// Build folder item in edit mode (with selection checkbox)
  Widget _buildEditableFolderItem(FolderEntity folder, bool isSelected, FolderLoaded state) {
    return GestureDetector(
      onTap: () {
        // Toggle selection when tapped in edit mode
        context.read<FolderBloc>().add(ToggleFolderSelection(folderId: folder.id));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: isSelected 
              ? Border.all(color: Colors.blue, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            // Folder item
            FolderItem(
              folder: folder,
              onTap: () => context.read<FolderBloc>().add(ToggleFolderSelection(folderId: folder.id)),
            ),
            // Selection checkbox
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.blue : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ),
          ],
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