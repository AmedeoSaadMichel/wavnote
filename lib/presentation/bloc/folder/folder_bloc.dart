// File: presentation/bloc/folder/folder_bloc.dart
// 
// Folder BLoC - Presentation Layer
// ===============================
//
// State management for voice memo folder operations in the WavNote app.
// This BLoC handles all folder-related UI interactions and coordinates with
// the data layer for persistent storage of folder information.
//
// Key Responsibilities:
// - Load and manage default system folders (All Recordings, Favorites, Recently Deleted)
// - Handle custom user folder creation, deletion, and modification
// - Manage folder organization and recording count updates
// - Provide edit mode functionality with multi-selection capabilities
// - Coordinate folder operations with database persistence
//
// Architecture Features:
// - Implements BLoC pattern for reactive state management
// - Uses Clean Architecture with repository dependency
// - Maintains immutable state with Equatable
// - Handles async operations with proper error management
// - Provides real-time folder count updates
//
// Folder Types:
// - Default Folders: System-provided folders that cannot be deleted
//   - All Recordings: Contains all user recordings
//   - Favorites: Contains user-marked favorite recordings
//   - Recently Deleted: Contains soft-deleted recordings (15-day retention)
// - Custom Folders: User-created folders with custom icons and colors
//
// State Management:
// - FolderInitial: Initial loading state
// - FolderLoading: Loading folders from database
// - FolderLoaded: Folders loaded with counts and edit capabilities
// - FolderError: Error states with descriptive messages
// - FolderCreated: Folder successfully created
// - FolderDeleted: Folder successfully deleted
//
// Edit Mode Features:
// - Multi-selection of custom folders for bulk operations
// - Bulk deletion with confirmation dialogs
// - Edit mode toggle for better UX
// - Selection state management

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

// Domain imports
import '../../../domain/entities/folder_entity.dart';   // Folder business entity

// Data layer imports
import '../../../data/repositories/folder_repository.dart'; // Folder data access

// BLoC parts
part 'folder_event.dart'; // Folder events (user actions)
part 'folder_state.dart'; // Folder states (app states)

/// BLoC responsible for managing folder state and operations
///
/// Handles folder loading, creation, deletion, and updates.
/// Uses real repository for persistent storage.
///
/// Key features:
/// - Default and custom folder management
/// - Real-time recording count updates
/// - Multi-selection edit mode for bulk operations
/// - Persistent storage with SQLite database
/// - Error handling with user-friendly messages
///
/// Example usage:
/// ```dart
/// // Load folders
/// context.read<FolderBloc>().add(const LoadFolders());
/// 
/// // Create custom folder
/// context.read<FolderBloc>().add(CreateFolder(
///   name: 'My Folder',
///   color: Colors.blue,
///   icon: Icons.folder,
/// ));
/// 
/// // Listen to state changes
/// BlocBuilder<FolderBloc, FolderState>(
///   builder: (context, state) {
///     if (state is FolderLoaded) {
///       return ListView(children: state.allFolders.map(...));
///     }
///     return CircularProgressIndicator();
///   },
/// );
/// ```
class FolderBloc extends Bloc<FolderEvent, FolderState> {
  final FolderRepository _folderRepository = FolderRepository();

  FolderBloc() : super(const FolderInitial()) {
    on<LoadFolders>(_onLoadFolders);
    on<RefreshFolders>(_onRefreshFolders);
    on<CreateFolder>(_onCreateFolder);
    on<DeleteFolder>(_onDeleteFolder);
    on<UpdateFolderCount>(_onUpdateFolderCount);
    on<RenameFolderEvent>(_onRenameFolder);
    on<ToggleFolderEditMode>(_onToggleFolderEditMode);
    on<ToggleFolderSelection>(_onToggleFolderSelection);
    on<ClearFolderSelection>(_onClearFolderSelection);
    on<DeleteSelectedFolders>(_onDeleteSelectedFolders);
  }

