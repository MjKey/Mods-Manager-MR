import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mod.dart';

class ModService {
  static const String _modsKey = 'installed_mods';
  final SharedPreferences _prefs;
  final String gamePath;
  
  ModService(this._prefs, this.gamePath);

  Future<List<Mod>> loadMods() async {
    final String? modsJson = _prefs.getString(_modsKey);
    final List<Mod> loadedMods = [];
    final modsDir = Directory(path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods'));
    final tempDir = await Directory.systemTemp.createTemp('MR-Mods');
    
    // Загружаем сохраненные моды
    if (modsJson != null) {
      final List<dynamic> modsList = json.decode(modsJson);
      for (final modJson in modsList) {
        final mod = Mod.fromJson(modJson);
        if (await File(mod.path).exists()) {
          loadedMods.add(mod);
        }
      }
    }

    // Сканируем папку ~mods
    if (await modsDir.exists()) {
      final enabledFiles = await modsDir.list().where((entity) => 
        entity is File && entity.path.toLowerCase().endsWith('.pak')
      ).toList();

      for (final file in enabledFiles) {
        final fileName = path.basename(file.path);
        // Если мод уже загружен, обновляем его состояние
        final existingMod = loadedMods.firstWhere(
          (mod) => mod.name == fileName,
          orElse: () {
            final stat = (file as File).statSync();
            return Mod(
              name: fileName,
              path: file.path,
              fileSize: stat.size,
              isEnabled: true, // Файл в ~mods = включен
            );
          },
        );
        
        if (!loadedMods.contains(existingMod)) {
          loadedMods.add(existingMod);
        } else {
          // Обновляем путь и состояние существующего мода
          final index = loadedMods.indexWhere((mod) => mod.name == fileName);
          loadedMods[index].path = file.path;
          loadedMods[index].isEnabled = true;
        }
      }
    }

    // Сканируем временную папку для выключенных модов
    if (await tempDir.exists()) {
      final disabledFiles = await tempDir.list().where((entity) => 
        entity is File && entity.path.toLowerCase().endsWith('.pak')
      ).toList();

      for (final file in disabledFiles) {
        final fileName = path.basename(file.path);
        final existingMod = loadedMods.firstWhere(
          (mod) => mod.name == fileName,
          orElse: () {
            final stat = (file as File).statSync();
            return Mod(
              name: fileName,
              path: file.path,
              fileSize: stat.size,
              isEnabled: false, // Файл в системном temp = выключен
            );
          },
        );
        
        if (!loadedMods.contains(existingMod)) {
          loadedMods.add(existingMod);
        } else {
          // Обновляем путь и состояние существующего мода
          final index = loadedMods.indexWhere((mod) => mod.name == fileName);
          loadedMods[index].path = file.path;
          loadedMods[index].isEnabled = false;
        }
      }
    }

    await saveMods(loadedMods); // Сохраняем обновленный список
    return loadedMods;
  }

  Future<void> saveMods(List<Mod> mods) async {
    try {
      final String modsJson = json.encode(mods.map((mod) => mod.toJson()).toList());
      await _prefs.setString(_modsKey, modsJson);
    } catch (e) {
      print('Ошибка при сохранении модов: $e');
      rethrow;
    }
  }

  Future<String> exportMods(List<Mod> mods, String exportPath) async {
    final archive = Archive();
    final enabledMods = mods.where((mod) => mod.isEnabled).toList();
    
    // Сохраняем метаданные модов
    final modsMetadata = enabledMods.map((mod) => mod.toJson()).toList();
    final metadataBytes = utf8.encode(json.encode(modsMetadata));
    archive.addFile(ArchiveFile('metadata.json', metadataBytes.length, metadataBytes));

    // Копируем файлы модов
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

    // Создаем архив
    final outputPath = path.join(exportPath, 'mods_export.mrmm');
    final encoder = ZipEncoder();
    final bytes = encoder.encode(archive);
    if (bytes != null) {
      await File(outputPath).writeAsBytes(bytes);
    }
    
    return outputPath;
  }

  Future<List<Mod>> importMods(String archivePath, String modsDirectory) async {
    final bytes = await File(archivePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final importedMods = <Mod>[];

    // Читаем метаданные
    final metadataFile = archive.findFile('metadata.json');
    if (metadataFile != null) {
      final metadataJson = utf8.decode(metadataFile.content);
      final List<dynamic> modsMetadata = json.decode(metadataJson);

      // Извлекаем моды
      for (final modData in modsMetadata) {
        final modName = path.basename(modData['path']);
        final modFile = archive.findFile(modName);
        
        if (modFile != null) {
          final targetPath = path.join(modsDirectory, modName);
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
        }
      }
    }

    return importedMods;
  }
} 