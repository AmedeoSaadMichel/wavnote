import 'package:flutter/material.dart';

enum FolderType {
  defaultFolder,
  customFolder,
}

class VoiceMemoFolder {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final FolderType type;
  final bool isDeletable;

  VoiceMemoFolder({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    this.count = 0,
    required this.type,
    this.isDeletable = false,
  });

  VoiceMemoFolder copyWith({
    String? id,
    String? title,
    IconData? icon,
    Color? color,
    int? count,
    FolderType? type,
    bool? isDeletable,
  }) {
    return VoiceMemoFolder(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      count: count ?? this.count,
      type: type ?? this.type,
      isDeletable: isDeletable ?? this.isDeletable,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'icon': icon.codePoint,
      'color': color.value,
      'count': count,
      'type': type.index,
      'isDeletable': isDeletable,
    };
  }

  // Create from JSON
  factory VoiceMemoFolder.fromJson(Map<String, dynamic> json) {
    return VoiceMemoFolder(
      id: json['id'],
      title: json['title'],
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      color: Color(json['color']),
      count: json['count'],
      type: FolderType.values[json['type']],
      isDeletable: json['isDeletable'],
    );
  }
}