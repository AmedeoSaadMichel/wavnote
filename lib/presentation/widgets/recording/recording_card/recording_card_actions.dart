// File: presentation/widgets/recording/recording_card/recording_card_actions.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Widget for handling swipe actions on recording cards
class RecordingCardActions extends StatelessWidget {
  final bool isSwipeActionsVisible;
  final bool isFavoriteActionVisible;
  final bool isFavorite;
  final String currentFolderId;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final VoidCallback onMoreActions;
  final VoidCallback onMoveToFolder;
  final VoidCallback onToggleFavorite;

  const RecordingCardActions({
    Key? key,
    required this.isSwipeActionsVisible,
    required this.isFavoriteActionVisible,
    required this.isFavorite,
    required this.currentFolderId,
    required this.onRestore,
    required this.onDelete,
    required this.onMoreActions,
    required this.onMoveToFolder,
    required this.onToggleFavorite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildFavoriteActionBackground(),
        _buildSwipeActionsBackground(),
      ],
    );
  }

  Widget _buildFavoriteActionBackground() {
    if (currentFolderId == 'recently_deleted') {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      left: 16,
      top: 4,
      bottom: 4,
      width: 80,
      child: Container(
        decoration: BoxDecoration(
          color: isFavorite ? Colors.red : Colors.orange,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggleFavorite,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  isFavorite ? 'Remove' : 'Favorite',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeActionsBackground() {
    final isRecentlyDeleted = currentFolderId == 'recently_deleted';
    
    return Positioned(
      right: 16,
      top: 4,
      bottom: 4,
      width: isRecentlyDeleted ? 160 : 240,
      child: Row(
        children: isRecentlyDeleted 
            ? _buildRecentlyDeletedActions()
            : _buildNormalActions(),
      ),
    );
  }

  List<Widget> _buildRecentlyDeletedActions() {
    return [
      _buildActionButton(
        color: Colors.green,
        icon: Icons.restore,
        label: 'Restore',
        onTap: onRestore,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
      _buildActionButton(
        color: Colors.red,
        icon: FontAwesomeIcons.skull,
        label: 'Delete',
        onTap: onDelete,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
    ];
  }

  List<Widget> _buildNormalActions() {
    return [
      _buildActionButton(
        color: Colors.grey[600]!,
        icon: Icons.more_horiz,
        label: 'More Actions',
        onTap: onMoreActions,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
      _buildActionButton(
        color: Colors.blue,
        icon: Icons.folder_open,
        label: 'Move to Folder',
        onTap: onMoveToFolder,
      ),
      _buildActionButton(
        color: Colors.red,
        icon: FontAwesomeIcons.skull,
        label: 'Delete',
        onTap: onDelete,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
    ];
  }

  Widget _buildActionButton({
    required Color color,
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
    BorderRadius? borderRadius,
  }) {
    return Expanded(
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon is IconData 
                  ? Icon(icon, color: Colors.white, size: 24)
                  : FaIcon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}