import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/localization_service.dart';

class ModManagerService {
  static final LocalizationService _localization = LocalizationService();

  static String generateFileName(String baseFileName, int order) {
    // Гарантируем, что order не меньше 0
    final safeOrder = order.clamp(0, 999);
    final prefix = safeOrder.toString().padLeft(3, '0');
    return '${prefix}_$baseFileName';
  }

  static int? extractOrderFromFileName(String fileName) {
    final match = RegExp(r'^(\d{3})_').firstMatch(fileName);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static String extractBaseFileName(String fileName) {
    return fileName.replaceFirst(RegExp(r'^\d{3}_'), '');
  }

  // Включаем мод
  static Future<void> enableMod(String modPath, String gamePath, int order) async {
    final modsDir = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks', '~mods');
    
    if (!await Directory(modsDir).exists()) {
      await Directory(modsDir).create(recursive: true);
    }
    // problem TODO
    final baseFileName = path.basename(modPath);
    print(baseFileName);
    final newFileName = generateFileName(extractBaseFileName(baseFileName), order);
    final targetPath = path.join(modsDir, newFileName);

    final pakFile = File(modPath);
    if (await pakFile.exists()) {
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