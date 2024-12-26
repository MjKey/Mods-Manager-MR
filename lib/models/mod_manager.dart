import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
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

  Future<void> launchGameSteam() async {
    if (gamePath == null) {
      throw ModManagerException('Путь к игре не указан');
    }

    try {
      final process = await Process.run(
        'cmd',
        ['/c', 'start', 'steam://rungameid/2767030'],
        runInShell: true,
      );

      if (process.exitCode != 0) {
        throw ModManagerException('Не удалось запустить игру через Steam');
      }
    } catch (e) {
      throw ModManagerException('Ошибка при запуске игры: ${e.toString()}');
    }
  }

  Future<void> launchGameLauncher() async {
    if (gamePath == null) {
      throw ModManagerException('Путь к игре не указан');
    }

    final launcherPath = path.join(gamePath!, 'MarvelRivals_Launcher.exe');
    if (!await File(launcherPath).exists()) {
      throw ModManagerException('Лаунчер игры не найден');
    }

    try {
      final process = await Process.run(
        launcherPath,
        [],
        workingDirectory: gamePath,
        runInShell: true,
      );

      if (process.exitCode != 0) {
        throw ModManagerException('Не удалось запустить игру через лаунчер');
      }
    } catch (e) {
      throw ModManagerException('Ошибка при запуске игры: ${e.toString()}');
    }
  }

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
          
          if (settings.disabledModsPath != null) {
            tempModsPath = settings.disabledModsPath;
            final tempDir = Directory(tempModsPath!);
            if (!await tempDir.exists()) {
              await tempDir.create(recursive: true);
            }
          } else {
            final tempDir = await Directory.systemTemp.createTemp('MR-Mods');
            tempModsPath = tempDir.path;
          }

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

          final modsDir = Directory(modsPath!);
          if (await modsDir.exists()) {
            final enabledFiles = await modsDir.list().where((entity) => 
              entity is File && entity.path.toLowerCase().endsWith('.pak')
            ).toList();

            for (final file in enabledFiles) {
              final fileName = path.basename(file.path);
              final existingModIndex = mods.indexWhere((mod) => mod.name == fileName);
              
              if (existingModIndex != -1) {
                mods[existingModIndex].path = file.path;
                mods[existingModIndex].isEnabled = true;
              } else {
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
    final oldTempPath = tempModsPath;
    settings = newSettings;

    if (settings.disabledModsPath != null && settings.disabledModsPath != oldTempPath) {
      final newTempDir = Directory(settings.disabledModsPath!);
      if (!await newTempDir.exists()) {
        await newTempDir.create(recursive: true);
      }

      final disabledMods = mods.where((mod) => !mod.isEnabled).toList();
      for (final mod in disabledMods) {
        final oldFile = File(mod.path);
        if (await oldFile.exists()) {
          final newPath = path.join(settings.disabledModsPath!, path.basename(mod.path));
          await oldFile.copy(newPath);
          await oldFile.delete();
          mod.path = newPath;
        }
      }

      tempModsPath = settings.disabledModsPath;
    }

    await saveSettings();
  }

  Future<void> setGamePath(String selectedPath) async {
    gamePath = selectedPath;
    modsPath = path.join(gamePath!, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods');
    
    final modsDir = Directory(modsPath!);
    if (!await modsDir.exists()) {
      await modsDir.create(recursive: true);
    }

    if (settings.disabledModsPath != null) {
      tempModsPath = settings.disabledModsPath;
      final tempDir = Directory(tempModsPath!);
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
    } else {
      final tempDir = await Directory.systemTemp.createTemp('MR-Mods');
      tempModsPath = tempDir.path;
    }

    await saveSettings();
  }

  bool isValidGamePath(String gamePath) {
    final launcherPath = path.join(gamePath, 'MarvelRivals_Launcher.exe');
    final hasLauncher = File(launcherPath).existsSync();

    final gameFolder = path.join(gamePath, 'MarvelGame');
    final hasGameFolder = Directory(gameFolder).existsSync();

    return hasLauncher && hasGameFolder;
  }

  Future<void> addMod(String filePath, {void Function(double)? onProgress, bool replace = false}) async {
    if (!filePath.toLowerCase().endsWith('.pak')) {
      throw ModManagerException('invalid_file_format');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw ModManagerException('file_not_found');
    }

    final fileName = path.basename(filePath);
    final targetPath = settings.autoEnableMods
        ? path.join(modsPath!, fileName)
        : path.join(tempModsPath!, fileName);

    if (!replace && await File(targetPath).exists()) {
      throw ModManagerException('mod_exists');
    }

    await _copyFileWithProgress(file, File(targetPath), onProgress);
    
    final mod = Mod(
      name: fileName,
      path: targetPath,
      fileSize: await file.length(),
      isEnabled: settings.autoEnableMods,
    );

    final existingIndex = mods.indexWhere((m) => m.name == fileName);
    if (existingIndex != -1) {
      mods[existingIndex] = mod;
    } else {
      mods.add(mod);
    }
    await saveSettings();
  }

  Future<void> _copyFileWithProgress(File source, File target, void Function(double)? onProgress) async {
    try {
      final sourceStream = source.openRead();
      final sinkStream = target.openWrite();
      final sourceSize = await source.length();
      var copiedBytes = 0;

      await for (final chunk in sourceStream) {
        sinkStream.add(chunk);
        copiedBytes += chunk.length;
        onProgress?.call(copiedBytes / sourceSize);
      }

      await sinkStream.close();
    } catch (e) {
      if (await target.exists()) {
        await target.delete();
      }
      throw ModManagerException('error_copying_file');
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
        final mod = Mod.fromJson(modData);
        final modFile = archive.findFile(mod.name);
        
        if (modFile != null) {
          final targetPath = path.join(tempModsPath!, mod.name);
          await File(targetPath).writeAsBytes(modFile.content);
          
          mod.path = targetPath;
          mod.isEnabled = false;
          importedMods.add(mod);
          mods.add(mod);
        }
      }

      await saveSettings();
    }

    return importedMods;
  }
} 