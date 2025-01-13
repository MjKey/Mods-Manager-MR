class Mod {
  final String name;
  final String? description;
  final String pakPath;
  final String unpackedPath;
  final DateTime installDate;
  final String version;
  final String? character;
  final bool isEnabled;
  final String? nexusUrl;
  final String? nexusImageUrl;
  final DateTime? lastUpdateCheck;
  final List<String> tags;

  Mod({
    required this.name,
    this.description,
    required this.pakPath,
    required this.unpackedPath,
    required this.installDate,
    required this.version,
    this.character,
    required this.isEnabled,
    this.nexusUrl,
    this.nexusImageUrl,
    this.lastUpdateCheck,
    this.tags = const [],
  });

  Mod copyWith({
    String? name,
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
} 