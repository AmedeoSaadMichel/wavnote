// File: presentation/widgets/folder/folder_item.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../domain/entities/folder_entity.dart';

/// Widget to display a single folder item
///
/// Shows folder icon, name, recording count, and handles tap interactions.
/// Uses the clean FolderEntity from the domain layer.
///
/// Features swipe-to-delete with animated skull button (same as RecordingCard)
class FolderItem extends StatefulWidget {
  final FolderEntity folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool showChevron;

  const FolderItem({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
    this.showChevron = true,
  });

  @override
  State<FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<FolderItem> with SingleTickerProviderStateMixin {
  // Swipe animation controller
  late AnimationController _swipeController;
  late Animation<double> _swipeAnimation;
  double _swipeOffset = 0.0;
  bool _isSwipeActionVisible = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
  }

  void _initializeAnimation() {
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _swipeAnimation = Tween<double>(
      begin: 0.0,
      end: -80.0, // Width of delete button
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInOut,
    ));

    _swipeAnimation.addListener(() {
      setState(() {
        _swipeOffset = _swipeAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  /// Toggle swipe action visibility
  void _toggleSwipeAction() {
    if (_isSwipeActionVisible) {
      _swipeController.reverse();
    } else {
      _swipeController.forward();
    }
    _isSwipeActionVisible = !_isSwipeActionVisible;
  }

  /// Hide swipe action
  void _hideSwipeAction() {
    if (_isSwipeActionVisible) {
      _swipeController.reverse();
      _isSwipeActionVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show swipe action for non-deletable folders
    if (!widget.folder.canBeDeleted || widget.onDelete == null) {
      return _buildSimpleFolderItem();
    }

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // Swipe RIGHT to LEFT - show delete button
        if (details.delta.dx < -5) {
          if (!_isSwipeActionVisible) {
            _toggleSwipeAction();
          }
        }
      },
      onTap: () {
        // If swipe action is visible, hide it first
        if (_isSwipeActionVisible) {
          _hideSwipeAction();
        } else {
          widget.onTap();
        }
      },
      onLongPress: widget.onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Delete button background (positioned to fill the entire space)
          Positioned.fill(
            child: _buildDeleteBackground(),
          ),

          // Main folder item with transform (covers background when not swiped)
          Transform.translate(
            offset: Offset(_swipeOffset, 0),
            child: _buildFolderCard(),
          ),
        ],
      ),
    );
  }

  /// Build delete button background
  Widget _buildDeleteBackground() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _hideSwipeAction();
              widget.onDelete?.call();
            },
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.skull,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(height: 4),
                Text(
                  'Delete',
                  style: TextStyle(
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

  /// Build the main folder card
  Widget _buildFolderCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF7B4CA8),  // Lighter purple, fully opaque
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
          if (widget.showChevron) ...[
            const SizedBox(width: 12),
            _buildChevron(),
          ],
        ],
      ),
    );
  }

  /// Build simple folder item without swipe (for non-deletable folders)
  Widget _buildSimpleFolderItem() {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: _buildFolderCard(),
    );
  }

  /// Build the folder icon with background circle
  Widget _buildFolderIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.folder.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.folder.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Icon(
        widget.folder.icon,
        color: widget.folder.color,
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
          widget.folder.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),

        // Folder Type Badge (for custom folders)
        if (widget.folder.isCustom) ...[
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
        color: widget.folder.hasRecordings
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.folder.shortCountText,
        style: TextStyle(
          color: widget.folder.hasRecordings
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