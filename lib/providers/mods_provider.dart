import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/mod.dart';
import '../services/mod_manager_service.dart';
import '../services/game_paths_service.dart';
import '../services/character_service.dart';
import 'package:path/path.dart' as path;
import '../services/settings_service.dart';
import '../services/nexus_mods_service.dart';
import '../services/localization_service.dart';
import '../services/archive_service.dart';

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
      
      final gamePath = await GamePathsService.getGamePath();
      if (gamePath == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final modsDir = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods');
      if (!await Directory(modsDir).exists()) {
        await Directory(modsDir).create(recursive: true);
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Загружаем сохраненное состояние
      final savedState = await SettingsService.loadModsState();
      final List<Mod> loadedMods = [];

      await for (final entry in Directory(modsDir).list()) {
        if (entry is File && entry.path.toLowerCase().endsWith('.pak')) {
          final modName = path.basenameWithoutExtension(entry.path);
          final character = await CharacterService.detectCharacterFromModPath(entry.path);
          
          // Получаем сохраненное состояние для этого мода
          final savedModState = savedState[modName] as Map<String, dynamic>?;
          
          final mod = Mod(
            name: modName,
            description: savedModState?['description'] as String? ?? _localization.translate('mods.default.description'),
            pakPath: entry.path,
            unpackedPath: entry.path,
            installDate: savedModState?['installDate'] != null 
                ? DateTime.parse(savedModState!['installDate'] as String)
                : (await entry.stat()).modified,
            version: savedModState?['version'] as String? ?? '1.0',
            character: character,
            isEnabled: true, // В папке ~mods все моды считаются включенными
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

      // Загружаем отключенные моды из папки для отключенных модов
      final disabledModsDir = await SettingsService.getModsPath();
      await for (final entry in Directory(disabledModsDir).list()) {
        if (entry is File && entry.path.toLowerCase().endsWith('.pak')) {
          final modName = path.basenameWithoutExtension(entry.path);
          final character = await CharacterService.detectCharacterFromModPath(entry.path);
          
          // Получаем сохраненное состояние для этого мода
          final savedModState = savedState[modName] as Map<String, dynamic>?;
          
          final mod = Mod(
            name: modName,
            description: savedModState?['description'] as String? ?? _localization.translate('mods.default.description'),
            pakPath: entry.path,
            unpackedPath: entry.path,
            installDate: savedModState?['installDate'] != null 
                ? DateTime.parse(savedModState!['installDate'] as String)
                : (await entry.stat()).modified,
            version: savedModState?['version'] as String? ?? '1.0',
            character: character,
            isEnabled: false, // Моды в папке отключенных модов считаются выключенными
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

  Future<bool> addMod(String filePath) async {
    try {
      String? pakPath = filePath;
      final extension = path.extension(filePath).toLowerCase();
      
      // Если это архив, извлекаем из него .pak файл
      if (extension == '.zip') {
        pakPath = await ArchiveService.extractPakFromArchive(filePath);
        if (pakPath == null) {
          return false;
        }
      }
      
      // Проверяем, что это .pak файл
      if (path.extension(pakPath).toLowerCase() != '.pak') {
        return false;
      }

      final gamePath = await GamePathsService.getGamePath();
      if (gamePath == null) return false;

      final modsDir = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods');
      if (!await Directory(modsDir).exists()) {
        await Directory(modsDir).create(recursive: true);
      }

      final modName = path.basenameWithoutExtension(pakPath);
      final destPath = path.join(modsDir, '$modName.pak');

      // Проверяем, существует ли уже мод с таким именем
      final existingMod = _mods.firstWhere(
        (mod) => mod.name == modName,
        orElse: () => Mod(
          name: '',
          pakPath: '',
          installDate: DateTime.now(),
          isEnabled: false,
        ),
      );

      if (existingMod.name.isNotEmpty) {
        // Показываем диалог подтверждения обновления
        final context = GamePathsService.navigatorKey.currentContext;
        if (context == null) return false;

        final shouldUpdate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_localization.translate('mods.dialogs.duplicate.title')),
            content: Text(_localization.translate('mods.dialogs.duplicate.message', {'name': modName})),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_localization.translate('mods.dialogs.duplicate.cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_localization.translate('mods.dialogs.duplicate.update')),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
            ],
          ),
        );

        if (shouldUpdate != true) {
          // Если это был временный файл из архива, удаляем его
          if (pakPath != filePath) {
            await ArchiveService.cleanupTempFiles(pakPath);
          }
          return false;
        }

        // Удаляем старый мод перед обновлением
        await removeMod(existingMod);
      }

      // Копируем мод в папку ~mods
      await File(pakPath).copy(destPath);

      // Если это был временный файл из архива, удаляем его
      if (pakPath != filePath) {
        await ArchiveService.cleanupTempFiles(pakPath);
      }

      // Получаем сохраненное состояние
      final savedState = await SettingsService.loadModsState();
      final savedModState = savedState[modName] as Map<String, dynamic>?;

      // Определяем персонажа
      final character = await CharacterService.detectCharacterFromModPath(destPath);

      // Добавляем мод в список
      final mod = Mod(
        name: modName,
        description: savedModState?['description'] as String? ?? _localization.translate('mods.default.description'),
        pakPath: destPath,
        unpackedPath: destPath,
        installDate: DateTime.now(),
        version: savedModState?['version'] as String? ?? '1.0',
        character: character,
        isEnabled: true,
        tags: (savedModState?['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      );

      _mods.add(mod);
      await SettingsService.saveModsState(_mods);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Ошибка при добавлении мода: $e');
      return false;
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

      // Обновляем мод в списке
      _mods[index] = mod.copyWith(name: newName);
      
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
          // Отключаем мод
          debugPrint('Отключаем мод: ${mod.name}');
          
          // Получаем путь к папке отключенных модов
          final disabledModsPath = await SettingsService.getModsPath();
          debugPrint('Путь к папке отключенных модов: $disabledModsPath');
          
          // Проверяем существование директории
          final disabledModsDir = Directory(disabledModsPath);
          if (!await disabledModsDir.exists()) {
            debugPrint('Создаем папку для отключенных модов');
            await disabledModsDir.create(recursive: true);
          }

          final fileName = path.basename(mod.pakPath);
          final newPath = path.join(disabledModsPath, fileName);
          debugPrint('Новый путь для мода: $newPath');
          
          // Проверяем существование исходного файла
          final sourceFile = File(mod.pakPath);
          if (await sourceFile.exists()) {
            debugPrint('Копируем файл мода в папку отключенных модов');
            await sourceFile.copy(newPath);
            debugPrint('Удаляем оригинальный файл');
            await sourceFile.delete();
            
            // Проверяем, что файл скопировался
            final newFile = File(newPath);
            if (!await newFile.exists()) {
              throw Exception('Файл не был скопирован в папку отключенных модов');
            }
          } else {
            throw Exception('Исходный файл мода не найден: ${mod.pakPath}');
          }

          // Отключаем мод в системе
          await ModManagerService.disableMod(mod.pakPath, gamePath);

          _mods[index] = mod.copyWith(
            isEnabled: false,
            pakPath: newPath
          );
          
          debugPrint('Мод успешно отключен и перемещен');
        } else {
          // Получаем список файлов, которые будут заменены
          final affectedFiles = await ModManagerService.getAffectedFiles(mod.pakPath, gamePath);
          
          // Проверяем конфликты с другими включенными модами
          for (final otherMod in _mods) {
            if (otherMod != mod && otherMod.isEnabled) {
              final otherAffectedFiles = await ModManagerService.getAffectedFiles(otherMod.pakPath, gamePath);
              final conflicts = affectedFiles.toSet().intersection(otherAffectedFiles.toSet());
              
              if (conflicts.isNotEmpty) {
                throw Exception(_localization.translate('mods.errors.mod_conflict', {
                  'modName': otherMod.name,
                  'files': conflicts.join("\n")
                }));
              }
            }
          }

          // Включаем мод
          await ModManagerService.enableMod(mod.pakPath, gamePath);
          
          // Перемещаем файл в папку ~mods
          final modsDir = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods');
          final fileName = path.basename(mod.pakPath);
          final newPath = path.join(modsDir, fileName);
          
          final sourceFile = File(mod.pakPath);
          if (await sourceFile.exists()) {
            await sourceFile.copy(newPath);
            await sourceFile.delete();
          }

          _mods[index] = mod.copyWith(
            isEnabled: true,
            pakPath: newPath
          );
          
          debugPrint('Мод успешно включен и перемещен');
        }

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
      debugPrint(_localization.translate('delete_logs.start', {'name': mod.name}));
      
      // Если мод включен, сначала отключаем его
      if (mod.isEnabled) {
        debugPrint(_localization.translate('delete_logs.removing_files'));
        final gamePath = await GamePathsService.getGamePath();
        if (gamePath != null) {
          await ModManagerService.disableMod(mod.pakPath, gamePath);
        }
      }

      // Удаляем файл мода
      final modFile = File(mod.pakPath);
      if (await modFile.exists()) {
        await modFile.delete();
      }

      // Удаляем из списка модов
      _mods.remove(mod);
      
      // Сохраняем состояние после удаления
      await SettingsService.saveModsState(_mods);
      
      debugPrint(_localization.translate('delete_logs.success', {'name': mod.name}));
      notifyListeners();
    } catch (e) {
      throw Exception(_localization.translate('delete_errors.failed', {'error': e.toString()}));
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