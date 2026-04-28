// File: lib/presentation/screens/main/main_screen_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/enums/audio_format.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../bloc/folder/folder_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';

/// Header della main screen: titolo, selettore formato, pulsanti Edit/Done/Delete.
class MainScreenHeader extends StatelessWidget {
  final FolderEntity? selectedFolder;
  final VoidCallback onFolderDeselected;
  final VoidCallback onToggleEditMode;
  final VoidCallback onDeleteSelected;
  final VoidCallback onShowFormatDialog;

  const MainScreenHeader({
    super.key,
    required this.selectedFolder,
    required this.onFolderDeselected,
    required this.onToggleEditMode,
    required this.onDeleteSelected,
    required this.onShowFormatDialog,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FolderBloc, FolderState>(
      builder: (context, folderState) {
        final isEditMode =
            folderState is FolderLoaded ? folderState.isEditMode : false;
        final hasSelectedFolders =
            folderState is FolderLoaded ? folderState.hasSelectedFolders : false;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
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
                      if (!isEditMode)
                        BlocBuilder<SettingsBloc, SettingsState>(
                          builder: (context, settingsState) {
                            AudioFormat currentFormat = AudioFormat.m4a;
                            if (settingsState is SettingsLoaded) {
                              currentFormat = settingsState.settings.audioFormat;
                            }
                            return GestureDetector(
                              onTap: onShowFormatDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5A2B8C)
                                      .withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.1),
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
                  Row(
                    children: [
                      if (isEditMode && hasSelectedFolders) ...[
                        GestureDetector(
                          onTap: onDeleteSelected,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
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
                                FaIcon(
                                  FontAwesomeIcons.skull,
                                  color: Colors.white,
                                  size: 14,
                                ),
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
                      GestureDetector(
                        onTap: onToggleEditMode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A2B8C)
                                .withValues(alpha: 0.7),
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

              if (isEditMode) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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

              if (selectedFolder != null && !isEditMode) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Color(selectedFolder!.colorValue)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(selectedFolder!.colorValue)
                          .withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        IconData(
                          selectedFolder!.iconCodePoint,
                          fontFamily: 'MaterialIcons',
                        ),
                        color: Color(selectedFolder!.colorValue),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Selected: ${selectedFolder!.name}',
                        style: TextStyle(
                          color: Color(selectedFolder!.colorValue),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onFolderDeselected,
                        child: Icon(
                          Icons.close,
                          color: Color(selectedFolder!.colorValue),
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
}
