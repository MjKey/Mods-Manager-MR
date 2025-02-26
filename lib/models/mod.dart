class Mod {
  final String name;        // Отображаемое имя (можно менять)
  final String fileName;    // Базовое имя файла (неизменяемое)
  final int order;         // Порядок загрузки
  final String? description;
  final String pakPath;
  final String? unpackedPath;
  final DateTime installDate;
  final String? version;
  final String? character;
  final bool isEnabled;
  final String? nexusUrl;
  final String? nexusImageUrl;
  final DateTime? lastUpdateCheck;
  final List<String> tags;

  Mod({
    required this.name,
    required this.fileName,
    this.order = 0,
    this.description,
    required this.pakPath,
    this.unpackedPath,
    required this.installDate,
    this.version,
    this.character,
    required this.isEnabled,
    this.nexusUrl,
    this.nexusImageUrl,
    this.lastUpdateCheck,
    this.tags = const [],
  });

  String get baseFileName => fileName.replaceFirst(RegExp(r'^\d{3}_'), '');

  Mod copyWith({
    String? name,
    String? fileName,
    int? order,
    String? description,
    String? pakPath,
    String? unpackedPath,
    DateTime? installDate,
    String? version,
    String? character,
    bool? isEnabled,
    String? nexusUrl,
    String? nexusImageUrl,
    DateTime? lastUpdateCheck,
    List<String>? tags,
  }) {
    return Mod(
      name: name ?? this.name,
      fileName: fileName ?? this.fileName,
      order: order ?? this.order,
      description: description ?? this.description,
      pakPath: pakPath ?? this.pakPath,
      unpackedPath: unpackedPath ?? this.unpackedPath,
      installDate: installDate ?? this.installDate,
      version: version ?? this.version,
      character: character ?? this.character,
      isEnabled: isEnabled ?? this.isEnabled,
      nexusUrl: nexusUrl ?? this.nexusUrl,
      nexusImageUrl: nexusImageUrl ?? this.nexusImageUrl,
      lastUpdateCheck: lastUpdateCheck ?? this.lastUpdateCheck,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'fileName': fileName,
      'order': order,
      'description': description,
      'pakPath': pakPath,
      'unpackedPath': unpackedPath,
      'installDate': installDate.toIso8601String(),
      'version': version,
      'character': character,
      'isEnabled': isEnabled,
      'nexusUrl': nexusUrl,
      'nexusImageUrl': nexusImageUrl,
      'lastUpdateCheck': lastUpdateCheck?.toIso8601String(),
      'tags': tags,
    };
  }

  factory Mod.fromJson(Map<String, dynamic> json) {
    return Mod(
      name: json['name'] as String,
      fileName: json['fileName'] as String? ?? json['name'] as String,
      order: json['order'] as int? ?? 0,
      description: json['description'] as String?,
      pakPath: json['pakPath'] as String,
      unpackedPath: json['unpackedPath'] as String?,
      installDate: DateTime.parse(json['installDate'] as String),
      version: json['version'] as String?,
      character: json['character'] as String?,
      isEnabled: json['isEnabled'] as bool,
      nexusUrl: json['nexusUrl'] as String?,
      nexusImageUrl: json['nexusImageUrl'] as String?,
      lastUpdateCheck: json['lastUpdateCheck'] != null 
          ? DateTime.parse(json['lastUpdateCheck'] as String)
          : null,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
} 