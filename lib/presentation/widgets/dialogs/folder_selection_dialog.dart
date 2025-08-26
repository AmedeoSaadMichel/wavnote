// File: presentation/widgets/dialogs/folder_selection_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../../core/enums/folder_type.dart';
import '../../bloc/folder/folder_bloc.dart';

/// Dialog for selecting a folder to move recordings to
///
/// Displays a list of available folders (excluding Recently Deleted)
/// and allows the user to select a target folder for moving recordings.
class FolderSelectionDialog extends StatelessWidget {
  final String? currentFolderId;
  final Function(String folderId) onFolderSelected;
  final String title;
  final String? subtitle;
  final bool isRecordingAlreadyFavorite;

  const FolderSelectionDialog({
    super.key,
    this.currentFolderId,
    required this.onFolderSelected,
    this.title = 'Move to Folder',
    this.subtitle,
    this.isRecordingAlreadyFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.deepPurpleAccent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: const BoxConstraints(
          maxHeight: 500,
          maxWidth: 400,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: const TextStyle(
                color: Colors.pinkAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Folder list
            Expanded(
              child: BlocBuilder<FolderBloc, FolderState>(
                builder: (context, state) {
                  if (state is FolderLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.pinkAccent,
                      ),
                    );
                  }
                  
                  if (state is FolderError) {
                    return Center(
                      child: Text(
                        'Error loading folders: ${state.message}',
                        style: TextStyle(
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  
                  if (state is FolderLoaded) {
                    // Filter out special system folders that aren't real move destinations
                    final availableFolders = state.allFolders.where((folder) {
                      // Exclude special system folders that don't represent actual storage
                      if (folder.id == 'recently_deleted') return false; // Can't move to trash
                      if (folder.id == 'all_recordings') return false; // Not a real folder, just a view
                      
                      // Exclude current folder (can't move to same folder)
                      if (folder.id == currentFolderId) return false;
                      
                      // Exclude Favourites folder if recording is already favorite
                      if (folder.id == 'favourites' && isRecordingAlreadyFavorite) {
                        print('📁 FolderSelectionDialog: Excluding Favourites folder - recording is already favorite');
                        return false;
                      }
                      
                      return true;
                    }).toList();
                    
                    print('📁 FolderSelectionDialog: Filtering folders - excluding recently_deleted and $currentFolderId');
                    print('📁 FolderSelectionDialog: Available folders: ${availableFolders.map((f) => f.name).join(', ')}');

                    if (availableFolders.isEmpty) {
                      return Center(
                        child: Text(
                          'No folders available',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: availableFolders.length,
                      itemBuilder: (context, index) {
                        final folder = availableFolders[index];
                        return _FolderListTile(
                          folder: folder,
                          onTap: () {
                            onFolderSelected(folder.id);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    );
                  }
                  
                  return const SizedBox.shrink();
                },
              ),
            ),

            const SizedBox(height: 16),

            // Cancel button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.cyanAccent.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual folder list tile widget
class _FolderListTile extends StatelessWidget {
  final FolderEntity folder;
  final VoidCallback onTap;

  const _FolderListTile({
    required this.folder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Folder icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: folder.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                folder.icon,
                color: folder.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // Folder info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.id == 'favourites' ? 'Add to Favorites' : folder.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    folder.id == 'favourites' 
                        ? 'Mark as favorite recording'
                        : '${folder.recordingCount} recording${folder.recordingCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Selection indicator
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}