  /// Load all folders (default + custom)
  Future<void> _onLoadFolders(
      LoadFolders event,
      Emitter<FolderState> emit,
      ) async {
    emit(const FolderLoading());

    try {
      // Get all folders from repository (includes default + custom)
      final allFolders = await _folderRepository.getAllFolders();

      // Separate default and custom folders
      final defaultFolders = allFolders.where((f) => f.isDefault).toList();
      final customFolders = allFolders.where((f) => f.isCustom).toList();

      emit(FolderLoaded(
        defaultFolders: defaultFolders,
        customFolders: customFolders,
      ));

      print('✅ Loaded ${defaultFolders.length} default and ${customFolders.length} custom folders');

    } catch (e, stackTrace) {
      print('❌ Error loading folders: $e');
      print('Stack trace: $stackTrace');
      emit(FolderError('Failed to load folders: ${e.toString()}'));
    }
  }

  /// Refresh folders without showing loading state
  Future<void> _onRefreshFolders(
      RefreshFolders event,
      Emitter<FolderState> emit,
      ) async {
    try {
      // Get all folders from repository
      final allFolders = await _folderRepository.getAllFolders();

      // Separate default and custom folders
      final defaultFolders = allFolders.where((f) => f.isDefault).toList();
      final customFolders = allFolders.where((f) => f.isCustom).toList();

      emit(FolderLoaded(
        defaultFolders: defaultFolders,
        customFolders: customFolders,
      ));

      print('🔄 Refreshed folders');

    } catch (e) {
      print('❌ Error refreshing folders: $e');
      emit(FolderError('Failed to refresh folders: ${e.toString()}'));
    }
  }

  /// Create a new custom folder
  Future<void> _onCreateFolder(
      CreateFolder event,
      Emitter<FolderState> emit,
      ) async {
    if (state is! FolderLoaded) {
      emit(const FolderError('Cannot create folder: folders not loaded'));
      return;
    }

    final currentState = state as FolderLoaded;

    // Show creating state
    emit(FolderCreating(
      defaultFolders: currentState.defaultFolders,
      customFolders: currentState.customFolders,
    ));

    try {
      // Create new folder entity
      final newFolder = FolderEntity.customFolder(
        name: event.name,
        icon: event.icon,
        color: event.color,
      );

      // Save to repository (database)
      final createdFolder = await _folderRepository.createFolder(newFolder);

      // Update state with new folder
      final updatedCustomFolders = List<FolderEntity>.from(currentState.customFolders)
        ..add(createdFolder);

      emit(FolderLoaded(
        defaultFolders: currentState.defaultFolders,
        customFolders: updatedCustomFolders,
      ));

      // Emit success event
      emit(FolderCreated(
        defaultFolders: currentState.defaultFolders,
        customFolders: updatedCustomFolders,
        createdFolder: createdFolder,
      ));

      print('✅ Created and saved folder: ${createdFolder.name}');

    } catch (e) {
      print('❌ Error creating folder: $e');
      emit(FolderError('Failed to create folder: ${e.toString()}'));

      // Restore previous state
      emit(FolderLoaded(
        defaultFolders: currentState.defaultFolders,
        customFolders: currentState.customFolders,
      ));
    }
  }

  /// Delete a custom folder
  Future<void> _onDeleteFolder(
      DeleteFolder event,
      Emitter<FolderState> emit,
      ) async {
    print('🗑️ [DEBUG] Delete folder requested: ${event.folderId}');

    if (state is! FolderLoaded) {
      print('❌ [DEBUG] Cannot delete folder: folders not loaded');
      emit(const FolderError('Cannot delete folder: folders not loaded'));
      return;
    }

    final currentState = state as FolderLoaded;

    // Find the folder to delete
    final folderToDelete = currentState.customFolders
        .cast<FolderEntity?>()
        .firstWhere((folder) => folder?.id == event.folderId, orElse: () => null);

    if (folderToDelete == null) {
      print('❌ [DEBUG] Folder not found: ${event.folderId}');
      emit(const FolderError('Folder not found'));
      return;
    }

    if (!folderToDelete.canBeDeleted) {
      print('❌ [DEBUG] Folder cannot be deleted: ${folderToDelete.name}');
      emit(const FolderError('This folder cannot be deleted'));
      return;
    }

    print('✅ [DEBUG] Starting delete process for: ${folderToDelete.name}');

    try {
      // Delete from repository (database)
      final success = await _folderRepository.deleteFolder(event.folderId);

      if (!success) {
        emit(const FolderError('Failed to delete folder from database'));
        return;
      }

      // Create updated list WITHOUT the deleted folder
      final updatedCustomFolders = currentState.customFolders
          .where((folder) => folder.id != event.folderId)
          .toList();

      print('✅ [DEBUG] Folder deleted from database. New count: ${updatedCustomFolders.length}');

      // Emit the updated state
      emit(FolderLoaded(
        defaultFolders: currentState.defaultFolders,
        customFolders: updatedCustomFolders,
      ));

      // Then emit the delete success state
      emit(FolderDeleted(
        defaultFolders: currentState.defaultFolders,
        customFolders: updatedCustomFolders,
        deletedFolderId: event.folderId,
        deletedFolderName: folderToDelete.name,
      ));

    } catch (e) {
      print('❌ [DEBUG] Error deleting folder: $e');
      emit(FolderError('Failed to delete folder: ${e.toString()}'));
    }
  }

