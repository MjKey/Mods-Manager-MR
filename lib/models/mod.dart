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
  String displayName;
  String path;
  final int fileSize;
  bool isEnabled;
  final Set<ModTag> tags;
  final DateTime addedDate;

  Mod({
    required this.name,
    String? displayName,
    required this.path,
    this.fileSize = 0,
    this.isEnabled = false,
    Set<ModTag>? tags,
    DateTime? addedDate,
  }) : 
    displayName = displayName ?? name,
    addedDate = addedDate ?? DateTime.now(),
    tags = tags ?? {};

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'path': path,
      'fileSize': fileSize,
      'isEnabled': isEnabled,
      'tags': tags.map((tag) => tag.name).toList(),
      'addedDate': addedDate.toIso8601String(),
    };
  }

  factory Mod.fromJson(Map<String, dynamic> json) {
    return Mod(
      name: json['name'],
      displayName: json['displayName'],
      path: json['path'],
      fileSize: json['fileSize'] ?? 0,
      isEnabled: json['isEnabled'] ?? false,
      tags: (json['tags'] as List<dynamic>?)
          ?.map((tag) => ModTag.values.firstWhere((e) => e.name == tag))
          .toSet() ?? {},
      addedDate: json['addedDate'] != null 
          ? DateTime.parse(json['addedDate'])
          : null,
    );
  }

  static Future<Mod> fromFile(File file) async {
    final stat = await file.stat();
    final fileName = file.path.split(Platform.pathSeparator).last;
    return Mod(
      name: fileName,
      displayName: fileName,
      path: file.path,
      fileSize: stat.size,
    );
  }
} 