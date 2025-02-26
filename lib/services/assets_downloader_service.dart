import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:marvel_rivals_mod_manager/main.dart' show InitialCheckScreen;
import '../services/localization_service.dart';

class AssetsDownloaderService {
  static const String assetsUrl = 'https://mjkey.ru/MarvelRivalsModManager/assets.zip';
  static final LocalizationService _localization = LocalizationService();
  
  static Future<void> downloadAndSetupQuickBMS(BuildContext context) async {
    if (kIsWeb) {
      throw UnsupportedError(
        _localization.translate('downloader.errors.web_unsupported')
      );
    }

    final assetsDir = path.join(Directory.current.path, 'assets');
    final quickbmsDir = path.join(assetsDir, 'quickbms');
    final zipPath = path.join(assetsDir, 'assets.zip');

    print(_localization.translate('downloader.logs.download_url', {'url': assetsUrl}));
    print(_localization.translate('downloader.logs.save_path', {'path': zipPath}));

    final client = http.Client();

    try {
      await Directory(quickbmsDir).create(recursive: true);

      final request = http.Request('GET', Uri.parse(assetsUrl));
      
      // Добавляем заголовки
      request.headers.addAll({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
      });

      print(_localization.translate('downloader.logs.request_headers', {'headers': request.headers.toString()}));
      final response = await client.send(request);
      print(_localization.translate('downloader.logs.response_code', {'code': response.statusCode.toString()}));
      
      if (response.statusCode != 200) {
        throw Exception(
          _localization.translate('downloader.errors.download_failed', {'code': response.statusCode.toString()})
        );
      }

      print(_localization.translate('downloader.logs.file_size', {'size': response.contentLength.toString()}));
      
      final contentLength = response.contentLength ?? 0;
      int received = 0;

      final file = File(zipPath);
      final sink = file.openWrite();

      final completer = Completer();
      final progressNotifier = ValueNotifier<double>(0);
      final downloadedNotifier = ValueNotifier<int>(0);

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ValueListenableBuilder(
            valueListenable: progressNotifier,
            builder: (context, progress, _) {
              return AlertDialog(
                title: Text(_localization.translate('downloader.progress.title')),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<int>(
                      valueListenable: downloadedNotifier,
                      builder: (context, downloaded, _) {
                        return Text(
                          _localization.translate('downloader.progress.downloaded', {
                            'downloaded': (downloaded / 1024 / 1024).toStringAsFixed(2),
                            'total': (contentLength / 1024 / 1024).toStringAsFixed(2)
                          })
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    if (contentLength > 0)
                      LinearProgressIndicator(value: progress),
                  ],
                ),
              );
            },
          ),
        );
      }

      print(_localization.translate('downloader.logs.download_start'));
      response.stream.listen(
        (List<int> chunk) {
          received += chunk.length;
          sink.add(chunk);
          progressNotifier.value = received / contentLength;
          downloadedNotifier.value = received;
          print(_localization.translate('downloader.logs.received', {
            'received': received.toString(),
            'total': contentLength.toString()
          }));
        },
        onDone: () async {
          print(_localization.translate('downloader.logs.download_complete'));
          await sink.close();
          completer.complete();
        },
        onError: (error) {
          print('Ошибка при загрузке: $error');
          completer.completeError(error);
        },
        cancelOnError: true,
      );

      await completer.future;

      final fileLength = await file.length();
      print(_localization.translate('downloader.logs.file_length', {'size': fileLength.toString()}));

      final bytes = await file.readAsBytes();
      print(_localization.translate('downloader.logs.first_bytes', {'bytes': bytes.take(10).toList().toString()}));

      // Проверяем, что файл - действительно ZIP архив
      if (bytes.length < 4 || 
          bytes[0] != 0x50 || // P
          bytes[1] != 0x4B || // K
          bytes[2] != 0x03 || // \x03
          bytes[3] != 0x04) { // \x04
        throw FormatException(_localization.translate('downloader.errors.not_zip'));
      }

      try {
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final file in archive) {
          final filename = file.name;
          if (file.isFile) {
            final data = file.content as List<int>;
            final outFile = File(path.join(quickbmsDir, filename));
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(data);
          }
        }

        await file.delete();
        
        if (context.mounted) {
          Navigator.of(context).pop();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const InitialCheckScreen()),
            (route) => false,
          );
        }

      } catch (e) {
        throw FormatException(_localization.translate('downloader.errors.unpack_failed', {'error': e.toString()}));
      }

    } catch (e) {
      print('Ошибка при установке QuickBMS: $e');
      print('Стек вызовов: ${StackTrace.current}');
      rethrow;
    } finally {
      client.close();
    }
  }
} 