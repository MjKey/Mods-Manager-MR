import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/mod.dart';
import 'platform_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _settingsFileName = 'settings.json';
  static const String _modsStateFileName = 'mods_state.json';
  static const String _modsPathKey = 'mods_path';

  static Future<String> get _settingsPath async {
    final appDir = await PlatformService.getModsDirectory();
    return path.join(appDir, _settingsFileName);
  }

  static Future<String> get _modsStatePath async {
    final appDir = await PlatformService.getModsDirectory();
    return path.join(appDir, _modsStateFileName);
  }

  static String get defaultAppDataPath {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    return path.join(localAppData!, 'MarvelRivalsModsManager');
  }

  static Future<String> getModsPath() async {
    final prefs = await SharedPreferences.getInstance();
    final modsPath = prefs.getString(_modsPathKey) ?? path.join(defaultAppDataPath, 'Disabled Mods');
    
    // Создаем директорию, если она не существует
    final directory = Directory(modsPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    return modsPath;
  }

  static Future<void> setModsPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modsPathKey, path);
    
    // Создаем директорию, если она не существует
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  // Структура настроек приложения
  static Future<Map<String, dynamic>> loadSettings() async {
    try {
      final file = File(await _settingsPath);
      if (!await file.exists()) {
        // Возвращаем настройки по умолчанию
        return {
          'gamePath': null,
          'autoCheckUpdates': true,
          'lastUpdateCheck': null,
        };
      }

      final jsonString = await file.readAsString();
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Ошибка при загрузке настроек: $e');
      return {};
    }
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final file = File(await _settingsPath);
      await file.writeAsString(json.encode(settings));
    } catch (e) {
      print('Ошибка при сохранении настроек: $e');
    }
  }

  // Вспомогательные методы для работы с конкретными настройками
  static Future<String?> getGamePath() async {
    final settings = await loadSettings();
    return settings['gamePath'] as String?;
  }

  static Future<void> setGamePath(String? path) async {
    final settings = await loadSettings();
    settings['gamePath'] = path;
    await saveSettings(settings);
  }

  static Future<bool> getAutoCheckUpdates() async {
    final settings = await loadSettings();
    return settings['autoCheckUpdates'] as bool? ?? true;
  }

  static Future<void> setAutoCheckUpdates(bool value) async {
    final settings = await loadSettings();
    settings['autoCheckUpdates'] = value;
    await saveSettings(settings);
  }

  // Структура для хранения состояния модов
  static Future<Map<String, dynamic>> loadModsState() async {
    try {
      final file = File(await _modsStatePath);
      if (!await file.exists()) {
        return {};
      }

      final jsonString = await file.readAsString();
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Ошибка при загрузке состояния модов: $e');
      return {};
    }
  }

  static Future<void> saveModsState(List<Mod> mods) async {
    try {
      final file = File(await _modsStatePath);
      final modsState = <String, dynamic>{};

      for (final mod in mods) {
        modsState[mod.name] = {
          'isEnabled': mod.isEnabled,
          'character': mod.character,
          'description': mod.description,
          'version': mod.version,
          'installDate': mod.installDate.toIso8601String(),
          'unpackedPath': mod.unpackedPath,
          'nexusUrl': mod.nexusUrl,
          'nexusImageUrl': mod.nexusImageUrl,
          'lastUpdateCheck': mod.lastUpdateCheck?.toIso8601String(),
          'tags': mod.tags,
        };
      }

      await file.writeAsString(json.encode(modsState));
    } catch (e) {
      print('Ошибка при сохранении состояния модов: $e');
    }
  }
} 