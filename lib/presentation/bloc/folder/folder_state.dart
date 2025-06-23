part of 'folder_bloc.dart';



/// Base class for all folder states
abstract class FolderState extends Equatable {
  const FolderState();

  @override
  List<Object?> get props => [];
}

/// Initial state when bloc is first created
class FolderInitial extends FolderState {
  const FolderInitial();

  @override
  String toString() => 'FolderInitial';
}

/// State when folders are being loaded
class FolderLoading extends FolderState {
  const FolderLoading();

  @override
  String toString() => 'FolderLoading';
}

/// State when folders are successfully loaded
class FolderLoaded extends FolderState {
  final List<FolderEntity> defaultFolders;
  final List<FolderEntity> customFolders;
  final bool isEditMode;
  final Set<String> selectedFolderIds;

  const FolderLoaded({
    required this.defaultFolders,
    required this.customFolders,
    this.isEditMode = false,
    this.selectedFolderIds = const <String>{},
  });

  @override
  List<Object> get props => [defaultFolders, customFolders, isEditMode, selectedFolderIds];

  /// Get all folders combined
  List<FolderEntity> get allFolders => [...defaultFolders, ...customFolders];

  /// Total number of folders
  int get totalFolders => defaultFolders.length + customFolders.length;

  /// Whether there are any custom folders
  bool get hasCustomFolders => customFolders.isNotEmpty;

  /// Total number of recordings across all folders
  int get totalRecordings {
    return allFolders.fold<int>(0, (sum, folder) => sum + folder.recordingCount);
  }

  /// Get folder by ID
  FolderEntity? getFolderById(String id) {
    try {
      return allFolders.firstWhere((folder) => folder.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get custom folders sorted by name
  List<FolderEntity> get customFoldersSortedByName {
    final sorted = List<FolderEntity>.from(customFolders);
    sorted.sort(FolderEntity.compareByName);
    return sorted;
  }

  /// Get custom folders sorted by creation date
  List<FolderEntity> get customFoldersSortedByDate {
    final sorted = List<FolderEntity>.from(customFolders);
    sorted.sort(FolderEntity.compareByCreatedDate);
    return sorted;
  }

  /// Get custom folders sorted by recording count
  List<FolderEntity> get customFoldersSortedByCount {
    final sorted = List<FolderEntity>.from(customFolders);
    sorted.sort(FolderEntity.compareByRecordingCount);
    return sorted;
  }

  /// Whether any folders are selected
  bool get hasSelectedFolders => selectedFolderIds.isNotEmpty;

  /// Number of selected folders
  int get selectedFoldersCount => selectedFolderIds.length;

  /// Get selected folders
  List<FolderEntity> get selectedFolders {
    return customFolders.where((folder) => selectedFolderIds.contains(folder.id)).toList();
  }

  /// Check if a folder is selected
  bool isFolderSelected(String folderId) => selectedFolderIds.contains(folderId);

  /// Copy with new values
  FolderLoaded copyWith({
    List<FolderEntity>? defaultFolders,
    List<FolderEntity>? customFolders,
    bool? isEditMode,
    Set<String>? selectedFolderIds,
  }) {
    return FolderLoaded(
      defaultFolders: defaultFolders ?? this.defaultFolders,
      customFolders: customFolders ?? this.customFolders,
      isEditMode: isEditMode ?? this.isEditMode,
      selectedFolderIds: selectedFolderIds ?? this.selectedFolderIds,
    );
  }

  @override
  String toString() => 'FolderLoaded { defaultFolders: ${defaultFolders.length}, customFolders: ${customFolders.length}, isEditMode: $isEditMode, selectedCount: ${selectedFolderIds.length} }';
}

/// State when a folder is being created
class FolderCreating extends FolderLoaded {
  const FolderCreating({
    required super.defaultFolders,
    required super.customFolders,
    super.isEditMode = false,
    super.selectedFolderIds = const <String>{},
  });

  @override
  String toString() => 'FolderCreating { defaultFolders: ${defaultFolders.length}, customFolders: ${customFolders.length} }';
}

/// State when a folder has been successfully created
class FolderCreated extends FolderLoaded {
  final FolderEntity createdFolder;

  const FolderCreated({
    required super.defaultFolders,
    required super.customFolders,
    required this.createdFolder,
    super.isEditMode = false,
    super.selectedFolderIds = const <String>{},
  });

  @override
  List<Object> get props => [defaultFolders, customFolders, isEditMode, selectedFolderIds, createdFolder];

  @override
  String toString() => 'FolderCreated { createdFolder: ${createdFolder.name} }';
}

/// State when a folder has been successfully deleted
class FolderDeleted extends FolderLoaded {
  final String deletedFolderId;
  final String deletedFolderName;

  const FolderDeleted({
    required super.defaultFolders,
    required super.customFolders,
    required this.deletedFolderId,
    required this.deletedFolderName,
    super.isEditMode = false,
    super.selectedFolderIds = const <String>{},
  });

  @override
  List<Object> get props => [defaultFolders, customFolders, isEditMode, selectedFolderIds, deletedFolderId, deletedFolderName];

  @override
  String toString() => 'FolderDeleted { deletedFolderId: $deletedFolderId, deletedFolderName: $deletedFolderName }';
}

/// State when multiple folders have been successfully deleted
class FoldersDeleted extends FolderLoaded {
  final List<String> deletedFolderIds;
  final int deletedCount;

  const FoldersDeleted({
    required super.defaultFolders,
    required super.customFolders,
    required this.deletedFolderIds,
    required this.deletedCount,
    super.isEditMode = false,
    super.selectedFolderIds = const <String>{},
  });

  @override
  List<Object> get props => [defaultFolders, customFolders, isEditMode, selectedFolderIds, deletedFolderIds, deletedCount];

  @override
  String toString() => 'FoldersDeleted { deletedCount: $deletedCount }';
}

/// State when an error occurs
class FolderError extends FolderState {
  final String message;
  final String? errorCode;
  final dynamic error;

  const FolderError(
      this.message, {
        this.errorCode,
        this.error,
      });

  @override
  List<Object?> get props => [message, errorCode, error];

  /// Whether this is a validation error
  bool get isValidationError => errorCode == 'VALIDATION_ERROR';

  /// Whether this is a network error
  bool get isNetworkError => errorCode == 'NETWORK_ERROR';

  /// Whether this is a storage error
  bool get isStorageError => errorCode == 'STORAGE_ERROR';

  /// Whether this is a permission error
  bool get isPermissionError => errorCode == 'PERMISSION_ERROR';

  @override
  String toString() => 'FolderError { message: $message, errorCode: $errorCode }';
}

/// State when folders are being searched/filtered
class FolderFiltered extends FolderLoaded {
  final String searchQuery;
  final List<FolderEntity> filteredCustomFolders;

  const FolderFiltered({
    required super.defaultFolders,
    required super.customFolders,
    required this.searchQuery,
    required this.filteredCustomFolders,
    super.isEditMode = false,
    super.selectedFolderIds = const <String>{},
  });

  @override
  List<Object> get props => [defaultFolders, customFolders, isEditMode, selectedFolderIds, searchQuery, filteredCustomFolders];

  /// Whether search is active
  bool get isSearchActive => searchQuery.isNotEmpty;

  /// Number of filtered results
  int get filteredCount => filteredCustomFolders.length;

  @override
  String toString() => 'FolderFiltered { searchQuery: $searchQuery, filteredCount: $filteredCount }';
}