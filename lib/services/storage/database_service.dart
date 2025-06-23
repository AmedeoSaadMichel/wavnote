import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


import '../../data/models/folder_model.dart';

class DatabaseService {
  static List<VoiceMemoFolder> getDefaultFolders() {
    return [
      VoiceMemoFolder(
        id: 'all_recordings',
        title: 'All Recordings',
        icon: Icons.graphic_eq,
        color: Colors.cyan,
        type: FolderType.defaultFolder,
        isDeletable: false,
      ),
      VoiceMemoFolder(
        id: 'favourites',
        title: 'Favourites',
        icon: Icons.favorite,
        color: Colors.red,
        type: FolderType.defaultFolder,
        isDeletable: false,
      ),
      VoiceMemoFolder(
        id: 'recently_deleted',
        title: 'Recently Deleted',
        icon: FontAwesomeIcons.skull,
        color: Colors.yellow,
        type: FolderType.defaultFolder,
        isDeletable: false,
      ),
    ];
  }




}