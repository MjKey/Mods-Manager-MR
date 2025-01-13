import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/mod.dart';
import '../services/platform_service.dart';
import '../services/quickbms_service.dart';
import '../services/mod_manager_service.dart';
import '../services/game_paths_service.dart';
import '../services/character_service.dart';
import 'package:path/path.dart' as path;
import '../services/settings_service.dart';
import '../services/nexus_mods_service.dart';
import '../services/localization_service.dart';
import 'package:archive/archive.dart';

class ModsProvider with ChangeNotifier {
  final List<Mod> _mods = [];
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  final LocalizationService _localization;

  List<Mod> get mods => _mods;
  List<Mod> get enabledMods => _mods.where((mod) => mod.isEnabled).toList();
  List<Mod> get disabledMods => _mods.where((mod) => !mod.isEnabled).toList();

  ModsProvider() : _localization = LocalizationService() {
    loadMods();
  }

  Future<void> loadMods() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final unpackedModsDir = Directory(QuickBMSService.unpackedModsPath);
      if (!await unpackedModsDir.exists()) {
        await unpackedModsDir.create(recursive: true);
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Загружаем сохраненное состояние
      final savedState = await SettingsService.loadModsState();
      final List<Mod> loadedMods = [];

      await for (final entry in unpackedModsDir.list()) {
        if (entry is Directory) {
          final modName = path.basename(entry.path);
          final character = await CharacterService.detectCharacterFromModPath(entry.path);
          
          // Получаем сохраненное состояние для этого мода
          final savedModState = savedState[modName] as Map<String, dynamic>?;
          
          final mod = Mod(
            name: modName,
            description: savedModState?['description'] as String? ?? _localization.translate('mods.default.description'),
            pakPath: '',
            unpackedPath: entry.path,
            installDate: savedModState?['installDate'] != null 
                ? DateTime.parse(savedModState!['installDate'] as String)
                : (await entry.stat()).modified,
            version: savedModState?['version'] as String? ?? '1.0',
            character: character,
            isEnabled: savedModState?['isEnabled'] as bool? ?? false,
            nexusUrl: savedModState?['nexusUrl'] as String?,
            nexusImageUrl: savedModState?['nexusImageUrl'] as String?,
            lastUpdateCheck: savedModState?['lastUpdateCheck'] != null 
                ? DateTime.parse(savedModState!['lastUpdateCheck'] as String)
                : null,
            tags: (savedModState?['tags'] as List<dynamic>?)?.cast<String>() ?? [],
          );

          loadedMods.add(mod);
        }
      }

      _mods.clear();
      _mods.addAll(loadedMods);
      
      notifyListeners();
    } catch (e) {
      debugPrint(_localization.translate('mods.errors.load', {'error': e.toString()}));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMod(String filePath) async {
    try {
      final extension = path.extension(filePath).toLowerCase();
      String pakFilePath = filePath;
      bool needCleanup = false;

      // Если это ZIP архив, распаковываем его
      if (extension == '.zip') {
        final bytes = await File(filePath).readAsBytes();
        
        // Проверяем, что файл - действительно ZIP архив
        if (bytes.length < 4 || 
            bytes[0] != 0x50 || // P
            bytes[1] != 0x4B || // K
            bytes[2] != 0x03 || // \x03
            bytes[3] != 0x04) { // \x04
          throw FormatException(_localization.translate('mods.errors.not_zip'));
        }

        try {
          final archive = ZipDecoder().decodeBytes(bytes);
          final tempDir = await Directory(path.join(QuickBMSService.unpackedModsPath, 'temp_${DateTime.now().millisecondsSinceEpoch}')).create();
          needCleanup = true;

          // Ищем .pak файл или папку Marvel
          bool foundPakOrMarvel = false;
          for (final file in archive) {
            final filename = file.name.toLowerCase();
            if (file.isFile) {
              final data = file.content as List<int>;
              final outFile = File(path.join(tempDir.path, filename));
              await outFile.create(recursive: true);
              await outFile.writeAsBytes(data);

              if (filename.endsWith('.pak')) {
                pakFilePath = outFile.path;
                foundPakOrMarvel = true;
                break;
              }
            } else if (filename.contains('marvel')) {
              // Если нашли папку Marvel, значит это уже распакованный мод
              foundPakOrMarvel = true;
              final modName = path.basenameWithoutExtension(filePath);
              final targetDir = Directory(path.join(QuickBMSService.unpackedModsPath, modName));
              await targetDir.create(recursive: true);

              // Копируем содержимое в целевую директорию
              for (final f in archive) {
                if (f.isFile) {
                  final data = f.content as List<int>;
                  final outFile = File(path.join(targetDir.path, f.name));
                  await outFile.create(recursive: true);
                  await outFile.writeAsBytes(data);
                }
              }

              // Создаем мод без распаковки
              final mod = Mod(
                name: modName,
                description: _localization.translate('mods.default.description'),
                pakPath: '',  // Пустой путь, так как .pak файла нет
                unpackedPath: targetDir.path,
                installDate: DateTime.now(),
                version: '1.0',
                character: await CharacterService.detectCharacterFromModPath(targetDir.path),
                isEnabled: false,
              );

              _mods.add(mod);
              notifyListeners();
              return;
            }
          }

          if (!foundPakOrMarvel) {
            throw FormatException(_localization.translate('mods.errors.no_pak_or_marvel'));
          }
        } catch (e) {
          if (e is FormatException) rethrow;
          throw FormatException(_localization.translate('mods.errors.unpack_failed', {'error': e.toString()}));
        }
      }

      final fileName = path.basenameWithoutExtension(filePath);
      final unpackedPath = path.join(QuickBMSService.unpackedModsPath, fileName);

      // Проверяем, не существует ли уже мод с таким именем
      if (_mods.any((mod) => mod.name == fileName)) {
        throw Exception(_localization.translate('mods.errors.name_exists'));
      }
      
      // Распаковываем мод
      await QuickBMSService.unpackMod(pakFilePath);
      
      // Определяем персонажа
      final character = await CharacterService.detectCharacterFromModPath(unpackedPath);
      
      final mod = Mod(
        name: fileName,
        description: _localization.translate('mods.default.description'),
        pakPath: pakFilePath,
        unpackedPath: unpackedPath,
        installDate: DateTime.now(),
        version: '1.0',
        character: character,
        isEnabled: false,
      );

      _mods.add(mod);
      debugPrint(_localization.translate('mods.logs.add', {
        'name': mod.name,
        'character': mod.character ?? 'unknown',
        'enabled': mod.isEnabled.toString()
      }));

      // Очищаем временные файлы, если это был ZIP архив
      if (needCleanup) {
        final tempDir = Directory(path.dirname(pakFilePath));
        await tempDir.delete(recursive: true);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка при добавлении мода: $e');
      rethrow;
    }
  }

  Future<void> renameMod(Mod mod, String newName) async {
    try {
      final index = _mods.indexOf(mod);
      if (index == -1) return;

      // Проверяем, не существует ли уже мод с таким именем
      if (_mods.any((m) => m.name == newName && m != mod)) {
        throw Exception(_localization.translate('mods.errors.name_exists'));
      }

      final oldDir = Directory(mod.unpackedPath);
      final newPath = path.join(path.dirname(mod.unpackedPath), newName);
      
      // Переименовываем директорию
      await oldDir.rename(newPath);

      // Обновляем мод в списке
      _mods[index] = mod.copyWith(
        name: newName,
        unpackedPath: newPath,
      );
      
      // Сохраняем состояние после изменения
      await SettingsService.saveModsState(_mods);
      notifyListeners();
      debugPrint(_localization.translate('mods.logs.rename', {
        'oldName': mod.name,
        'newName': newName
      }));
    } catch (e) {
      throw Exception(_localization.translate('mods.errors.rename', {'error': e.toString()}));
    }
  }

  Future<void> toggleMod(Mod mod) async {
    try {
      final index = _mods.indexOf(mod);
      if (index != -1) {
        final gamePath = await GamePathsService.getGamePath();
        if (gamePath == null) {
          throw Exception(_localization.translate('mods.errors.game_path_not_found'));
        }

        if (mod.isEnabled) {
          await ModManagerService.disableMod(mod.unpackedPath, gamePath);
        } else {
          // Получаем список файлов, которые будут заменены
          final affectedFiles = await ModManagerService.getAffectedFiles(mod.unpackedPath, gamePath);
          
          // Проверяем конфликты с другими включенными модами
          for (final otherMod in _mods) {
            if (otherMod != mod && otherMod.isEnabled) {
              final otherAffectedFiles = await ModManagerService.getAffectedFiles(otherMod.unpackedPath, gamePath);
              final conflicts = affectedFiles.toSet().intersection(otherAffectedFiles.toSet());
              
              if (conflicts.isNotEmpty) {
                throw Exception(_localization.translate('mods.errors.mod_conflict', {
                  'modName': otherMod.name,
                  'files': conflicts.join("\n")
                }));
              }
            }
          }

          await ModManagerService.enableMod(mod.unpackedPath, gamePath);
        }

        _mods[index] = mod.copyWith(isEnabled: !mod.isEnabled);
        // Сохраняем состояние после изменения
        await SettingsService.saveModsState(_mods);
        notifyListeners();
        debugPrint(_localization.translate('mods.logs.toggle', {
          'name': mod.name,
          'enabled': (!mod.isEnabled).toString()
        }));
      }
    } catch (e) {
      throw Exception(_localization.translate('mods.errors.toggle', {'error': e.toString()}));
    }
  }

  Future<void> removeMod(Mod mod) async {
    try {
      if (mod.isEnabled) {
        await PlatformService.disableMod(mod.unpackedPath);
      }
      _mods.remove(mod);
      // Сохраняем состояние после удаления
      await SettingsService.saveModsState(_mods);
      notifyListeners();
    } catch (e) {
      throw Exception(_localization.translate('mods.errors.remove', {'error': e.toString()}));
    }
  }

  List<Mod> getEnabledMods({String? searchQuery}) {
    final enabled = _mods.where((mod) => mod.isEnabled);
    if (searchQuery == null || searchQuery.isEmpty) {
      return enabled.toList();
    }
    return enabled
        .where((mod) => 
            mod.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            (mod.character?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false))
        .toList();
  }

  List<Mod> getDisabledMods({String? searchQuery}) {
    final disabled = _mods.where((mod) => !mod.isEnabled);
    if (searchQuery == null || searchQuery.isEmpty) {
      return disabled.toList();
    }
    return disabled
        .where((mod) => 
            mod.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            (mod.character?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false))
        .toList();
  }

  List<Mod> getModsByCharacter(String character, {bool? enabled}) {
    return _mods.where((mod) => 
      mod.character == character && 
      (enabled == null || mod.isEnabled == enabled)
    ).toList();
  }

  List<String> getUniqueCharacters() {
    return _mods
        .where((mod) => mod.character != null)
        .map((mod) => mod.character!)
        .toSet()
        .toList();
  }

  Future<void> addTag(Mod mod, String tag) async {
    try {
      final index = _mods.indexOf(mod);
      if (index == -1) return;

      // Проверяем, не существует ли уже такой тег
      if (mod.tags.contains(tag)) {
        throw Exception(_localization.translate('mods.errors.tag_exists'));
      }

      // Создаем новый список тегов с добавленным тегом
      final newTags = List<String>.from(mod.tags)..add(tag);

      // Обновляем мод
      _mods[index] = mod.copyWith(tags: newTags);
      
      // Сохраняем состояние
      await SettingsService.saveModsState(_mods);
      notifyListeners();
      debugPrint(_localization.translate('mods.logs.tag_add', {
        'tag': tag,
        'name': mod.name
      }));
    } catch (e) {
      throw Exception(_localization.translate('mods.errors.add_tag', {'error': e.toString()}));
    }
  }

  Future<void> removeTag(Mod mod, String tag) async {
    try {
      final index = _mods.indexOf(mod);
      if (index == -1) return;

      // Создаем новый список тегов без удаляемого тега
      final newTags = List<String>.from(mod.tags)..remove(tag);

      // Обновляем мод
      _mods[index] = mod.copyWith(tags: newTags);
      
      // Сохраняем состояние
      await SettingsService.saveModsState(_mods);
      notifyListeners();
      debugPrint(_localization.translate('mods.logs.tag_remove', {
        'tag': tag,
        'name': mod.name
      }));
    } catch (e) {
      throw Exception(_localization.translate('mods.errors.remove_tag', {'error': e.toString()}));
    }
  }

  Future<void> updateModFromNexus(Mod mod, String newUrl) async {
    try {
      debugPrint(_localization.translate('mods.logs.nexus_update.start'));
      debugPrint(_localization.translate('mods.logs.nexus_update.mod_info', {'name': mod.name}));
      debugPrint(_localization.translate('mods.logs.nexus_update.new_url', {'url': newUrl}));
      
      final index = _mods.indexWhere((m) => m.name == mod.name);
      debugPrint(_localization.translate('mods.logs.nexus_update.mod_index', {'index': index.toString()}));
      if (index == -1) {
        debugPrint(_localization.translate('mods.logs.nexus_update.not_found'));
        return;
      }

      debugPrint(_localization.translate('mods.logs.nexus_update.getting_info'));
      final modInfo = await NexusModsService.getModInfo(newUrl);
      debugPrint(_localization.translate('mods.logs.nexus_update.received_info', {'info': modInfo.toString()}));
      
      _mods[index] = _mods[index].copyWith(
        version: modInfo['version'] ?? '',
        nexusImageUrl: modInfo['picture_url'],
        nexusUrl: newUrl,
        lastUpdateCheck: DateTime.now(),
      );
      
      debugPrint(_localization.translate('mods.logs.nexus_update.updated_info'));
      debugPrint(_localization.translate('mods.logs.nexus_update.version', {'version': _mods[index].version}));
      debugPrint(_localization.translate('mods.logs.nexus_update.picture_url', {'url': _mods[index].nexusImageUrl ?? 'null'}));
      debugPrint(_localization.translate('mods.logs.nexus_update.nexus_url', {'url': _mods[index].nexusUrl ?? 'null'}));
      
      await SettingsService.saveModsState(_mods);
      notifyListeners();
      debugPrint(_localization.translate('mods.logs.nexus_update.success'));
    } catch (e, stackTrace) {
      debugPrint('Stack trace: $stackTrace');
      throw Exception(_localization.translate('mods.errors.nexus_update', {'error': e.toString()}));
    }
  }

  Future<bool> checkModUpdate(Mod mod) async {
    if (mod.nexusUrl == null) return false;

    final modInfo = await NexusModsService.getModInfo(mod.nexusUrl!);
    final lastUpdate = DateTime.fromMillisecondsSinceEpoch(modInfo['updated_timestamp'] * 1000);
    
    return mod.lastUpdateCheck != null && lastUpdate.isAfter(mod.lastUpdateCheck!);
  }
} 