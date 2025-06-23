// File: domain/entities/recording_entity.dart
import 'package:equatable/equatable.dart';
import '../../core/enums/audio_format.dart';

/// Pure business entity representing an audio recording
///
/// Contains only business logic with no external dependencies.
/// Represents the core data and behavior of a voice recording.
class RecordingEntity extends Equatable {
  final String id;
  final String name;
  final String filePath;
  final String folderId;
  final AudioFormat format;
  final Duration duration;
  final int fileSize; // in bytes
  final int sampleRate;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isFavorite;
  final List<String> tags;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? originalFolderId; // Store original folder before deletion
  final List<double>? waveformData; // Real waveform amplitude data

  const RecordingEntity({
    required this.id,
    required this.name,
    required this.filePath,
    required this.folderId,
    required this.format,
    required this.duration,
    required this.fileSize,
    required this.sampleRate,
    this.latitude,
    this.longitude,
    this.locationName,
    required this.createdAt,
    this.updatedAt,
    this.isFavorite = false,
    this.tags = const [],
    this.isDeleted = false,
    this.deletedAt,
    this.originalFolderId,
    this.waveformData,
  });

  // ==== BUSINESS LOGIC PROPERTIES ====

  /// Whether this recording is empty/invalid
  bool get isEmpty => duration.inSeconds == 0 || fileSize == 0;

  /// Whether this recording has a valid duration
  bool get hasValidDuration => duration.inSeconds > 0;

  /// Whether this recording has location data
  bool get hasLocation => latitude != null && longitude != null;

  /// Whether this recording has been modified since creation
  bool get isModified => updatedAt != null && updatedAt!.isAfter(createdAt);

  /// Whether this recording is in Recently Deleted folder
  bool get isInTrash => isDeleted && folderId == 'recently_deleted';

  /// Days remaining before permanent deletion (15 days max)
  int get daysUntilPermanentDeletion {
    if (!isDeleted || deletedAt == null) return 0;
    final daysSinceDeletion = DateTime.now().difference(deletedAt!).inDays;
    return (15 - daysSinceDeletion).clamp(0, 15);
  }

  /// Whether this recording should be permanently deleted (older than 15 days)
  bool get shouldBePermanentlyDeleted {
    if (!isDeleted || deletedAt == null) return false;
    return DateTime.now().difference(deletedAt!).inDays >= 15;
  }

  /// File size in human-readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Duration in human-readable format
  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Short duration format for lists
  String get shortDurationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// File extension based on format
  String get fileExtension => format.fileExtension;

  /// Quality description based on sample rate
  String get qualityDescription {
    if (sampleRate >= 48000) return 'High Quality';
    if (sampleRate >= 44100) return 'CD Quality';
    if (sampleRate >= 22050) return 'Good Quality';
    return 'Basic Quality';
  }

