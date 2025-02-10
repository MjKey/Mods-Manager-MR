import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/localization_service.dart';

class ModManagerService {
  static final LocalizationService _localization = LocalizationService();

  // Включаем мод
  static Future<void> enableMod(String modPath, String gamePath) async {
    final modsDir = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods');
    
    // Создаем директорию ~mods если её нет
    final modsDirExists = await Directory(modsDir).exists();
    if (!modsDirExists) {
      await Directory(modsDir).create(recursive: true);
    }

    // Копируем .pak файл в папку ~mods
    final pakFile = File(modPath);
    if (await pakFile.exists()) {
      final targetPath = path.join(modsDir, path.basename(modPath));
      await pakFile.copy(targetPath);
    } else {
      throw Exception(_localization.translate('mods.errors.file_not_found'));
    }
  }

  // Отключаем мод
  static Future<void> disableMod(String modPath, String gamePath) async {
    final modsDir = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods');
    final targetPath = path.join(modsDir, path.basename(modPath));

    // Удаляем .pak файл из папки ~mods
    final modFile = File(targetPath);
    if (await modFile.exists()) {
      await modFile.delete();
    }
  }

  // Проверяем, какие файлы будут заменены модом
  static Future<List<String>> getAffectedFiles(String modPath, String gamePath) async {
    final modsDir = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods');
    final targetPath = path.join(modsDir, path.basename(modPath));
    
    if (await File(targetPath).exists()) {
      return [targetPath];
    }
    return [];
  }

  // Добавляем метод для полного сброса
  static Future<void> resetAllMods(String gamePath) async {
    final modsDir = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods');
    
    try {
      print(_localization.translate('mod_manager.logs.reset_start'));
      
      // Удаляем всю папку ~mods
      final modsDirExists = await Directory(modsDir).exists();
      if (modsDirExists) {
        await Directory(modsDir).delete(recursive: true);
      }

      print(_localization.translate('mod_manager.logs.reset_complete'));
    } catch (e) {
      print(_localization.translate('mod_manager.errors.reset_failed', {'error': e.toString()}));
      throw Exception(_localization.translate('mod_manager.errors.reset_failed', {'error': e.toString()}));
    }
  }
} 