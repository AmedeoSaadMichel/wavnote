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

  const FolderLoaded({
    required this.defaultFolders,
    required this.customFolders,
  });

  @override
  List<Object> get props => [defaultFolders, customFolders];

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

  @override
  String toString() => 'FolderLoaded { defaultFolders: ${defaultFolders.length}, customFolders: ${customFolders.length} }';
}

/// State when a folder is being created
class FolderCreating extends FolderLoaded {
  const FolderCreating({
    required super.defaultFolders,
    required super.customFolders,
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
  });

  @override
  List<Object> get props => [defaultFolders, customFolders, createdFolder];

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
  });

  @override
  List<Object> get props => [defaultFolders, customFolders, deletedFolderId, deletedFolderName];

  @override
  String toString() => 'FolderDeleted { deletedFolderId: $deletedFolderId, deletedFolderName: $deletedFolderName }';
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
  });

  @override
  List<Object> get props => [defaultFolders, customFolders, searchQuery, filteredCustomFolders];

  /// Whether search is active
  bool get isSearchActive => searchQuery.isNotEmpty;

  /// Number of filtered results
  int get filteredCount => filteredCustomFolders.length;

  @override
  String toString() => 'FolderFiltered { searchQuery: $searchQuery, filteredCount: $filteredCount }';
}