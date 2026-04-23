enum FolderType { defaultFolder, customFolder }

class VoiceMemoFolder {
  final String id;
  final String title;
  final int iconCodePoint;
  final int colorValue;
  final int count;
  final FolderType type;
  final bool isDeletable;

  VoiceMemoFolder({
    required this.id,
    required this.title,
    required this.iconCodePoint,
    required this.colorValue,
    this.count = 0,
    required this.type,
    this.isDeletable = false,
  });

  VoiceMemoFolder copyWith({
    String? id,
    String? title,
    int? iconCodePoint,
    int? colorValue,
    int? count,
    FolderType? type,
    bool? isDeletable,
  }) {
    return VoiceMemoFolder(
      id: id ?? this.id,
      title: title ?? this.title,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
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
      'icon': iconCodePoint,
      'color': colorValue,
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
      iconCodePoint: json['icon'],
      colorValue: json['color'],
      count: json['count'],
      type: FolderType.values[json['type']],
      isDeletable: json['isDeletable'],
    );
  }
}
