import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/preset.dart';
import '../services/settings_service.dart';
import 'localization_service.dart';

class PresetsService {
  static final LocalizationService _localization = LocalizationService();
  
  static String get _presetsPath {
    return path.join(SettingsService.defaultAppDataPath, 'Presets');
  }

  // Инициализация директории для пресетов
  static Future<void> initialize() async {
    final directory = Directory(_presetsPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  // Сохранение пресета
  static Future<void> savePreset(ModPreset preset) async {
    try {
      final file = File(path.join(_presetsPath, '${preset.name}.json'));
      await file.writeAsString(jsonEncode(preset.toJson()));
    } catch (e) {
      throw Exception(_localization.translate('presets.errors.save', {'error': e.toString()}));
    }
  }

  // Загрузка всех пресетов
  static Future<List<ModPreset>> loadPresets() async {
    try {
      final directory = Directory(_presetsPath);
      if (!await directory.exists()) {
        return [];
      }

      final List<ModPreset> presets = [];
      await for (final entity in directory.list()) {
        if (entity is File && path.extension(entity.path) == '.json') {
          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            presets.add(ModPreset.fromJson(json));
          } catch (e) {
            print(_localization.translate('presets.errors.load_file', {
              'file': path.basename(entity.path),
              'error': e.toString()
            }));
          }
        }
      }

      // Сортируем по дате создания (новые сверху)
      presets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return presets;
    } catch (e) {
      throw Exception(_localization.translate('presets.errors.load', {'error': e.toString()}));
    }
  }

  // Удаление пресета
  static Future<void> deletePreset(String name) async {
    try {
      final file = File(path.join(_presetsPath, '$name.json'));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception(_localization.translate('presets.errors.delete', {'error': e.toString()}));
    }
  }
} 