enum FolderType {
  defaultFolder,
  customFolder,
}

extension FolderTypeExtension on FolderType {
  String get name {
    switch (this) {
      case FolderType.defaultFolder:
        return 'Default';
      case FolderType.customFolder:
        return 'Custom';
    }
  }

  bool get isDefault => this == FolderType.defaultFolder;
  bool get isCustom => this == FolderType.customFolder;
  bool get isDeletable => this == FolderType.customFolder;
}