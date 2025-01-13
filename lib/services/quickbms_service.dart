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

  static String get backupsPath {
    return path.join(_appDataPath, 'Backups');
  }

  static String get quickBMSPath {
    return path.join(Directory.current.path, 'assets', 'quickbms');
  }

  static Future<void> initializeDirectories() async {
    final directory = Directory(_appDataPath);
    final unpackedDirectory = Directory(unpackedModsPath);
    final backupDirectory = Directory(backupPakPath);
    final backupsDirectory = Directory(backupsPath);

    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    if (!unpackedDirectory.existsSync()) {
      await unpackedDirectory.create(recursive: true);
    }
    if (!backupDirectory.existsSync()) {
      await backupDirectory.create(recursive: true);
    }
    if (!backupsDirectory.existsSync()) {
      await backupsDirectory.create(recursive: true);
    }
  }

  static Future<void> unpackMod(
    String pakFilePath, {
    String? outputPath,
    bool moveToBackup = false,
  }) async {
    final unpackingService = UnpackingStatusService();
    final pakFileName = path.basename(pakFilePath);
    bool unpacking = false;
    
    try {
      print(_localization.translate('quickbms.logs.unpack_start', {'path': pakFilePath}));
      unpackingService.startUnpacking(pakFileName);
      
      // Проверяем существование входного файла
      if (!await File(pakFilePath).exists()) {
        throw Exception(_localization.translate('quickbms.errors.unpack_file_not_found', {'path': pakFilePath}));
      }
      
      // Для файлов игры, используем родительскую директорию Marvel
      final isGameFile = pakFileName == 'pakchunkCharacter-Windows.pak' || 
                        pakFileName == 'pakchunkWwise-Windows.pak' ||
                        pakFileName == 'pakchunkVFX-Windows.pak';
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

      // Добавляем небольшую задержку перед началом распаковки
      await Future.delayed(const Duration(seconds: 1));
      
      // Обрабатываем вывод процесса
      process.stdout.transform(systemEncoding.decoder).transform(const LineSplitter()).listen((output) {
        final line = output.trim();
        if (line.isEmpty) return;
        
        // Проверяем начало распаковки по различным признакам
        if (line.toLowerCase().contains('starting the extraction') || 
            line.toLowerCase().contains('- starting the extraction') ||
            line.toLowerCase().contains('scanning') ||
            line.contains('.uasset') ||
            line.contains('.uexp') ||
            line.contains('.ubulk') ||
            line.contains('->')) {
          
          if (!unpacking) {
            print('Обнаружено начало распаковки: $line');
            unpacking = true;
            unpackingService.updateStatus(_localization.translate('quickbms.logs.extracting'));
          }
          
          // Извлекаем имя файла из строки вывода
          String? fileName;
          if (line.contains('->')) {
            final parts = line.split('->');
            if (parts.length > 1) {
              fileName = parts[1].trim();
            }
          } else if (line.contains('.u')) {
            // Ищем последнюю часть пути после последнего пробела
            final parts = line.split(' ');
            fileName = parts.last.trim();
          }
          
          // Если нашли имя файла, обновляем статус
          if (fileName != null && fileName.isNotEmpty) {
            final status = _localization.translate('quickbms.logs.unpacking_file', {'file': fileName});
            print('Текущий файл: $fileName');
            unpackingService.updateStatus(status);
          }
        }
      });

      // Обрабатываем ошибки
      process.stderr.transform(systemEncoding.decoder).transform(const LineSplitter()).listen((error) {
        final line = error.trim();
        if (line.isEmpty) return;
        print('Ошибка QuickBMS: $line'); // Отладочный вывод
      });

      // Ждем завершения процесса
      final exitCode = await process.exitCode;
      
      if (exitCode != 0) {
        throw Exception(_localization.translate('quickbms.errors.unpack_failed', {'code': exitCode.toString()}));
      }

      print(_localization.translate('quickbms.logs.unpack_complete'));
      unpackingService.updateStatus(_localization.translate('quickbms.logs.unpack_complete'));
      
      
      // Если нужно переместить в бэкап
      if (moveToBackup && isGameFile) {
        try {
          final backupPath = path.join(backupPakPath, pakFileName);
          
          // Проверяем существование оригинального файла
          if (!await File(pakFilePath).exists()) {
            print('ОШИБКА: Оригинальный файл не найден: $pakFilePath');
            throw Exception(_localization.translate('quickbms.errors.unpack_file_not_found', {'path': pakFilePath}));
          }

          // Создаем директорию для бэкапа если её нет
          final backupDir = Directory(path.dirname(backupPath));
          if (!await backupDir.exists()) {
            await backupDir.create(recursive: true);
          }
          
          // Сначала копируем файл
          print(_localization.translate('quickbms.logs.backup_copy', {'path': backupPath}));
          await File(pakFilePath).copy(backupPath);
          
          // Проверяем, что файл скопировался
          if (!await File(backupPath).exists()) {
            print('ОШИБКА: Файл не скопировался в бэкап: $backupPath');
            throw Exception('Backup file was not created');
          }
          
          // Затем удаляем оригинал
          print(_localization.translate('quickbms.logs.removing_original'));
          await File(pakFilePath).delete();
          
          // Проверяем, что оригинал удалился
          if (await File(pakFilePath).exists()) {
            print('ОШИБКА: Не удалось удалить оригинальный файл: $pakFilePath');
            throw Exception('Failed to delete original file');
          }

          // Проверяем и удаляем дополнительные файлы
          final paksDir = path.dirname(pakFilePath);
          final additionalFiles = [
            'pakchunkCharacter-Windows.pak',
            'pakchunkWwise-Windows.pak',
            'pakchunkVFX-Windows.pak'
          ];

          for (final fileName in additionalFiles) {
            final filePath = path.join(paksDir, fileName);
            final fileBackupPath = path.join(backupPakPath, fileName);

            if (await File(filePath).exists()) {
              try {
                // Пытаемся сделать бэкап
                print(_localization.translate('quickbms.logs.backup_copy', {'path': fileBackupPath}));
                await File(filePath).copy(fileBackupPath);

                // Если бэкап успешен - удаляем оригинал
                if (await File(fileBackupPath).exists()) {
                  print(_localization.translate('quickbms.logs.removing_original'));
                  await File(filePath).delete();
                  print(_localization.translate('quickbms.logs.moved_to_backup', {'path': fileBackupPath}));
                }
              } catch (e) {
                // При ошибке бэкапа - принудительно удаляем файл
                print('ОШИБКА при создании бэкапа файла $fileName: ${e.toString()}');
                print('Принудительное удаление файла без бэкапа: $filePath');
                
                try {
                  if (await File(filePath).exists()) {
                    await File(filePath).delete();
                    print('Файл успешно удален: $filePath');
                  }
                } catch (deleteError) {
                  print('ОШИБКА при принудительном удалении файла $fileName: ${deleteError.toString()}');
                }
              }
            }
          }
          
          print(_localization.translate('quickbms.logs.moved_to_backup', {'path': backupPath}));
        } catch (e) {
          print('ОШИБКА при создании бэкапа: ${e.toString()}');
          throw Exception(_localization.translate('quickbms.errors.backup_failed', {'error': e.toString()}));
        }
      }

    } catch (e) {
      print(_localization.translate('quickbms.errors.unpack_error', {'error': e.toString()}));
      unpackingService.updateStatus(_localization.translate('quickbms.errors.unpack_error', {'error': e.toString()}));
      rethrow;
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