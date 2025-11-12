// File: presentation/widgets/recording/recording_list_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/audio_format.dart';
import '../../bloc/recording/recording_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';

/// Header widget for recording list screen
class RecordingListHeader extends StatelessWidget {
  final String folderName;
  final VoidCallback onBack;
  final VoidCallback? onShowFormatDialog;
  final VoidCallback? onMoveSelected;

  const RecordingListHeader({
    Key? key,
    required this.folderName,
    required this.onBack,
    this.onShowFormatDialog,
    this.onMoveSelected,
  }) : super(key: key);

  /// Show confirmation dialog for deleting selected recordings
  void _showDeleteConfirmation(BuildContext context, RecordingLoaded recordingState) {
    final selectedCount = recordingState.selectedRecordings.length;
    final isRecentlyDeleted = folderName == 'Recently Deleted';
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isRecentlyDeleted ? 'Permanently Delete Recordings' : 'Delete Recordings',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            isRecentlyDeleted 
                ? 'Are you sure you want to permanently delete $selectedCount recording${selectedCount == 1 ? '' : 's'}? This action cannot be undone.'
                : 'Are you sure you want to delete $selectedCount recording${selectedCount == 1 ? '' : 's'}? ${selectedCount == 1 ? 'It' : 'They'} will be moved to Recently Deleted.',
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
                context.read<RecordingBloc>().add(DeleteSelectedRecordings(
                  folderId: isRecentlyDeleted ? 'recently_deleted' : 'all_recordings',
                ));
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
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, recordingState) {
        final isEditMode = recordingState is RecordingLoaded ? recordingState.isEditMode : false;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Main header row
              Row(
                children: [
                  // Back button
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: AppConstants.accentCyan,
                      size: 24,
                    ),
                  ),
                  // Folder title with format button (left-aligned like main screen)
                  Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            folderName,
                            style: const TextStyle(
                              color: AppConstants.accentYellow,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Format button right next to title (like main screen)
                        // Don't show format button in Recently Deleted folder
                        if (!isEditMode && onShowFormatDialog != null && folderName != 'Recently Deleted') ...[
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 0,
                            child: BlocBuilder<SettingsBloc, SettingsState>(
                              builder: (context, settingsState) {
                                AudioFormat currentFormat = AudioFormat.m4a;
                                if (settingsState is SettingsLoaded) {
                                  currentFormat = settingsState.settings.audioFormat;
                                }

                                return GestureDetector(
                                  onTap: onShowFormatDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5A2B8C).withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          currentFormat.icon,
                                          color: currentFormat.color,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          currentFormat.name,
                                          style: TextStyle(
                                            color: currentFormat.color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Action buttons (right-aligned)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isEditMode && recordingState is RecordingLoaded && recordingState.selectedRecordings.isNotEmpty) ...[
                        // Move to folder button
                        if (folderName != 'Recently Deleted' && onMoveSelected != null) ...[
                          GestureDetector(
                            onTap: onMoveSelected,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.folder_open, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Move',
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
                        // Delete selected recordings button with skull icon
                        GestureDetector(
                          onTap: () {
                            _showDeleteConfirmation(context, recordingState);
                          },
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
                        onTap: () {
                          context.read<RecordingBloc>().add(const ToggleEditMode());
                        },
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
                              color: AppConstants.accentCyan,
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

              // Selection status indicator and Select All button in edit mode
              if (isEditMode && recordingState is RecordingLoaded) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Selection count indicator
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
                        '${recordingState.selectedRecordings.length} recording${recordingState.selectedRecordings.length == 1 ? '' : 's'} selected',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Select All / Deselect All button (same style as counter)
                    GestureDetector(
                      onTap: () {
                        final areAllSelected = recordingState.recordings.length == recordingState.selectedRecordings.length;
                        if (areAllSelected) {
                          context.read<RecordingBloc>().add(const DeselectAllRecordings());
                        } else {
                          context.read<RecordingBloc>().add(const SelectAllRecordings());
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              recordingState.recordings.length == recordingState.selectedRecordings.length
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: Colors.blue,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              recordingState.recordings.length == recordingState.selectedRecordings.length
                                  ? 'Deselect All'
                                  : 'Select All',
                              style: const TextStyle(
                                color: Colors.blue,
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
              ],
            ],
          ),
        );
      },
    );
  }
}