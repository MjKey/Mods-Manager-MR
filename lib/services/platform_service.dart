import 'dart:io';
import 'package:path/path.dart' as path;
import 'game_paths_service.dart';
import 'mod_manager_service.dart';
import '../services/localization_service.dart';

class PlatformService {
  static final LocalizationService _localization = LocalizationService();
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;

  static Future<String> getModsDirectory() async {
    if (isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData == null) {
        throw Exception(_localization.translate('platform.errors.localappdata_not_found'));
      }
      return path.join(localAppData, 'MarvelRivalsModsManager');
    } else if (isLinux) {
      final home = Platform.environment['HOME'];
      if (home == null) {
        throw Exception(_localization.translate('platform.errors.home_not_found'));
      }
      return path.join(home, '.local', 'share', 'MarvelRivalsModsManager');
    } else {
      throw Exception(_localization.translate('platform.errors.unsupported_os'));
    }
  }

  static Future<void> installMod(String modPath, String gamePath) async {
    if (!await Directory(modPath).exists()) {
      throw Exception(_localization.translate('platform.errors.mod_path_not_exists', {'path': modPath}));
    }

    if (!await Directory(gamePath).exists()) {
      throw Exception(_localization.translate('platform.errors.game_path_not_exists', {'path': gamePath}));
    }

    try {
      final modDir = Directory(modPath);
      await for (final entity in modDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: modPath);
          final targetPath = path.join(gamePath, relativePath);
          
          await Directory(path.dirname(targetPath)).create(recursive: true);
          await entity.copy(targetPath);
        }
      }
    } catch (e) {
      throw Exception(_localization.translate('platform.errors.install_failed', {'error': e.toString()}));
    }
  }

  static Future<void> enableMod(String modPath) async {
    final gamePath = await GamePathsService.getGamePath();
    if (gamePath == null) {
      throw Exception(_localization.translate('platform.errors.game_path_not_found'));
    }
    await installMod(modPath, gamePath);
  }

  static Future<void> disableMod(String modPath) async {
    // Восстанавливаем файлы из бэкапа
    final gamePath = await GamePathsService.getGamePath();
    if (gamePath == null) {
      throw Exception(_localization.translate('platform.errors.game_path_not_found'));
    }
    await ModManagerService.disableMod(modPath, gamePath);
  }
} 