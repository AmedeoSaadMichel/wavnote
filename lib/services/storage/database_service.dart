// File: services/storage/database_service.dart
import 'package:flutter/material.dart';
import '../../data/models/folder_model.dart';

class DatabaseService {
  static List<VoiceMemoFolder> getDefaultFolders() {
    return [
      VoiceMemoFolder(
        id: 'all_recordings',
        title: 'All Recordings',
        iconCodePoint: Icons.graphic_eq.codePoint,
        colorValue: Colors.cyan.value,
        type: FolderType.defaultFolder,
        isDeletable: false,
      ),
      VoiceMemoFolder(
        id: 'favourites',
        title: 'Favourites',
        iconCodePoint: Icons.favorite.codePoint,
        colorValue: Colors.red.value,
        type: FolderType.defaultFolder,
        isDeletable: false,
      ),
      VoiceMemoFolder(
        id: 'recently_deleted',
        title: 'Recently Deleted',
        iconCodePoint: Icons.delete.codePoint,
        colorValue: Colors.yellow.value,
        type: FolderType.defaultFolder,
        isDeletable: false,
      ),
    ];
  }
}
