import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:win32/win32.dart';
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
          gamePath = data['gamePath'];
          modsPath = path.join(gamePath!, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods');
          final tempDir = await Directory.systemTemp.createTemp('MR-Mods');
          tempModsPath = tempDir.path;

          // Загружаем сохраненные моды
          if (data['mods'] != null) {
            final List<dynamic> modsJson = data['mods'];
            mods.clear();
            for (final modJson in modsJson) {
              final mod = Mod.fromJson(modJson);
              if (await File(mod.path).exists()) {
                mods.add(mod);
              }
            }
          }

          // Сканируем папку ~mods
          final modsDir = Directory(modsPath!);
          if (await modsDir.exists()) {
            final enabledFiles = await modsDir.list().where((entity) => 
              entity is File && entity.path.toLowerCase().endsWith('.pak')
            ).toList();

            for (final file in enabledFiles) {
              final fileName = path.basename(file.path);
              final existingModIndex = mods.indexWhere((mod) => mod.name == fileName);
              
              if (existingModIndex != -1) {
                // Обновляем существующий мод
                mods[existingModIndex].path = file.path;
                mods[existingModIndex].isEnabled = true;
              } else {
                // Добавляем новый мод
                final stat = await (file as File).stat();
                mods.add(Mod(
                  name: fileName,
                  path: file.path,
                  fileSize: stat.size,
                  isEnabled: true,
                ));
              }
            }
          }

          await saveSettings();
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
    
    final targetPath = settings.autoEnableMods
        ? path.join(modsPath!, modName)
        : path.join(tempModsPath!, modName);

    try {
      await modFile.copy(targetPath);
      onProgress?.call(1.0);

      final mod = Mod(
        name: modName,
        path: targetPath,
        fileSize: fileSize,
        isEnabled: settings.autoEnableMods,
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

  Future<String> exportMods(String exportPath) async {
    final archive = Archive();
    final enabledMods = mods.where((mod) => mod.isEnabled).toList();
    
    final modsMetadata = enabledMods.map((mod) => mod.toJson()).toList();
    final metadataBytes = utf8.encode(json.encode(modsMetadata));
    archive.addFile(ArchiveFile('metadata.json', metadataBytes.length, metadataBytes));

    for (final mod in enabledMods) {
      final file = File(mod.path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(
          path.basename(mod.path),
          bytes.length,
          bytes,
        ));
      }
    }

    final outputPath = path.join(exportPath, 'mods_export.mrmm');
    final bytes = ZipEncoder().encode(archive);
    if (bytes != null) {
      await File(outputPath).writeAsBytes(bytes);
    }
    
    return outputPath;
  }

  Future<List<Mod>> importMods(String archivePath) async {
    final bytes = await File(archivePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final importedMods = <Mod>[];

    final metadataFile = archive.findFile('metadata.json');
    if (metadataFile != null) {
      final metadataJson = utf8.decode(metadataFile.content);
      final List<dynamic> modsMetadata = json.decode(metadataJson);

      for (final modData in modsMetadata) {
        final modName = path.basename(modData['path']);
        final modFile = archive.findFile(modName);
        
        if (modFile != null) {
          final targetPath = path.join(modsPath!, modName);
          await File(targetPath).writeAsBytes(modFile.content);
          
          final mod = Mod(
            name: modName,
            path: targetPath,
            fileSize: modFile.size,
            isEnabled: true,
            tags: (modData['tags'] as List<dynamic>?)
                ?.map((tag) => ModTag.values.firstWhere((e) => e.name == tag))
                .toSet(),
          );
          importedMods.add(mod);
          mods.add(mod);
        }
      }
    }

    await saveSettings();
    return importedMods;
  }

  Future<void> launchGame() async {
    if (gamePath == null) return;
    
    final launcherPath = path.join(gamePath!, 'MarvelRivals_Launcher.exe');
    if (await File(launcherPath).exists()) {
      final result = ShellExecute(
        0, // hwnd
        TEXT('runas'),  // operation
        TEXT(launcherPath), // file
        TEXT(''), // parameters
        TEXT(gamePath!), // directory
        SW_SHOW,
      );

      if (result <= 32) {
        throw ModManagerException('Ошибка запуска игры: $result');
      }
    } else {
      throw ModManagerException('Лаунчер игры не найден');
    }
  }
} 