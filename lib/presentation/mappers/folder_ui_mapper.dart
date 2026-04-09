// File: presentation/mappers/folder_ui_mapper.dart
//
// Folder UI Mapper - Presentation Layer
// ======================================
//
// Maps FolderEntity primitive values (iconCodePoint, colorValue) to Flutter UI types.
// Keeps the Domain layer pure while providing UI-friendly conversions.

import 'package:flutter/material.dart';
import '../../domain/entities/folder_entity.dart';

/// Mapper for converting FolderEntity primitives to Flutter UI types
class FolderUiMapper {
  /// Convert icon code point to Flutter IconData
  static IconData toIconData(FolderEntity folder) {
    return IconData(folder.iconCodePoint, fontFamily: 'MaterialIcons');
  }

  /// Convert color value to Flutter Color
  static Color toColor(FolderEntity folder) {
    return Color(folder.colorValue);
  }

  /// Get icon for folder type (fallback for default folders)
  static IconData getIconForFolderType(FolderType type) {
    switch (type) {
      case FolderType.allRecordings:
        return Icons.folder;
      case FolderType.favorites:
        return Icons.favorite;
      case FolderType.recentlyDeleted:
        return Icons.delete;
      case FolderType.customFolder:
        return Icons.folder_outlined;
    }
  }

  /// Get color for folder type (fallback for default folders)
  static Color getColorForFolderType(FolderType type) {
    switch (type) {
      case FolderType.allRecordings:
        return Colors.blue;
      case FolderType.favorites:
        return Colors.red;
      case FolderType.recentlyDeleted:
        return Colors.grey;
      case FolderType.customFolder:
        return Colors.orange;
    }
  }
}

// Need to define FolderType enum or import it
enum FolderType { allRecordings, favorites, recentlyDeleted, customFolder }
