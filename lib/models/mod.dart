import 'dart:io';

enum ModTag {
  color,
  model,
  sound,
  music,
  other;

  String getLocalizedLabel(String Function(String) getLocalized) {
    return getLocalized('tag_${name}');
  }
}

class Mod {
  final String name;
  String path;
  final int fileSize;
  bool isEnabled;
  final Set<ModTag> tags;

  Mod({
    required this.name,
    required this.path,
    this.fileSize = 0,
    this.isEnabled = false,
    Set<ModTag>? tags,
  }) : tags = tags ?? {};

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'fileSize': fileSize,
      'isEnabled': isEnabled,
      'tags': tags.map((tag) => tag.name).toList(),
    };
  }

  factory Mod.fromJson(Map<String, dynamic> json) {
    return Mod(
      name: json['name'],
      path: json['path'],
      fileSize: json['fileSize'] ?? 0,
      isEnabled: json['isEnabled'] ?? false,
      tags: (json['tags'] as List<dynamic>?)
          ?.map((tag) => ModTag.values.firstWhere((e) => e.name == tag))
          .toSet() ?? {},
    );
  }

  static Future<Mod> fromFile(File file) async {
    final stat = await file.stat();
    return Mod(
      name: file.path.split(Platform.pathSeparator).last,
      path: file.path,
      fileSize: stat.size,
    );
  }
} 