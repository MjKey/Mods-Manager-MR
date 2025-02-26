import 'dart:io';
import 'package:path/path.dart' as path;
import 'game_paths_service.dart';
import 'localization_service.dart';

class PatchManagerService {
  static final LocalizationService _localization = LocalizationService();

  static Future<void> renamePatchFiles() async {
    try {
      final gamePath = await GamePathsService.getGamePath();
      if (gamePath == null) {
        throw Exception(_localization.translate('game_paths.errors.get_path', {'error': 'Game path not found'}));
      }

      final paksPath = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks');
      final directory = Directory(paksPath);
      
      if (!await directory.exists()) {
        throw Exception(_localization.translate('game_paths.errors.invalid_path'));
      }

      await for (final entity in directory.list()) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          // Ищем файлы по шаблону Patch_-Windows_X.X.XXXXXX_P.pak
          final match = RegExp(r'Patch_-Windows_(\d+\.\d+\.\d+)_P\.pak').firstMatch(fileName);
          
          if (match != null) {
            final version = match.group(1);
            final newFileName = 'Windows_$version.pak';
            final newPath = path.join(paksPath, newFileName);
            
            // Проверяем, существует ли файл с новым именем
            if (!await File(newPath).exists()) {
              await entity.rename(newPath);
              print('Переименован файл: $fileName -> $newFileName');
            }
          }
        }
      }
    } catch (e) {
      print('Ошибка при переименовании патч-файлов: $e');
      rethrow;
    }
  }
} 