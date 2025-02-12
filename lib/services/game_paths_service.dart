import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'game_finder_service.dart';
import 'cache_service.dart';
import 'localization_service.dart';
import 'patch_manager_service.dart';

class GamePathsService {
  static const String _gamePathKey = 'game_path';
  static SharedPreferences? _prefs;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final LocalizationService _localization = LocalizationService();

  static Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<String?> getGamePath() async {
    try {
      await _initPrefs();
      final savedPath = _prefs!.getString(_gamePathKey);
      
      if (savedPath != null) {
        final paksPath = path.join(savedPath, 'MarvelGame', 'Marvel', 'Content', 'Paks');
        if (await Directory(paksPath).exists()) {
          return savedPath;
        }
      }

      return await GameFinderService.findGameFolder();
    } catch (e) {
      print(_localization.translate('game_paths.errors.get_path', {'error': e.toString()}));
      return null;
    }
  }

  static Future<void> setGamePath(String gamePath) async {
    final paksPath = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks');
    if (!await Directory(paksPath).exists()) {
      throw Exception(_localization.translate('game_paths.errors.invalid_path'));
    }

    // Создаем папку ~mods если её нет
    final modsPath = path.join(paksPath, '~mods');
    if (!await Directory(modsPath).exists()) {
      await Directory(modsPath).create();
    }

    await _initPrefs();
    await _prefs!.setString(_gamePathKey, gamePath);
    await CacheService.cacheGamePath(gamePath);

    // Проверяем и переименовываем патч-файлы после установки пути к игре
    try {
      await PatchManagerService.renamePatchFiles();
    } catch (e) {
      print('Ошибка при проверке патч-файлов: $e');
    }
  }

  static Future<void> checkGamePath() async {
    final gamePath = await getGamePath();
    if (gamePath == null) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(_localization.translate('dialogs.game_path.title')),
            content: Text(_localization.translate('dialogs.game_path.message')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/settings');
                },
                child: Text(_localization.translate('dialogs.game_path.go_to_settings')),
              ),
            ],
          ),
        );
      }
    }
  }
} 