  /// Update folder recording count
  Future<void> _onUpdateFolderCount(
      UpdateFolderCount event,
      Emitter<FolderState> emit,
      ) async {
    if (state is! FolderLoaded) return;

    final currentState = state as FolderLoaded;

    try {
      // Update in repository (database)
      await _folderRepository.updateFolderCount(event.folderId, event.newCount);

      // Update default folders
      final updatedDefaultFolders = currentState.defaultFolders.map((folder) {
        if (folder.id == event.folderId) {
          return folder.updateCount(event.newCount);
        }
        return folder;
      }).toList();

      // Update custom folders
      final updatedCustomFolders = currentState.customFolders.map((folder) {
        if (folder.id == event.folderId) {
          return folder.updateCount(event.newCount);
        }
        return folder;
      }).toList();

      emit(FolderLoaded(
        defaultFolders: updatedDefaultFolders,
        customFolders: updatedCustomFolders,
      ));

      print('✅ Updated folder count for ${event.folderId}: ${event.newCount}');

    } catch (e) {
      print('❌ Error updating folder count: $e');
      emit(FolderError('Failed to update folder count: ${e.toString()}'));
    }
  }

  /// Rename a custom folder
  Future<void> _onRenameFolder(
      RenameFolderEvent event,
      Emitter<FolderState> emit,
      ) async {
    if (state is! FolderLoaded) {
      emit(const FolderError('Cannot rename folder: folders not loaded'));
      return;
    }

    final currentState = state as FolderLoaded;

    // Find the folder to rename
    final folderToRename = currentState.customFolders
        .cast<FolderEntity?>()
        .firstWhere((folder) => folder?.id == event.folderId, orElse: () => null);

    if (folderToRename == null) {
      emit(const FolderError('Folder not found'));
      return;
    }

    if (!folderToRename.canBeRenamed) {
      emit(const FolderError('This folder cannot be renamed'));
      return;
    }

    try {
      // Validate new name
      final nameValidationError = folderToRename.getNameValidationError(event.newName);
      if (nameValidationError != null) {
        emit(FolderError(nameValidationError));
        return;
      }

      // Check for duplicate names (excluding current folder)
      final existingNames = [
        ...currentState.defaultFolders.map((f) => f.name.toLowerCase()),
        ...currentState.customFolders
            .where((f) => f.id != event.folderId)
            .map((f) => f.name.toLowerCase()),
      ];

      if (existingNames.contains(event.newName.toLowerCase())) {
        emit(const FolderError('A folder with this name already exists'));
        return;
      }

      // Rename folder
      final renamedFolder = folderToRename.rename(event.newName);

      // Update in repository (database)
      await _folderRepository.updateFolder(renamedFolder);

      // Update custom folders list
      final updatedCustomFolders = currentState.customFolders.map((folder) {
        if (folder.id == event.folderId) {
          return renamedFolder;
        }
        return folder;
      }).toList();

      emit(FolderLoaded(
        defaultFolders: currentState.defaultFolders,
        customFolders: updatedCustomFolders,
      ));

      print('✅ Renamed folder ${folderToRename.name} to ${event.newName}');

    } catch (e) {
      print('❌ Error renaming folder: $e');
      emit(FolderError('Failed to rename folder: ${e.toString()}'));
    }
  }

