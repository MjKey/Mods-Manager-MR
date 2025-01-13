import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import '../services/settings_service.dart';
import '../services/localization_service.dart';
import '../services/quickbms_service.dart';
import '../services/repak_service.dart';

class ModManagerService {
  static final LocalizationService _localization = LocalizationService();
  static Future<String> get _backupPath => SettingsService.getBackupPath();

  // Получаем хеш файла для создания уникального бэкапа
  static Future<String> _getFileHash(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return '';
    final bytes = await file.readAsBytes();
    return md5.convert(bytes).toString();
  }

  // Создаем бэкап файла перед заменой
  static Future<void> _backupFile(String filePath, String modName) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final hash = await _getFileHash(filePath);
    final fileName = path.basename(filePath);
    
    // Получаем путь к директории Marvel в игре
    final gameMarvelDir = path.dirname(path.dirname(filePath)); // Поднимаемся на 2 уровня вверх до Marvel
    
    // Получаем относительный путь от директории Marvel
    final relativePath = path.relative(filePath, from: gameMarvelDir);
    
    print(_localization.translate('mod_manager.logs.backup_create', {'path': filePath}));
    print(_localization.translate('mod_manager.logs.relative_path', {'path': relativePath}));
    
    final backupDir = path.join(await _backupPath, modName, hash);
    
    await Directory(backupDir).create(recursive: true);
    await file.copy(path.join(backupDir, fileName));
    
    final infoFile = File(path.join(backupDir, 'path.txt'));
    await infoFile.writeAsString(relativePath);
    
