import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'localization_service.dart';

class ArchiveService {
  static final LocalizationService _localization = LocalizationService();

  static Future<String?> extractPakFromArchive(String archivePath) async {
    try {
      final bytes = await File(archivePath).readAsBytes();
      final extension = path.extension(archivePath).toLowerCase();
      
      Archive? archive;
      if (extension == '.zip') {
        archive = ZipDecoder().decodeBytes(bytes);
      } else if (extension == '.rar') {
        throw Exception(_localization.translate('archive.errors.unsupported_format_rar'));
      }

      if (archive == null) {
        throw Exception(_localization.translate('archive.errors.unsupported_format'));
      }

      // Ищем .pak файл в архиве
      final pakFile = archive.files.firstWhere(
        (file) => path.extension(file.name).toLowerCase() == '.pak',
        orElse: () => throw Exception(_localization.translate('archive.errors.no_pak_found')),
      );

      // Создаем временную директорию для распаковки
      final tempDir = await Directory.systemTemp.createTemp('marvel_rivals_mod_');
      final pakPath = path.join(tempDir.path, path.basename(pakFile.name));

      // Распаковываем только .pak файл
      final pakData = pakFile.content as List<int>;
      await File(pakPath).writeAsBytes(pakData);

      return pakPath;
    } catch (e) {
      print('Ошибка при распаковке архива: $e');
      return null;
    }
  }

  static Future<void> cleanupTempFiles(String tempFilePath) async {
    try {
      final tempDir = Directory(path.dirname(tempFilePath));
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      print('Ошибка при очистке временных файлов: $e');
    }
  }
} 