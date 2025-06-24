// File: presentation/widgets/recording/recording_card/recording_card_info.dart
import 'package:flutter/material.dart';
import '../../../../domain/entities/recording_entity.dart';
import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/enums/audio_format.dart';

/// Widget for displaying recording information (title, tags, date)
class RecordingCardInfo extends StatelessWidget {
  final RecordingEntity recording;
  final String currentFolderId;
  final Map<String, String>? folderNames;
  final bool showFavoriteIcon;
  final VoidCallback? onToggleFavorite;

  const RecordingCardInfo({
    Key? key,
    required this.recording,
    required this.currentFolderId,
    this.folderNames,
    this.showFavoriteIcon = true,
    this.onToggleFavorite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showFavoriteIcon) ...[
          _buildFavoriteIcon(),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recording.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTagsRow(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                recording.createdAt.userFriendlyFormat,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteIcon() {
    if (!recording.isFavorite) {
      return const SizedBox(width: 24, height: 24);
    }
    
    return GestureDetector(
      onTap: () {
        if (currentFolderId != 'recently_deleted') {
          onToggleFavorite?.call();
        }
      },
      child: const SizedBox(
        width: 24,
        height: 24,
        child: Icon(
          Icons.favorite,
          color: Colors.red,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTagsRow() {
    final folderTag = _buildSourceFolderTag();
    
    return Row(
      children: [
        if (folderTag != null) ...[
          folderTag,
          const SizedBox(width: 4),
        ],
        _buildExtensionTag(),
      ],
    );
  }

  Widget? _buildSourceFolderTag() {
    if (currentFolderId != 'all_recordings' || recording.folderId == 'all_recordings') {
      return null;
    }

    final folderName = folderNames?[recording.folderId] ?? recording.folderId;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purple,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        folderName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildExtensionTag() {
    final extension = recording.format.fileExtension;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        extension.toUpperCase().replaceFirst('.', ''),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}