    print(_localization.translate('mod_manager.logs.backup_created', {'path': backupDir}));
    print(_localization.translate('mod_manager.logs.relative_path_saved', {'path': relativePath}));
  }

  // Восстанавливаем файл из бэкапа
  static Future<void> _restoreFile(String filePath, String modName) async {
    final backupDir = path.join(await _backupPath, modName);
    if (!await Directory(backupDir).exists()) return;

    print(_localization.translate('mod_manager.logs.backup_search', {'path': filePath}));
    print(_localization.translate('mod_manager.logs.mod_backup_dir', {'path': backupDir}));

    // Получаем путь к директории Marvel в игре (поднимаемся на 2 уровня вверх)
    final gameMarvelDir = path.dirname(path.dirname(filePath));
    
    // Получаем относительный путь от директории Marvel
    final targetRelativePath = path.relative(filePath, from: gameMarvelDir);
    print(_localization.translate('mod_manager.logs.file_relative_path', {'path': targetRelativePath}));

    // Получаем все директории бэкапов для этого мода
    final backupDirs = await Directory(backupDir)
      .list()
      .where((entity) => entity is Directory)
      .cast<Directory>()
      .toList();

    if (backupDirs.isEmpty) {
      print(_localization.translate('mod_manager.logs.backup_not_found', {'name': modName}));
      
      // Удаляем файл, если он существует и для него нет бэкапа
      final file = File(filePath);
      if (await file.exists()) {
        print(_localization.translate('mod_manager.logs.removing_mod_file', {'path': filePath}));
        await file.delete();
      }
      return;
    }

    final fileName = path.basename(filePath);
    
    // Проходим по всем директориям бэкапов
    for (final backupDir in backupDirs) {
      final backupFile = File(path.join(backupDir.path, fileName));
      final pathFile = File(path.join(backupDir.path, 'path.txt'));
      
      if (await backupFile.exists() && await pathFile.exists()) {
        // Читаем сохраненный относительный путь
        final savedRelativePath = (await pathFile.readAsString()).trim();
        print(_localization.translate('mod_manager.logs.comparing_paths'));
        print(_localization.translate('mod_manager.logs.saved_path', {'path': savedRelativePath}));
        print(_localization.translate('mod_manager.logs.target_path', {'path': targetRelativePath}));
        
        // Проверяем, совпадает ли относительный путь
        if (savedRelativePath == targetRelativePath) {
          print(_localization.translate('mod_manager.logs.backup_found', {'path': backupFile.path}));
          print(_localization.translate('mod_manager.logs.restoring_file', {'path': filePath}));
          
          // Создаем директорию если её нет
          final targetDir = Directory(path.dirname(filePath));
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }
          
          await backupFile.copy(filePath);
          print(_localization.translate('mod_manager.logs.file_restored', {'path': backupFile.path}));
          return;
        } else {
          print(_localization.translate('mod_manager.logs.paths_mismatch'));
        }
      }
    }
    
    print(_localization.translate('mod_manager.logs.no_backup_found', {'path': filePath}));
    // Удаляем файл, если он существует и для него не найден подходящий бэкап
    final file = File(filePath);
    if (await file.exists()) {
      print(_localization.translate('mod_manager.logs.removing_mod_file', {'path': filePath}));
      await file.delete();
    }
  }

  // Определяем метод распаковки в зависимости от типа файла
  static Future<void> unpackFile(String pakFilePath, {String? outputPath}) async {
    final fileName = path.basename(pakFilePath).toLowerCase();
    final isGameSystemPak = fileName == 'pakchunkcharacter-windows.pak' || 
                           fileName == 'pakchunkwwise-windows.pak';
    
    print('Распаковка файла: $pakFilePath');
    print('Метод распаковки: ${isGameSystemPak ? 'QuickBMS' : 'Repak'}');
    
    if (isGameSystemPak) {
      // Для системных файлов игры используем QuickBMS
      await QuickBMSService.unpackMod(pakFilePath, outputPath: outputPath);
    } else {
      // Для ВСЕХ остальных .pak файлов (включая моды) используем repak
      final finalOutputPath = outputPath ?? path.join(
        path.dirname(pakFilePath),
        path.basenameWithoutExtension(pakFilePath)
      );
      await RepakService.unpackMod(pakFilePath, outputPath: finalOutputPath);
    }
  }

  // Включаем мод с учетом разных методов распаковки
  static Future<void> enableMod(String modPath, String gamePath) async {
    final modName = path.basename(modPath);
    final marvelDir = path.join(modPath, 'Marvel');
    
    if (!await Directory(marvelDir).exists()) {
      throw Exception(_localization.translate('mod_manager.errors.invalid_mod_structure'));
    }

    final gameMarvelDir = path.join(gamePath, 'MarvelGame', 'Marvel');
    
    // Рекурсивно обходим все файлы в моде
    await for (final entity in Directory(marvelDir).list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: marvelDir);
        final targetPath = path.join(gameMarvelDir, relativePath);
        
        // Если это .pak файл, используем соответствующий метод распаковки
        if (path.extension(entity.path).toLowerCase() == '.pak') {
          print('Обнаружен .pak файл в моде: ${entity.path}');
          
          // Создаем директории если нужно
          final targetDir = Directory(path.dirname(targetPath));
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }
          
          // Сначала копируем .pak файл
          await entity.copy(targetPath);
          print('Скопирован .pak файл: $targetPath');
          
          // Затем распаковываем его через repak (т.к. это файл мода)
          final outputPath = path.join(
            path.dirname(targetPath),
            path.basenameWithoutExtension(targetPath)
          );
          await RepakService.unpackMod(targetPath, outputPath: outputPath);
          
          // После успешной распаковки удаляем .pak файл
          await File(targetPath).delete();
          print('Удален временный .pak файл после распаковки: $targetPath');
        } else {
          // Для не-.pak файлов создаем бэкап если файл существует
          if (await File(targetPath).exists()) {
            try {
              await _backupFile(targetPath, modName);
            } catch (e) {
              throw Exception(_localization.translate('mod_manager.errors.backup_failed', {'error': e.toString()}));
            }
          }

          // Создаем директории если нужно
          await Directory(path.dirname(targetPath)).create(recursive: true);
          
          // Копируем обычный файл
          await entity.copy(targetPath);
        }
      }
    }
  }

  // Отключаем мод
  static Future<void> disableMod(String modPath, String gamePath) async {
    final modName = path.basename(modPath);
    final marvelDir = path.join(modPath, 'Marvel');
    final gameMarvelDir = path.join(gamePath, 'MarvelGame', 'Marvel');

    print('Начинаем отключение мода: $modName');
    // Рекурсивно обходим все файлы в моде
    await for (final entity in Directory(marvelDir).list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: marvelDir);
        final targetPath = path.join(gameMarvelDir, relativePath);
        
        try {
          // Восстанавливаем оригинальный файл из бэкапа
          await _restoreFile(targetPath, modName);
        } catch (e) {
          throw Exception(_localization.translate('mod_manager.errors.restore_failed', {'error': e.toString()}));
        }
      }
    }
    print('Мод успешно отключен: $modName');
  }

  // Проверяем, какие файлы будут заменены модом
  static Future<List<String>> getAffectedFiles(String modPath, String gamePath) async {
    final affectedFiles = <String>[];
    final marvelDir = path.join(modPath, 'Marvel');
    final gameMarvelDir = path.join(gamePath, 'MarvelGame', 'Marvel');

    await for (final entity in Directory(marvelDir).list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: marvelDir);
        final targetPath = path.join(gameMarvelDir, relativePath);
        
        if (await File(targetPath).exists()) {
          affectedFiles.add(relativePath);
        }
      }
    }

    return affectedFiles;
  }

  // Добавляем метод для полного сброса
  static Future<void> resetAllMods(String gamePath) async {
    try {
      print(_localization.translate('mod_manager.logs.reset_start'));
      
      final modsPath = await SettingsService.getModsPath();
      final unpackedModsDir = Directory(modsPath);
      if (await unpackedModsDir.exists()) {
        await for (final entry in unpackedModsDir.list()) {
          if (entry is Directory) {
            final modName = path.basename(entry.path);
            print(_localization.translate('mod_manager.logs.disable_mod', {'name': modName}));
            
            // Восстанавливаем оригинальные файлы
            await disableMod(entry.path, gamePath);
            
            // Удаляем распакованный мод
            await entry.delete(recursive: true);
            print(_localization.translate('mod_manager.logs.mod_removed', {'name': modName}));
          }
        }
        
        // Удаляем директорию с распакованными модами
        await unpackedModsDir.delete(recursive: true);
      }

      // Очищаем бэкапы
      final backupDir = Directory(await _backupPath);
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
        print(_localization.translate('mod_manager.logs.backups_removed'));
      }

      print(_localization.translate('mod_manager.logs.reset_complete'));
    } catch (e) {
      print(_localization.translate('mod_manager.errors.reset_failed', {'error': e.toString()}));
      throw Exception(_localization.translate('mod_manager.errors.reset_failed', {'error': e.toString()}));
    }
  }
} 