  /// Toggle edit mode for multi-selection
  void _onToggleFolderEditMode(
      ToggleFolderEditMode event,
      Emitter<FolderState> emit,
      ) {
    if (state is FolderLoaded) {
      final currentState = state as FolderLoaded;
      emit(currentState.copyWith(
        isEditMode: !currentState.isEditMode,
        selectedFolderIds: currentState.isEditMode ? <String>{} : currentState.selectedFolderIds,
      ));
      print('📝 Toggled edit mode: ${!currentState.isEditMode}');
    }
  }

  /// Toggle selection of a custom folder
  void _onToggleFolderSelection(
      ToggleFolderSelection event,
      Emitter<FolderState> emit,
      ) {
    if (state is FolderLoaded) {
      final currentState = state as FolderLoaded;
      final selectedFolderIds = Set<String>.from(currentState.selectedFolderIds);
      
      if (selectedFolderIds.contains(event.folderId)) {
        selectedFolderIds.remove(event.folderId);
        print('➖ Deselected folder: ${event.folderId}');
      } else {
        selectedFolderIds.add(event.folderId);
        print('➕ Selected folder: ${event.folderId}');
      }
      
      emit(currentState.copyWith(selectedFolderIds: selectedFolderIds));
      print('📋 Selected folders count: ${selectedFolderIds.length}');
    }
  }

  /// Clear all folder selections
  void _onClearFolderSelection(
      ClearFolderSelection event,
      Emitter<FolderState> emit,
      ) {
    if (state is FolderLoaded) {
      final currentState = state as FolderLoaded;
      emit(currentState.copyWith(selectedFolderIds: <String>{}));
      print('🗑️ Cleared all folder selections');
    }
  }

  /// Delete multiple selected folders
  Future<void> _onDeleteSelectedFolders(
      DeleteSelectedFolders event,
      Emitter<FolderState> emit,
      ) async {
    if (state is! FolderLoaded) {
      emit(const FolderError('Cannot delete folders: folders not loaded'));
      return;
    }

    final currentState = state as FolderLoaded;
    
    if (event.folderIds.isEmpty) {
      emit(const FolderError('No folders selected for deletion'));
      return;
    }

    print('🗑️ [DEBUG] Bulk delete requested for ${event.folderIds.length} folders');

    try {
      // Verify all folders can be deleted
      final foldersToDelete = currentState.customFolders
          .where((folder) => event.folderIds.contains(folder.id))
          .toList();

      final nonDeletableFolders = foldersToDelete
          .where((folder) => !folder.canBeDeleted)
          .toList();

      if (nonDeletableFolders.isNotEmpty) {
        emit(const FolderError('Some selected folders cannot be deleted'));
        return;
      }

      print('✅ [DEBUG] All selected folders can be deleted');

      // Delete folders from repository one by one
      int deletedCount = 0;
      for (final folderId in event.folderIds) {
        try {
          final success = await _folderRepository.deleteFolder(folderId);
          if (success) {
            deletedCount++;
            print('✅ [DEBUG] Deleted folder: $folderId');
          } else {
            print('❌ [DEBUG] Failed to delete folder: $folderId');
          }
        } catch (e) {
          print('❌ [DEBUG] Error deleting folder $folderId: $e');
        }
      }

      // Create updated custom folders list
      final updatedCustomFolders = currentState.customFolders
          .where((folder) => !event.folderIds.contains(folder.id))
          .toList();

      print('✅ [DEBUG] Bulk delete complete. Deleted: $deletedCount/${event.folderIds.length}');

      // Emit the updated state with edit mode turned off and selections cleared
      emit(FoldersDeleted(
        defaultFolders: currentState.defaultFolders,
        customFolders: updatedCustomFolders,
        deletedFolderIds: event.folderIds,
        deletedCount: deletedCount,
        isEditMode: false,
        selectedFolderIds: <String>{},
      ));

    } catch (e) {
      print('❌ [DEBUG] Error during bulk folder deletion: $e');
      emit(FolderError('Failed to delete selected folders: ${e.toString()}'));
    }
  }
}