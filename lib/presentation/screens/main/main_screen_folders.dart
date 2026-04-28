// File: lib/presentation/screens/main/main_screen_folders.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/folder_entity.dart';
import '../../bloc/folder/folder_bloc.dart';
import '../../widgets/folder/folder_item.dart';

/// Contenuto della main screen nello stato FolderLoaded:
/// lista cartelle default, cartelle custom in edit/normal mode, pulsante add.
class MainScreenFoldersContent extends StatelessWidget {
  final FolderLoaded state;
  final void Function(FolderEntity) onFolderTap;
  final void Function(FolderEntity) onFolderLongPress;
  final void Function(FolderEntity) onFolderDelete;
  final VoidCallback onCreateFolder;

  const MainScreenFoldersContent({
    super.key,
    required this.state,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onFolderDelete,
    required this.onCreateFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CustomScrollView(
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final folder = state.defaultFolders[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => onFolderTap(folder),
                          onLongPress: () => onFolderLongPress(folder),
                          child: FolderItem(
                            folder: folder,
                            onTap: () => onFolderTap(folder),
                          ),
                        ),
                      );
                    },
                    childCount: state.defaultFolders.length,
                  ),
                ),

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

                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final folder = state.customFolders[index];
                        final isSelected = state.isFolderSelected(folder.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: state.isEditMode
                              ? _buildEditableItem(context, folder, isSelected)
                              : _buildNormalItem(folder),
                        );
                      },
                      childCount: state.customFolders.length,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
        ),

        if (!state.isEditMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildAddFolderButton(),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildNormalItem(FolderEntity folder) {
    return FolderItem(
      folder: folder,
      onTap: () => onFolderTap(folder),
      onLongPress: () => onFolderLongPress(folder),
      onDelete: folder.canBeDeleted ? () => onFolderDelete(folder) : null,
    );
  }

  Widget _buildEditableItem(
    BuildContext context,
    FolderEntity folder,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () =>
          context.read<FolderBloc>().add(ToggleFolderSelection(folderId: folder.id)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
        ),
        child: Stack(
          children: [
            FolderItem(
              folder: folder,
              onTap: () => context.read<FolderBloc>().add(
                ToggleFolderSelection(folderId: folder.id),
              ),
            ),
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
                    color: isSelected
                        ? Colors.blue
                        : Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          onTap: onCreateFolder,
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
