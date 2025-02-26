import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class ModPreset {
  final String name;
  final List<String> enabledMods; // Список имен включенных модов
  final DateTime createdAt;
  final String? description;

  ModPreset({
    required this.name,
    required this.enabledMods,
    required this.createdAt,
    this.description,
  });

  // Конвертация в JSON
  Map<String, dynamic> toJson() => {
    'name': name,
    'enabledMods': enabledMods,
    'createdAt': createdAt.toIso8601String(),
    'description': description,
  };

  // Создание из JSON
  factory ModPreset.fromJson(Map<String, dynamic> json) => ModPreset(
    name: json['name'] as String,
    enabledMods: (json['enabledMods'] as List<dynamic>).cast<String>(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    description: json['description'] as String?,
  );
} 