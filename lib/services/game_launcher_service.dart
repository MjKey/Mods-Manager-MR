import 'dart:io';
import 'platform_service.dart';

class GameLauncherService {
  static Future<void> launchThroughSteam() async {
    try {
      if (PlatformService.isWindows) {
        await Process.run('cmd', ['/c', 'start', 'steam://rungameid/2767030']);
      } else if (PlatformService.isLinux) {
        await Process.run('sh', ['-c', 'WINEPREFIX=~/.wine wine steam://rungameid/2767030']);
      }
    } catch (e) {
      throw Exception('Ошибка запуска игры через Steam: $e');
    }
  }

  static Future<void> launchThroughEpic() async {
    try {
      if (PlatformService.isWindows) {
        await Process.run('cmd', ['/c', 'start', 'com.epicgames.launcher://apps/38e211ced4e448a5a653a8d1e13fef18%3A27556e7cd968479daee8cc7bd77aebdd%3A575efd0b5dd54429b035ffc8fe2d36d0?action=launch&silent=true']);
      } else if (PlatformService.isLinux) {
        throw Exception('Запуск через Epic Games не поддерживается на Linux');
      }
    } catch (e) {
      throw Exception('Ошибка запуска игры через Epic Games: $e');
    }
  }
} 