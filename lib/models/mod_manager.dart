import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'mod.dart';
import 'app_settings.dart';

class ModManagerException implements Exception {
  final String message;
  ModManagerException(this.message);
  
  @override
  String toString() => message;
}

class ModManager {
  String? gamePath;
  String? modsPath;
  String? tempModsPath;
  final List<Mod> mods = [];
  static const String _settingsFileName = 'marvel_rivals_mod_manager.json';
  AppSettings settings = AppSettings();

  Future<void> loadSettings() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final settingsFile = File(path.join(appDir.path, _settingsFileName));
      
      if (await settingsFile.exists()) {
        final jsonString = await settingsFile.readAsString();
        final Map<String, dynamic> data = json.decode(jsonString);
        
        if (data['settings'] != null) {
          settings = AppSettings.fromJson(data['settings']);
        }
        
        if (data['gamePath'] != null) {
          await setGamePath(data['gamePath']);
        }

        if (data['mods'] != null) {
          final List<dynamic> modsJson = data['mods'];
          mods.clear();
          for (final modJson in modsJson) {
            final mod = Mod.fromJson(modJson);
            if (await File(mod.path).exists()) {
              mods.add(mod);
              if (mod.isEnabled) {
                await toggleMod(mod); // Восстанавливаем состояние мода
              }
            }
          }
        }
      }
    } catch (e) {
      print('Ошибка загрузки настроек: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final settingsFile = File(path.join(appDir.path, _settingsFileName));
      
      final Map<String, dynamic> data = {
        'settings': settings.toJson(),
        'gamePath': gamePath,
        'mods': mods.map((mod) => mod.toJson()).toList(),
      };

      await settingsFile.writeAsString(json.encode(data));
    } catch (e) {
      print('Ошибка сохранения настроек: $e');
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    settings = newSettings;
    await saveSettings();
  }

  Future<void> setGamePath(String selectedPath) async {
    gamePath = selectedPath;
    modsPath = path.join(gamePath!, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods');
    
    final modsDir = Directory(modsPath!);
    if (!await modsDir.exists()) {
      await modsDir.create(recursive: true);
    }

    final tempDir = await Directory.systemTemp.createTemp('MR-Mods');
    tempModsPath = tempDir.path;

    await saveSettings(); // Сохраняем настройки после установки пути
  }

  bool isValidGamePath(String gamePath) {
    // Проверяем наличие лаунчера
    final launcherPath = path.join(gamePath, 'MarvelRivals_Launcher.exe');
    final hasLauncher = File(launcherPath).existsSync();

    // Проверяем наличие папки игры
    final gameFolder = path.join(gamePath, 'MarvelGame');
    final hasGameFolder = Directory(gameFolder).existsSync();

    // Путь валиден, если есть и лаунчер, и папка игры
    return hasLauncher && hasGameFolder;
  }

  Future<void> addMod(String modPath, {Function(double)? onProgress}) async {
    if (!modPath.toLowerCase().endsWith('.pak')) {
      throw 'Неверный формат файла. Поддерживаются только .pak файлы';
    }

    final modFile = File(modPath);
    final modName = path.basename(modPath);
    final fileSize = await modFile.length();
    
    // Определяем конечный путь в зависимости от настройки autoEnableMods
    final targetPath = settings.autoEnableMods
        ? path.join(modsPath!, modName)  // Сразу в папку модов
        : path.join(tempModsPath!, modName);  // Во временную папку

    try {
      await modFile.copy(targetPath);
      onProgress?.call(1.0);

      final mod = Mod(
        name: modName,
        path: targetPath,
        isEnabled: settings.autoEnableMods,  // Устанавливаем статус в зависимости от настройки
        fileSize: fileSize,
      );

      mods.add(mod);
      await saveSettings();
    } catch (e) {
      throw 'Ошибка копирования файла: ${e.toString()}';
    }
  }

  Future<void> toggleMod(Mod mod) async {
    try {
      final modFile = File(mod.path);
      if (!await modFile.exists()) {
        throw ModManagerException('Файл мода не найден');
      }

      final newPath = mod.isEnabled
          ? path.join(tempModsPath!, path.basename(mod.path))
          : path.join(modsPath!, path.basename(mod.path));

      try {
        await modFile.rename(newPath);
      } catch (e) {
        // Если переименование не удалось, пробуем копировать и удалить
        await modFile.copy(newPath);
        await modFile.delete();
      }

      mod.path = newPath;
      mod.isEnabled = !mod.isEnabled;
      await saveSettings();
    } catch (e) {
      throw ModManagerException('Ошибка при переключении мода: ${e.toString()}');
    }
  }

  Future<void> deleteMod(Mod mod) async {
    try {
      final modFile = File(mod.path);
      if (await modFile.exists()) {
        await modFile.delete();
      }
      mods.remove(mod);
      await saveSettings();
    } catch (e) {
      throw ModManagerException('Ошибка при удалении мода: ${e.toString()}');
    }
  }
} 