import 'dart:io';
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';
import 'cache_service.dart';

class GameFinderService {
  static Future<String?> findGameFolder() async {
    try {
      print('Начинаем поиск игры...');
      
      // Сначала проверяем кэш
      final cachedPath = await CacheService.getCachedGamePath();
      if (cachedPath != null) {
        final paksPath = path.join(cachedPath, 'MarvelGame', 'Marvel', 'Content', 'Paks');
        if (await Directory(paksPath).exists()) {
          print('Игра найдена в кэше: $cachedPath');
          return cachedPath;
        }
      }
      
      final steamPath = await findSteamGamePath();
      if (steamPath != null) {
        await CacheService.cacheGamePath(steamPath);
        return steamPath;
      }

      final epicPath = await findEpicGamePath();
      if (epicPath != null) {
        await CacheService.cacheGamePath(epicPath);
        return epicPath;
      }

      // Если игра не найдена, кэшируем null
      await CacheService.cacheGamePath(null);
      return null;
    } catch (e) {
      print('Ошибка при поиске игры: $e');
      return null;
    }
  }

  static String? findSteamPathFromRegistry() {
    try {
      print('Ищем путь к Steam в реестре...');
      final subKey = 'SOFTWARE\\Valve\\Steam'.toNativeUtf16();
      final phkResult = calloc<HKEY>();
      
      final result = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        subKey,
        0,
        REG_SAM_FLAGS.KEY_READ,
        phkResult,
      );

      if (result == WIN32_ERROR.ERROR_SUCCESS) {
        try {
          final bufferSize = calloc<DWORD>()..value = MAX_PATH;
          final buffer = wsalloc(MAX_PATH);
          final type = calloc<DWORD>();

          final queryResult = RegQueryValueEx(
            phkResult.value,
            'SteamPath'.toNativeUtf16(),
            nullptr,
            type,
            buffer.cast<Uint8>(),
            bufferSize,
          );

          if (queryResult == WIN32_ERROR.ERROR_SUCCESS) {
            final steamPath = buffer.toDartString();
            print('Найден путь к Steam в реестре: $steamPath');
            free(buffer);
            free(bufferSize);
            free(type);
            return steamPath;
          }
          
          free(buffer);
          free(bufferSize);
          free(type);
        } finally {
          RegCloseKey(phkResult.value);
          free(phkResult);
        }
      } else {
        free(phkResult);
      }
      
      free(subKey);
    } catch (e) {
      print('Ошибка при чтении реестра: $e');
    }
    print('Путь к Steam в реестре не найден');
    return null;
  }

  static Future<String?> findSteamGamePath() async {
    final steamLibraries = await findSteamLibraries();
    print('Найдены библиотеки Steam: $steamLibraries');
    
    for (final library in steamLibraries) {
      final gamePath = path.join(
        library,
        'steamapps',
        'common',
        'MarvelRivals',
      );
      print('Проверяем путь: $gamePath');
      
      final paksPath = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks');
      print('Проверяем путь к Paks: $paksPath');
      
      if (await Directory(paksPath).exists()) {
        print('Найдена игра в Steam: $gamePath');
        return gamePath;
      }
    }
    return null;
  }

  static Future<List<String>> findSteamLibraries() async {
    final libraries = <String>[];
    
    // Сначала пытаемся найти Steam через реестр
    final steamPath = findSteamPathFromRegistry();
    if (steamPath != null) {
      libraries.add(steamPath);
      
      final vdfPath = path.join(
        steamPath,
        'steamapps',
        'libraryfolders.vdf',
      );
      print('Проверяем файл библиотек Steam: $vdfPath');

      if (await File(vdfPath).exists()) {
        try {
          final content = await File(vdfPath).readAsString();
          print('Содержимое libraryfolders.vdf: $content');
          final pathRegex = RegExp(r'"path"\s+"(.+)"');
          final matches = pathRegex.allMatches(content);

          for (final match in matches) {
            if (match.groupCount >= 1) {
              final libraryPath = match.group(1)?.replaceAll(r'\\', r'\');
              if (libraryPath != null) {
                print('Найдена дополнительная библиотека Steam: $libraryPath');
                libraries.add(libraryPath);
              }
            }
          }
        } catch (e) {
          print('Ошибка при чтении Steam библиотек: $e');
        }
      }
    }

    // Также проверяем стандартный путь установки
    final programFiles = Platform.environment['ProgramFiles(x86)'];
    if (programFiles != null) {
      final defaultSteamPath = path.join(programFiles, 'Steam');
      if (!libraries.contains(defaultSteamPath)) {
        libraries.add(defaultSteamPath);
      }
    }

    return libraries;
  }

  static Future<String?> findEpicGamePath() async {
    final programData = Platform.environment['ProgramData'];
    if (programData == null) return null;

    final manifestPath = path.join(
      programData,
      'Epic',
      'EpicGamesLauncher',
      'Data',
      'Manifests',
    );

    print('Проверяем манифесты Epic Games: $manifestPath');
    if (!await Directory(manifestPath).exists()) {
      print('Папка манифестов Epic Games не найдена');
      return null;
    }

    try {
      final dir = Directory(manifestPath);
      await for (final file in dir.list()) {
        if (file.path.endsWith('.item')) {
          try {
            final content = await File(file.path).readAsString();
            final manifest = json.decode(content);
            final installLocation = manifest['InstallLocation'] as String?;
            if (installLocation != null) {
              final gamePath = path.join(
                installLocation,
              );
              
              final paksPath = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks');
              print('Проверяем путь к Paks: $paksPath');
              
              if (await Directory(paksPath).exists()) {
                print('Найдена игра в Epic Games: $gamePath');
                return gamePath;
              }
            }
          } catch (e) {
            print('Ошибка при чтении манифеста ${file.path}: $e');
            continue;
          }
        }
      }
    } catch (e) {
      print('Ошибка при поиске в Epic Games: $e');
    }

    return null;
  }

  static Future<String?> findGameInstallPath() async {
    final steamPath = await findSteamGamePath();
    if (steamPath != null) return steamPath;

    final epicPath = await findEpicGamePath();
    if (epicPath != null) return epicPath;

    return null;
  }

  static Future<String?> findGameFolderForced() async {
    await CacheService.clearCache();
    return findGameFolder();
  }
} 