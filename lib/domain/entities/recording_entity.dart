// File: domain/entities/recording_entity.dart
import 'package:equatable/equatable.dart';
import '../../core/enums/audio_format.dart';
import '../../core/utils/app_file_utils.dart';

/// Pure business entity representing an audio recording
class RecordingEntity extends Equatable {
  final String id;
  final String name;
  final String filePath; // Path relativo memorizzato nel DB
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

  // Getter per risolvere il path assoluto
  Future<String> get resolvedFilePath => AppFileUtils.resolve(filePath);

  // ==== BUSINESS LOGIC PROPERTIES ====
  // ... (tutto il resto invariato) ...

  bool get isEmpty => duration.inSeconds == 0 || fileSize == 0;
  bool get hasValidDuration => duration.inSeconds > 0;
  bool get hasLocation => latitude != null && longitude != null;
  bool get isModified => updatedAt != null && updatedAt!.isAfter(createdAt);
  bool get isInTrash => isDeleted && folderId == 'recently_deleted';
  int get daysUntilPermanentDeletion {
    if (!isDeleted || deletedAt == null) return 0;
    final daysSinceDeletion = DateTime.now().difference(deletedAt!).inDays;
    return (15 - daysSinceDeletion).clamp(0, 15);
  }

  bool get shouldBePermanentlyDeleted {
    if (!isDeleted || deletedAt == null) return false;
    return DateTime.now().difference(deletedAt!).inDays >= 15;
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get shortDurationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get fileExtension => format.fileExtension;
  String get qualityDescription {
    if (sampleRate >= 48000) return 'High Quality';
    if (sampleRate >= 44100) return 'CD Quality';
    if (sampleRate >= 22050) return 'Good Quality';
    return 'Basic Quality';
  }

  String get ageDescription {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
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

  bool isValidName(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= 100 &&
        !_containsInvalidCharacters(trimmed);
  }

  bool _containsInvalidCharacters(String name) {
    const invalidChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    return invalidChars.any((char) => name.contains(char));
  }

  String? getNameValidationError(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Recording name cannot be empty';
    if (trimmed.length > 100) {
      return 'Recording name cannot exceed 100 characters';
    }
    if (_containsInvalidCharacters(trimmed)) {
      return 'Recording name contains invalid characters';
    }
    return null;
  }

  bool canBeMovedToFolder(String targetFolderId) =>
      targetFolderId != folderId && targetFolderId.isNotEmpty;
  int get approximateBitrate {
    if (duration.inSeconds == 0) return 0;
    return ((fileSize * 8) / duration.inSeconds).round();
  }

  // ==== IMMUTABLE UPDATE METHODS ====
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

  RecordingEntity markAsFavorite() =>
      copyWith(isFavorite: true, updatedAt: DateTime.now());
  RecordingEntity removeFromFavorites() =>
      copyWith(isFavorite: false, updatedAt: DateTime.now());
  RecordingEntity toggleFavorite() =>
      copyWith(isFavorite: !isFavorite, updatedAt: DateTime.now());
  RecordingEntity rename(String newName) {
    if (!isValidName(newName)) {
      throw ArgumentError('Invalid recording name: $newName');
    }
    return copyWith(name: newName.trim(), updatedAt: DateTime.now());
  }

  RecordingEntity moveToFolder(String newFolderId) {
    if (!canBeMovedToFolder(newFolderId)) {
      throw ArgumentError('Cannot move recording to folder: $newFolderId');
    }
    return copyWith(folderId: newFolderId, updatedAt: DateTime.now());
  }

  RecordingEntity addTag(String tag) {
    if (tags.contains(tag)) return this;
    return copyWith(tags: [...tags, tag], updatedAt: DateTime.now());
  }

  RecordingEntity removeTag(String tag) {
    if (!tags.contains(tag)) return this;
    return copyWith(
      tags: tags.where((t) => t != tag).toList(),
      updatedAt: DateTime.now(),
    );
  }

  RecordingEntity softDelete() => copyWith(
    originalFolderId: folderId,
    folderId: 'recently_deleted',
    isDeleted: true,
    deletedAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  RecordingEntity restore() {
    if (!isDeleted || originalFolderId == null) return this;
    return copyWith(
      folderId: originalFolderId,
      isDeleted: false,
      deletedAt: null,
      originalFolderId: null,
      updatedAt: DateTime.now(),
    );
  }

  // ==== FACTORY CONSTRUCTORS ====
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

  static int compareByCreatedDate(RecordingEntity a, RecordingEntity b) =>
      b.createdAt.compareTo(a.createdAt);
  static int compareByName(RecordingEntity a, RecordingEntity b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  static int compareByDuration(RecordingEntity a, RecordingEntity b) =>
      b.duration.compareTo(a.duration);
  static int compareByFileSize(RecordingEntity a, RecordingEntity b) =>
      b.fileSize.compareTo(a.fileSize);

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
  String toString() =>
      'RecordingEntity{id: $id, name: $name, duration: $durationFormatted, size: $fileSizeFormatted}';
}
