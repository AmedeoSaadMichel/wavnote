// File: presentation/widgets/folder/folder_item.dart
import 'package:flutter/material.dart';
import '../../../domain/entities/folder_entity.dart';

/// Widget to display a single folder item
///
/// Shows folder icon, name, recording count, and handles tap interactions.
/// Uses the clean FolderEntity from the domain layer.
class FolderItem extends StatelessWidget {
  final FolderEntity folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showChevron;

  const FolderItem({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF5A2B8C).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Folder Icon
            _buildFolderIcon(),
            const SizedBox(width: 16),

            // Folder Details
            Expanded(
              child: _buildFolderDetails(),
            ),

            // Recording Count
            _buildRecordingCount(),

            // Chevron (if enabled)
            if (showChevron) ...[
              const SizedBox(width: 12),
              _buildChevron(),
            ],
          ],
        ),
      ),
    );
  }

  /// Build the folder icon with background circle
  Widget _buildFolderIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: folder.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: folder.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Icon(
        folder.icon,
        color: folder.color,
        size: 24,
      ),
    );
  }

  /// Build folder name and metadata
  Widget _buildFolderDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folder Name
        Text(
          folder.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),

        // Folder Type Badge (for custom folders)
        if (folder.isCustom) ...[
          const SizedBox(height: 4),
          _buildFolderTypeBadge(),
        ],
      ],
    );
  }

  /// Build folder type badge for custom folders
  Widget _buildFolderTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        'CUSTOM',
        style: TextStyle(
          color: Colors.blue[300],
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Build recording count with proper formatting
  Widget _buildRecordingCount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: folder.hasRecordings
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        folder.shortCountText,
        style: TextStyle(
          color: folder.hasRecordings
              ? Colors.green[300]
              : Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Build chevron indicator
  Widget _buildChevron() {
    return Icon(
      Icons.chevron_right,
      color: Colors.white.withValues(alpha: 0.5),
      size: 20,
    );
  }
}

/// Alternative compact version of folder item
class CompactFolderItem extends StatelessWidget {
  final FolderEntity folder;
  final VoidCallback onTap;

  const CompactFolderItem({
    super.key,
    required this.folder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF5A2B8C).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              folder.icon,
              color: folder.color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                folder.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              folder.shortCountText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}