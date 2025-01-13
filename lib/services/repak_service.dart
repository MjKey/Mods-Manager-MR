import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'platform_service.dart';
import 'unpacking_status_service.dart';
import 'localization_service.dart';

class RepakService {
  static final LocalizationService _localization = LocalizationService();

  static String get _appDataPath {
    if (PlatformService.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      return path.join(localAppData!, 'MarvelRivalsModsManager');
    } else {
      final home = Platform.environment['HOME'];
      return path.join(home!, '.local', 'share', 'MarvelRivalsModsManager');
    }
  }

  static String get unpackedModsPath {
    return path.join(_appDataPath, 'Unpacked Mods');
  }

  static String get repakPath {
    return path.join(Directory.current.path, 'assets', 'quickbms');
  }

  static Future<void> unpackMod(String pakFilePath, {String? outputPath}) async {
    final unpackingService = UnpackingStatusService();
    final pakFileName = path.basename(pakFilePath);
    
    try {
      print(_localization.translate('repak.logs.unpack_start', {'path': pakFilePath}));
      unpackingService.startUnpacking(pakFileName);
      
      if (!await File(pakFilePath).exists()) {
        throw Exception(_localization.translate('repak.errors.unpack_file_not_found', {'path': pakFilePath}));
      }

      final finalOutputPath = outputPath ?? path.join(unpackedModsPath, path.basenameWithoutExtension(pakFilePath));
      print(_localization.translate('repak.logs.unpack_path', {'path': finalOutputPath}));
      
      await Directory(finalOutputPath).create(recursive: true);
      
      final repakExe = path.join(repakPath, 'repak.exe');
      print(_localization.translate('repak.logs.checking_components'));
      
      if (!await File(repakExe).exists()) {
        throw Exception(_localization.translate('repak.errors.repak_not_found', {'path': repakExe}));
      }

      unpackingService.updateStatus(_localization.translate('repak.logs.preparing'));
      
      final process = await Process.start(repakExe, [
        'unpack',
        '-o', finalOutputPath,
        '-s', '../../../',
        pakFilePath
      ]);

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        print(_localization.translate('repak.logs.output', {'line': line}));
        if (line.contains('%')) {
          unpackingService.updateStatus(_localization.translate('repak.logs.unpacking_progress', {'progress': line.trim()}));
        }
      });

      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        print(_localization.translate('repak.logs.error', {'line': line}));
      });

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw Exception(_localization.translate('repak.errors.unpack_failed', {'code': exitCode.toString()}));
      }

      unpackingService.finishUnpacking();
      print(_localization.translate('repak.logs.unpack_complete'));
    } catch (e, stackTrace) {
      print(_localization.translate('repak.errors.unpack_error', {'error': e.toString()}));
      print('Стек ошибки: $stackTrace');
      unpackingService.finishUnpacking();
      throw Exception(_localization.translate('repak.errors.unpack_error', {'error': e.toString()}));
    }
  }

  static Future<void> checkRequirements() async {
    final repakExe = path.join(repakPath, 'repak.exe');
    print(_localization.translate('repak.logs.checking_repak', {'path': repakExe}));
    
    if (!await File(repakExe).exists()) {
      throw Exception(_localization.translate('repak.errors.repak_not_found', {'path': repakExe}));
    }
  }
} 