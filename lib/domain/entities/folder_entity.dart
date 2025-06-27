// File: domain/entities/folder_entity.dart
// 
// Folder Entity - Domain Layer
// ===========================
//
// This file defines the core business entity for voice memo folders in the WavNote app.
// As part of the Domain layer in Clean Architecture, this entity contains only pure
// business logic and has no dependencies on external frameworks, databases, or UI.
//
// Key Features:
// - Immutable data structure using Equatable for value equality
// - Business logic for validation and operations
// - Factory constructors for different folder types
// - Data conversion methods for persistence layer
// - Support for both default (system) and custom (user-created) folders

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../core/enums/folder_type.dart';

/// Pure business entity representing a voice memo folder
///
/// This entity contains only business logic and has no dependencies
/// on external frameworks or UI components beyond basic Flutter types.
/// 
/// Folders serve as organizational containers for voice recordings, with two types:
/// - Default folders: System-provided folders (All Recordings, Favorites, Recently Deleted)
/// - Custom folders: User-created folders for personal organization
///
/// The entity includes comprehensive validation, business rules, and immutable
/// update methods following functional programming principles.
class FolderEntity extends Equatable {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int recordingCount;
  final FolderType type;
  final bool isDeletable;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FolderEntity({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.recordingCount = 0,
    required this.type,
    this.isDeletable = false,
    required this.createdAt,
    this.updatedAt,
  });

  // ==== BUSINESS LOGIC PROPERTIES ====

  /// Whether this is a default system folder
  bool get isDefault => type.isDefault;

  /// Whether this is a custom user-created folder
  bool get isCustom => type.isCustom;

  /// Whether this folder has no recordings
  bool get isEmpty => recordingCount == 0;

  /// Whether this folder contains recordings
  bool get hasRecordings => recordingCount > 0;

  /// Whether this folder can be deleted by the user
  bool get canBeDeleted => isDeletable && isCustom;

  /// Whether this folder can be renamed
  bool get canBeRenamed => isCustom;

  /// Display text for recording count
  String get recordingCountText {
    if (recordingCount == 0) return 'No recordings';
    if (recordingCount == 1) return '1 recording';
    return '$recordingCount recordings';
  }

  /// Short display text for recording count (for UI)
  String get shortCountText => recordingCount.toString();

  // ==== BUSINESS LOGIC METHODS ====

  /// Validate if a folder name is acceptable
  bool isValidName(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= 50 &&
        trimmed.length >= 1 &&
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
      return 'Folder name cannot be empty';
    }

    if (trimmed.length > 50) {
      return 'Folder name cannot exceed 50 characters';
    }

    if (_containsInvalidCharacters(trimmed)) {
      return 'Folder name contains invalid characters';
    }

    return null; // No error
  }

  /// Check if this folder can accommodate more recordings
  bool canAddRecording() {
    // Business rule: folders can have maximum 1000 recordings
    return recordingCount < 1000;
  }

  // ==== IMMUTABLE UPDATE METHODS ====

  /// Create a copy with updated values
  FolderEntity copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    int? recordingCount,
    FolderType? type,
    bool? isDeletable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FolderEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      recordingCount: recordingCount ?? this.recordingCount,
      type: type ?? this.type,
      isDeletable: isDeletable ?? this.isDeletable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Increment recording count by 1
  FolderEntity incrementCount() {
    return copyWith(
      recordingCount: recordingCount + 1,
      updatedAt: DateTime.now(),
    );
  }

  /// Decrement recording count by 1 (minimum 0)
  FolderEntity decrementCount() {
    return copyWith(
      recordingCount: recordingCount > 0 ? recordingCount - 1 : 0,
      updatedAt: DateTime.now(),
    );
  }

  /// Update recording count to specific value
  FolderEntity updateCount(int newCount) {
    if (newCount < 0) throw ArgumentError('Recording count cannot be negative');

    return copyWith(
      recordingCount: newCount,
      updatedAt: DateTime.now(),
    );
  }

  /// Rename the folder
  FolderEntity rename(String newName) {
    if (!isValidName(newName)) {
      throw ArgumentError('Invalid folder name: $newName');
    }

    if (!canBeRenamed) {
      throw StateError('This folder cannot be renamed');
    }

    return copyWith(
      name: newName.trim(),
      updatedAt: DateTime.now(),
    );
  }

  // ==== FACTORY CONSTRUCTORS ====

  /// Create a default system folder
  factory FolderEntity.defaultFolder({
    required String id,
    required String name,
    required IconData icon,
    required Color color,
    int recordingCount = 0,
  }) {
    return FolderEntity(
      id: id,
      name: name,
      icon: icon,
      color: color,
      recordingCount: recordingCount,
      type: FolderType.defaultFolder,
      isDeletable: false,
      createdAt: DateTime.now(),
    );
  }

  /// Create a custom user folder
  factory FolderEntity.customFolder({
    required String name,
    required IconData icon,
    required Color color,
    String? id,
  }) {
    // Validate name before creating
    final entity = FolderEntity(
      id: 'temp',
      name: name,
      icon: icon,
      color: color,
      recordingCount: 0,
      type: FolderType.customFolder,
      isDeletable: true,
      createdAt: DateTime.now(),
    );

    if (!entity.isValidName(name)) {
      throw ArgumentError('Invalid folder name: $name');
    }

    return FolderEntity(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      icon: icon,
      color: color,
      recordingCount: 0,
      type: FolderType.customFolder,
      isDeletable: true,
      createdAt: DateTime.now(),
    );
  }

  /// Create folder from raw data (for database/API)
  factory FolderEntity.fromData({
    required String id,
    required String name,
    required int iconCodePoint,
    required int colorValue,
    required int recordingCount,
    required FolderType type,
    required bool isDeletable,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) {
    return FolderEntity(
      id: id,
      name: name,
      icon: IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
      color: Color(colorValue),
      recordingCount: recordingCount,
      type: type,
      isDeletable: isDeletable,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // ==== DATA CONVERSION METHODS ====

  /// Convert to raw data (for database/API)
  Map<String, dynamic> toData() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': icon.codePoint,
      'colorValue': color.value,
      'recordingCount': recordingCount,
      'type': type.index,
      'isDeletable': isDeletable,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // ==== COMPARISON METHODS ====

  /// Compare folders by creation date (newest first)
  static int compareByCreatedDate(FolderEntity a, FolderEntity b) {
    return b.createdAt.compareTo(a.createdAt);
  }

  /// Compare folders by name (alphabetical)
  static int compareByName(FolderEntity a, FolderEntity b) {
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// Compare folders by recording count (highest first)
  static int compareByRecordingCount(FolderEntity a, FolderEntity b) {
    return b.recordingCount.compareTo(a.recordingCount);
  }

  // ==== EQUATABLE IMPLEMENTATION ====

  @override
  List<Object?> get props => [
    id,
    name,
    icon,
    color,
    recordingCount,
    type,
    isDeletable,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() {
    return 'FolderEntity{id: $id, name: $name, type: ${type.name}, count: $recordingCount, canDelete: $canBeDeleted}';
  }
}