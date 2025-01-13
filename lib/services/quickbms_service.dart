import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'platform_service.dart';
import 'unpacking_status_service.dart';
import '../services/localization_service.dart';

class QuickBMSService {
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

  static String get backupPakPath {
    return path.join(_appDataPath, 'BackupPak');
  }

  static String get quickBMSPath {
    return path.join(Directory.current.path, 'assets', 'quickbms');
  }

  static Future<void> initializeDirectories() async {
    final directory = Directory(_appDataPath);
    final unpackedDirectory = Directory(unpackedModsPath);
    final backupDirectory = Directory(backupPakPath);

    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    if (!unpackedDirectory.existsSync()) {
      await unpackedDirectory.create(recursive: true);
    }
    if (!backupDirectory.existsSync()) {
      await backupDirectory.create(recursive: true);
    }
  }

  static Future<void> unpackMod(
    String pakFilePath, {
    String? outputPath,
    bool moveToBackup = false,
  }) async {
    final unpackingService = UnpackingStatusService();
    final pakFileName = path.basename(pakFilePath);
    
    try {
      print(_localization.translate('quickbms.logs.unpack_start', {'path': pakFilePath}));
      unpackingService.startUnpacking(pakFileName);
      
      // Проверяем существование входного файла
      if (!await File(pakFilePath).exists()) {
        throw Exception(_localization.translate('quickbms.errors.unpack_file_not_found', {'path': pakFilePath}));
      }
      
      // Для файлов игры, используем родительскую директорию Marvel
      final isGameFile = pakFileName == 'pakchunkCharacter-Windows.pak';
      final finalOutputPath = isGameFile 
        ? path.dirname(path.dirname(path.dirname(path.dirname(pakFilePath))))
        : (outputPath ?? path.join(unpackedModsPath, path.basenameWithoutExtension(pakFilePath)));
      
      print(_localization.translate('quickbms.logs.unpack_path', {'path': finalOutputPath}));
      unpackingService.updateStatus(_localization.translate('quickbms.logs.preparing'));
      
      // Создаем директорию для распаковки, если её нет
      if (!isGameFile) {
        print(_localization.translate('quickbms.logs.create_mod_dir', {'path': finalOutputPath}));
        await Directory(finalOutputPath).create(recursive: true);
      }
      
      // Проверяем наличие QuickBMS
      final quickBmsExe = path.join(quickBMSPath, 'quickbms_4gb_files.exe');
      final bmsScript = path.join(quickBMSPath, 'marvel_rivals.bms');

      print(_localization.translate('quickbms.logs.checking_components'));
      print(_localization.translate('quickbms.logs.quickbms_exe', {'path': quickBmsExe}));
      print(_localization.translate('quickbms.logs.bms_script', {'path': bmsScript}));

      if (!await File(quickBmsExe).exists()) {
        throw Exception(_localization.translate('quickbms.errors.quickbms_not_found', {'path': quickBmsExe}));
      }
      if (!await File(bmsScript).exists()) {
        throw Exception(_localization.translate('quickbms.errors.script_not_found', {'path': bmsScript}));
      }

      unpackingService.updateStatus(_localization.translate('quickbms.logs.preparing'));
      print(_localization.translate('quickbms.logs.start_process'));

      final command = '"$quickBmsExe" -C -o "$bmsScript" "$pakFilePath" "$finalOutputPath"';
      print(_localization.translate('quickbms.logs.executing_command', {'command': command}));

      final process = await Process.start(quickBmsExe, [
        '-C', '-o', bmsScript, pakFilePath, finalOutputPath
      ]);

      // Обрабатываем вывод в реальном времени
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        print(_localization.translate('quickbms.logs.quickbms_output', {'line': line}));
        // Ищем имя файла в выводе QuickBMS
        if (line.contains('->')) {
          final parts = line.split('->');
          if (parts.length > 1) {
            final currentFile = parts[1].trim();
            unpackingService.updateStatus(_localization.translate('quickbms.logs.unpacking_file', {'file': currentFile}));
          }
        }
      });

      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        print(_localization.translate('quickbms.logs.quickbms_error', {'line': line}));
      });

      // Ждем завершения процесса
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw Exception(_localization.translate('quickbms.errors.unpack_failed', {'code': exitCode.toString()}));
      }

      if (moveToBackup && isGameFile) {
        unpackingService.updateStatus(_localization.translate('quickbms.logs.moving_to_backup'));
        final backupPath = path.join(backupPakPath, pakFileName);
        print(_localization.translate('quickbms.logs.backup_path', {'path': backupPath}));
        
        // Создаем директорию для бэкапа если её нет
        final backupDir = Directory(path.dirname(backupPath));
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        
        await File(pakFilePath).copy(backupPath);
        await File(pakFilePath).delete();
        print(_localization.translate('quickbms.logs.file_moved', {'source': pakFilePath, 'target': backupPath}));
      }

      unpackingService.finishUnpacking();
      print(_localization.translate('quickbms.logs.unpack_complete'));
    } catch (e, stackTrace) {
      print(_localization.translate('quickbms.errors.unpack_error', {'error': e.toString()}));
      print('Стек ошибки: $stackTrace');
      unpackingService.finishUnpacking();
      throw Exception(_localization.translate('quickbms.errors.unpack_error', {'error': e.toString()}));
    }
  }

  static Future<void> checkRequirements() async {
    final quickbmsExe = path.join(quickBMSPath, 'quickbms_4gb_files.exe');
    final bmsScript = path.join(quickBMSPath, 'marvel_rivals.bms');
    
    print(_localization.translate('quickbms.logs.checking_quickbms', {'path': quickbmsExe}));
    print(_localization.translate('quickbms.logs.checking_script', {'path': bmsScript}));
    
    if (!await File(quickbmsExe).exists()) {
      throw Exception(_localization.translate('quickbms.errors.quickbms_not_found', {'path': quickbmsExe}));
    }
    if (!await File(bmsScript).exists()) {
      throw Exception(_localization.translate('quickbms.errors.script_not_found', {'path': bmsScript}));
    }
  }
} 