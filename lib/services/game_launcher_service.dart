import 'package:process_run/process_run.dart';
import 'platform_service.dart';

class GameLauncherService {
  static Future<void> launchThroughSteam() async {
    try {
      if (PlatformService.isWindows) {
        await Shell().run('start steam://rungameid/GAME_ID'); // Замените GAME_ID на реальный ID игры в Steam
      } else if (PlatformService.isLinux) {
        await Shell().run('WINEPREFIX=~/.wine wine steam://rungameid/GAME_ID');
      }
    } catch (e) {
      throw Exception('Ошибка запуска игры через Steam: $e');
    }
  }

  static Future<void> launchThroughLauncher() async {
    try {
      if (PlatformService.isWindows) {
        await Shell().run(r'start "" "C:\Program Files\Marvel Rivals\Launcher.exe"');
      } else if (PlatformService.isLinux) {
        await Shell().run('WINEPREFIX=~/.wine wine "C:\\Program Files\\Marvel Rivals\\Launcher.exe"');
      }
    } catch (e) {
      throw Exception('Ошибка запуска игры через лаунчер: $e');
    }
  }
} 