  /// Recording age description
  String get ageDescription {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years} year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months} month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  // ==== BUSINESS LOGIC METHODS ====

  /// Validate if recording name is acceptable
  bool isValidName(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= 100 &&
        !_containsInvalidCharacters(trimmed);
  }

  /// Check if name contains invalid characters for file system
  bool _containsInvalidCharacters(String name) {
    const invalidChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    return invalidChars.any((char) => name.contains(char));
  }

  /// Get validation error message for a name
  String? getNameValidationError(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return 'Recording name cannot be empty';
    }

    if (trimmed.length > 100) {
      return 'Recording name cannot exceed 100 characters';
    }

    if (_containsInvalidCharacters(trimmed)) {
      return 'Recording name contains invalid characters';
    }

    return null; // No error
  }

  /// Check if recording can be moved to another folder
  bool canBeMovedToFolder(String targetFolderId) {
    return targetFolderId != folderId && targetFolderId.isNotEmpty;
  }

  /// Calculate recording bitrate (approximate)
  int get approximateBitrate {
    if (duration.inSeconds == 0) return 0;
    return ((fileSize * 8) / duration.inSeconds).round();
  }

  // ==== IMMUTABLE UPDATE METHODS ====

  /// Create a copy with updated values
  RecordingEntity copyWith({
    String? id,
    String? name,
    String? filePath,
    String? folderId,
    AudioFormat? format,
    Duration? duration,
    int? fileSize,
    int? sampleRate,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    List<String>? tags,
    bool? isDeleted,
    DateTime? deletedAt,
    String? originalFolderId,
    List<double>? waveformData,
  }) {
    return RecordingEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      folderId: folderId ?? this.folderId,
      format: format ?? this.format,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      sampleRate: sampleRate ?? this.sampleRate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      originalFolderId: originalFolderId ?? this.originalFolderId,
      waveformData: waveformData ?? this.waveformData,
    );
  }

  /// Mark recording as favorite
  RecordingEntity markAsFavorite() {
    return copyWith(
      isFavorite: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove from favorites
  RecordingEntity removeFromFavorites() {
    return copyWith(
      isFavorite: false,
      updatedAt: DateTime.now(),
    );
  }

  /// Toggle favorite status
  RecordingEntity toggleFavorite() {
    return copyWith(
      isFavorite: !isFavorite,
      updatedAt: DateTime.now(),
    );
  }

  /// Rename the recording
  RecordingEntity rename(String newName) {
    if (!isValidName(newName)) {
      throw ArgumentError('Invalid recording name: $newName');
    }

    return copyWith(
      name: newName.trim(),
      updatedAt: DateTime.now(),
    );
  }

  /// Move to different folder
  RecordingEntity moveToFolder(String newFolderId) {
    if (!canBeMovedToFolder(newFolderId)) {
      throw ArgumentError('Cannot move recording to folder: $newFolderId');
    }

    return copyWith(
      folderId: newFolderId,
      updatedAt: DateTime.now(),
    );
  }

  /// Add tag to recording
  RecordingEntity addTag(String tag) {
    if (tags.contains(tag)) return this;

    return copyWith(
      tags: [...tags, tag],
      updatedAt: DateTime.now(),
    );
  }

  /// Remove tag from recording
  RecordingEntity removeTag(String tag) {
    if (!tags.contains(tag)) return this;

    return copyWith(
      tags: tags.where((t) => t != tag).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Soft delete recording - move to Recently Deleted folder
  RecordingEntity softDelete() {
    return copyWith(
      originalFolderId: folderId, // Store current folder
      folderId: 'recently_deleted', // Move to Recently Deleted
      isDeleted: true,
      deletedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Restore recording from Recently Deleted folder
  RecordingEntity restore() {
    if (!isDeleted || originalFolderId == null) return this;
    
    return copyWith(
      folderId: originalFolderId, // Restore to original folder
      isDeleted: false,
      deletedAt: null,
      originalFolderId: null,
      updatedAt: DateTime.now(),
    );
  }

  // ==== FACTORY CONSTRUCTORS ====

  /// Create a new recording entity
  factory RecordingEntity.create({
    required String name,
    required String filePath,
    required String folderId,
    required AudioFormat format,
    required Duration duration,
    required int fileSize,
    required int sampleRate,
    double? latitude,
    double? longitude,
    String? locationName,
    List<String> tags = const [],
  }) {
    return RecordingEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      filePath: filePath,
      folderId: folderId,
      format: format,
      duration: duration,
      fileSize: fileSize,
      sampleRate: sampleRate,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      createdAt: DateTime.now(),
      isFavorite: false,
      tags: tags,
    );
  }

  /// Create from raw data (for database/API)
  factory RecordingEntity.fromData({
    required String id,
    required String name,
    required String filePath,
    required String folderId,
    required int formatIndex,
    required int durationSeconds,
    required int fileSize,
    required int sampleRate,
    double? latitude,
    double? longitude,
    String? locationName,
    required DateTime createdAt,
    DateTime? updatedAt,
    bool isFavorite = false,
    List<String> tags = const [],
  }) {
    return RecordingEntity(
      id: id,
      name: name,
      filePath: filePath,
      folderId: folderId,
      format: AudioFormat.values[formatIndex],
      duration: Duration(seconds: durationSeconds),
      fileSize: fileSize,
      sampleRate: sampleRate,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFavorite: isFavorite,
      tags: tags,
    );
  }

  // ==== DATA CONVERSION METHODS ====

  /// Convert to raw data (for database/API)
  Map<String, dynamic> toData() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'folderId': folderId,
      'format': format.index,
      'durationSeconds': duration.inSeconds,
      'fileSize': fileSize,
      'sampleRate': sampleRate,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isFavorite': isFavorite,
      'tags': tags,
    };
  }

  // ==== COMPARISON METHODS ====

  /// Compare recordings by creation date (newest first)
  static int compareByCreatedDate(RecordingEntity a, RecordingEntity b) {
    return b.createdAt.compareTo(a.createdAt);
  }

  /// Compare recordings by name (alphabetical)
  static int compareByName(RecordingEntity a, RecordingEntity b) {
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// Compare recordings by duration (longest first)
  static int compareByDuration(RecordingEntity a, RecordingEntity b) {
    return b.duration.compareTo(a.duration);
  }

  /// Compare recordings by file size (largest first)
  static int compareByFileSize(RecordingEntity a, RecordingEntity b) {
    return b.fileSize.compareTo(a.fileSize);
  }

  // ==== EQUATABLE IMPLEMENTATION ====

  @override
  List<Object?> get props => [
    id,
    name,
    filePath,
    folderId,
    format,
    duration,
    fileSize,
    sampleRate,
    latitude,
    longitude,
    locationName,
    createdAt,
    updatedAt,
    isFavorite,
    tags,
    isDeleted,
    deletedAt,
    originalFolderId,
    waveformData,
  ];

  @override
  String toString() {
    return 'RecordingEntity{id: $id, name: $name, duration: $durationFormatted, size: $fileSizeFormatted}';
  }
}