import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../widgets/unpacking_progress_dialog.dart';
import 'game_finder_service.dart';
import 'quickbms_service.dart';
import 'cache_service.dart';
import 'localization_service.dart';

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

    await _initPrefs();
    await _prefs!.setString(_gamePathKey, gamePath);
    await CacheService.cacheGamePath(gamePath);

    // Проверяем наличие файла для распаковки
    final characterPakPath = path.join(paksPath, 'pakchunkCharacter-Windows.pak');
    if (await File(characterPakPath).exists()) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        // Проверяем наличие QuickBMS
        try {
          print(_localization.translate('game_paths.logs.checking_quickbms'));
          await QuickBMSService.checkRequirements();
        } catch (e) {
          print(_localization.translate('game_paths.errors.quickbms_check', {'error': e.toString()}));
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(_localization.translate('dialogs.error.title')),
                content: Text(_localization.translate('dialogs.error.components_not_found', {'error': e.toString()})),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(_localization.translate('game_paths.errors.ok')),
                  ),
                ],
              ),
            );
          }
          return;
        }

        final shouldUnpack = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(_localization.translate('dialogs.unpacking.title')),
            content: Text(_localization.translate('dialogs.unpacking.message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_localization.translate('dialogs.unpacking.cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_localization.translate('dialogs.unpacking.continue')),
              ),
            ],
          ),
        );

        if (shouldUnpack == true) {
          final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text(_localization.translate('dialogs.unpacking.warning.title')),
              content: Text(_localization.translate('dialogs.unpacking.warning.message')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_localization.translate('dialogs.unpacking.warning.cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_localization.translate('dialogs.unpacking.warning.continue')),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            try {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const UnpackingProgressDialog(),
              );

              // Распаковываем файл
              await QuickBMSService.unpackMod(
                characterPakPath,
                moveToBackup: true,
              );
            } catch (e) {
              print(_localization.translate('dialogs.error.unpacking_failed', {'error': e.toString()}));
              if (context.mounted) {
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(_localization.translate('dialogs.error.title')),
                    content: Text(_localization.translate('dialogs.error.unpacking_failed', {'error': e.toString()})),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(_localization.translate('game_paths.errors.ok')),
                      ),
                    ],
                  ),
                );
              }
            }
          }
        }
      }
    }
  }
} 