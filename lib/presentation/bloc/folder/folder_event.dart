part of 'folder_bloc.dart';

/// Base class for all folder-related events
abstract class FolderEvent extends Equatable {
  const FolderEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all folders (default + custom)
class LoadFolders extends FolderEvent {
  const LoadFolders();

  @override
  String toString() => 'LoadFolders';
}

/// Event to refresh folders without showing loading state
class RefreshFolders extends FolderEvent {
  const RefreshFolders();

  @override
  String toString() => 'RefreshFolders';
}

/// Event to create a new custom folder
class CreateFolder extends FolderEvent {
  final String name;
  final Color color;
  final IconData icon;

  const CreateFolder({
    required this.name,
    required this.color,
    required this.icon,
  });

  @override
  List<Object> get props => [name, color, icon];

  @override
  String toString() => 'CreateFolder { name: $name, color: $color, icon: $icon }';
}

/// Event to delete a custom folder
class DeleteFolder extends FolderEvent {
  final String folderId;

  const DeleteFolder({required this.folderId});

  @override
  List<Object> get props => [folderId];

  @override
  String toString() => 'DeleteFolder { folderId: $folderId }';
}

/// Event to update folder recording count
class UpdateFolderCount extends FolderEvent {
  final String folderId;
  final int newCount;

  const UpdateFolderCount({
    required this.folderId,
    required this.newCount,
  });

  @override
  List<Object> get props => [folderId, newCount];

  @override
  String toString() => 'UpdateFolderCount { folderId: $folderId, newCount: $newCount }';
}

/// Event to rename a custom folder
class RenameFolderEvent extends FolderEvent {
  final String folderId;
  final String newName;

  const RenameFolderEvent({
    required this.folderId,
    required this.newName,
  });

  @override
  List<Object> get props => [folderId, newName];

  @override
  String toString() => 'RenameFolderEvent { folderId: $folderId, newName: $newName }';
}

/// Event to sort folders by different criteria
class SortFolders extends FolderEvent {
  final FolderSortType sortType;

  const SortFolders({required this.sortType});

  @override
  List<Object> get props => [sortType];

  @override
  String toString() => 'SortFolders { sortType: $sortType }';
}

/// Event to search/filter folders
class FilterFolders extends FolderEvent {
  final String searchQuery;

  const FilterFolders({required this.searchQuery});

  @override
  List<Object> get props => [searchQuery];

  @override
  String toString() => 'FilterFolders { searchQuery: $searchQuery }';
}

/// Event to toggle edit mode for multi-selection
class ToggleFolderEditMode extends FolderEvent {
  const ToggleFolderEditMode();

  @override
  String toString() => 'ToggleFolderEditMode';
}

/// Event to toggle selection of a custom folder
class ToggleFolderSelection extends FolderEvent {
  final String folderId;

  const ToggleFolderSelection({required this.folderId});

  @override
  List<Object> get props => [folderId];

  @override
  String toString() => 'ToggleFolderSelection { folderId: $folderId }';
}

/// Event to clear all folder selections
class ClearFolderSelection extends FolderEvent {
  const ClearFolderSelection();

  @override
  String toString() => 'ClearFolderSelection';
}

/// Event to delete multiple selected folders
class DeleteSelectedFolders extends FolderEvent {
  final List<String> folderIds;

  const DeleteSelectedFolders({required this.folderIds});

  @override
  List<Object> get props => [folderIds];

  @override
  String toString() => 'DeleteSelectedFolders { folderIds: $folderIds }';
}

/// Enum for folder sorting options
enum FolderSortType {
  name,
  createdDate,
  recordingCount,
  lastModified,
}

extension FolderSortTypeExtension on FolderSortType {
  String get displayName {
    switch (this) {
      case FolderSortType.name:
        return 'Name';
      case FolderSortType.createdDate:
        return 'Date Created';
      case FolderSortType.recordingCount:
        return 'Recording Count';
      case FolderSortType.lastModified:
        return 'Last Modified';
    }
  }
}