// File: data/models/recording_model.dart
import 'dart:convert';
import '../../domain/entities/recording_entity.dart';
import '../../core/enums/audio_format.dart';

/// Data model for recording with database mapping
///
/// Handles conversion between database storage format
/// and domain entity objects with validation.
class RecordingModel {
  final String id;
  final String name;
  final String filePath;
  final String folderId;
  final int formatIndex;
  final int durationSeconds; // Legacy column - kept for backwards compatibility
  final int? durationMilliseconds; // New precise duration column
  final int fileSize;
  final int sampleRate;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String createdAt;
  final String? updatedAt;
  final bool isFavorite;
  final String? tags;
  final bool isDeleted;
  final String? deletedAt;
  final String? originalFolderId;
  final String? waveformDataJson; // JSON string of List<double>

  const RecordingModel({
    required this.id,
    required this.name,
    required this.filePath,
    required this.folderId,
    required this.formatIndex,
    required this.durationSeconds,
    this.durationMilliseconds,
    required this.fileSize,
    required this.sampleRate,
    this.latitude,
    this.longitude,
    this.locationName,
    required this.createdAt,
    this.updatedAt,
    required this.isFavorite,
    this.tags,
    required this.isDeleted,
    this.deletedAt,
    this.originalFolderId,
    this.waveformDataJson,
  });

  /// Create from entity
  factory RecordingModel.fromEntity(RecordingEntity entity) {
    return RecordingModel(
      id: entity.id,
      name: entity.name,
      filePath: entity.filePath,
      folderId: entity.folderId,
      formatIndex: entity.format.index,
      durationSeconds: entity.duration.inSeconds, // Keep for compatibility
      durationMilliseconds: entity.duration.inMilliseconds, // Precise duration
      fileSize: entity.fileSize,
      sampleRate: entity.sampleRate,
      latitude: entity.latitude,
      longitude: entity.longitude,
      locationName: entity.locationName,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt?.toIso8601String(),
      isFavorite: entity.isFavorite,
      tags: entity.tags.isNotEmpty ? entity.tags.join(',') : null,
      isDeleted: entity.isDeleted,
      deletedAt: entity.deletedAt?.toIso8601String(),
      originalFolderId: entity.originalFolderId,
      waveformDataJson: entity.waveformData != null 
          ? jsonEncode(entity.waveformData) 
          : null,
    );
  }

  /// Create from database map
  factory RecordingModel.fromDatabase(Map<String, dynamic> map) {
    return RecordingModel(
      id: map['id'] as String,
      name: map['name'] as String,
      filePath: map['file_path'] as String,
      folderId: map['folder_id'] as String,
      formatIndex: map['format_index'] as int,
      durationSeconds: map['duration_seconds'] as int,
      durationMilliseconds: map['duration_milliseconds'] as int?,
      fileSize: map['file_size'] as int,
      sampleRate: map['sample_rate'] as int,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      locationName: map['location_name'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
      isFavorite: (map['is_favorite'] as int) == 1,
      tags: map['tags'] as String?,
      isDeleted: (map['is_deleted'] as int?) == 1,
      deletedAt: map['deleted_at'] as String?,
      originalFolderId: map['original_folder_id'] as String?,
      waveformDataJson: map.containsKey('waveform_data') ? map['waveform_data'] as String? : null,
    );
  }

  /// Create from JSON
  factory RecordingModel.fromJson(Map<String, dynamic> json) {
    return RecordingModel(
      id: json['id'] as String,
      name: json['name'] as String,
      filePath: json['filePath'] as String,
      folderId: json['folderId'] as String,
      formatIndex: json['formatIndex'] as int,
      durationSeconds: json['durationSeconds'] as int,
      durationMilliseconds: json['durationMilliseconds'] as int?,
      fileSize: json['fileSize'] as int,
      sampleRate: json['sampleRate'] as int,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      locationName: json['locationName'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String?,
      isFavorite: json['isFavorite'] as bool,
      tags: json['tags'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] as String?,
      originalFolderId: json['originalFolderId'] as String?,
    );
  }

  /// Convert to entity
  RecordingEntity toEntity() {
    return RecordingEntity(
      id: id,
      name: name,
      filePath: filePath,
      folderId: folderId,
      format: AudioFormat.values[formatIndex],
      duration: durationMilliseconds != null 
          ? Duration(milliseconds: durationMilliseconds!) 
          : Duration(seconds: durationSeconds), // Fallback to seconds for legacy data
      fileSize: fileSize,
      sampleRate: sampleRate,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      createdAt: DateTime.parse(createdAt),
      updatedAt: updatedAt != null ? DateTime.parse(updatedAt!) : null,
      isFavorite: isFavorite,
      tags: tags?.split(',').where((tag) => tag.trim().isNotEmpty).toList() ?? [],
      isDeleted: isDeleted,
      deletedAt: deletedAt != null ? DateTime.parse(deletedAt!) : null,
      originalFolderId: originalFolderId,
      waveformData: waveformDataJson != null 
          ? (jsonDecode(waveformDataJson!) as List).cast<double>()
          : null,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'name': name,
      'file_path': filePath,
      'folder_id': folderId,
      'format_index': formatIndex,
      'duration_seconds': durationSeconds,
      'duration_milliseconds': durationMilliseconds,
      'file_size': fileSize,
      'sample_rate': sampleRate,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_favorite': isFavorite ? 1 : 0,
      'tags': tags,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt,
      'original_folder_id': originalFolderId,
      'waveform_data': waveformDataJson,
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'folderId': folderId,
      'formatIndex': formatIndex,
      'durationSeconds': durationSeconds,
      'durationMilliseconds': durationMilliseconds,
      'fileSize': fileSize,
      'sampleRate': sampleRate,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isFavorite': isFavorite,
      'tags': tags,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
      'originalFolderId': originalFolderId,
    };
  }

  /// Validate model data
  bool get isValid {
    try {
      // Check required fields
      if (id.isEmpty || name.isEmpty || filePath.isEmpty || folderId.isEmpty) {
        return false;
      }

      // Check format index is valid
      if (formatIndex < 0 || formatIndex >= AudioFormat.values.length) {
        return false;
      }

      // Check numeric values are reasonable
      if (durationSeconds < 0 || fileSize < 0 || sampleRate <= 0) {
        return false;
      }

      // Check date format
      DateTime.parse(createdAt);
      if (updatedAt != null) {
        DateTime.parse(updatedAt!);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get audio format
  AudioFormat get format => AudioFormat.values[formatIndex];

  /// Get duration
  Duration get duration => Duration(seconds: durationSeconds);

  /// Get tags as list
  List<String> get tagsList {
    if (tags == null || tags!.isEmpty) return [];
    return tags!.split(',').where((tag) => tag.trim().isNotEmpty).toList();
  }

  /// Create copy with updated values
  RecordingModel copyWith({
    String? id,
    String? name,
    String? filePath,
    String? folderId,
    int? formatIndex,
    int? durationSeconds,
    int? fileSize,
    int? sampleRate,
    double? latitude,
    double? longitude,
    String? locationName,
    String? createdAt,
    String? updatedAt,
    bool? isFavorite,
    String? tags,
    bool? isDeleted,
    String? deletedAt,
    String? originalFolderId,
  }) {
    return RecordingModel(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      folderId: folderId ?? this.folderId,
      formatIndex: formatIndex ?? this.formatIndex,
      durationSeconds: durationSeconds ?? this.durationSeconds,
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
    );
  }

  @override
  String toString() {
    return 'RecordingModel(id: $id, name: $name, format: ${format.name})';
  }
}