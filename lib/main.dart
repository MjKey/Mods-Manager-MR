import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/mods_provider.dart';
import 'services/game_paths_service.dart';
import 'services/quickbms_service.dart';
import 'services/localization_service.dart';
import 'dart:io';
import 'widgets/unpacking_progress_dialog.dart';
import 'services/assets_downloader_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализируем сервис локализации
  await LocalizationService().init();
  
  // Проверяем наличие QuickBMS до создания приложения
  final quickbmsDir = path.join(Directory.current.path, 'assets', 'quickbms');
  if (!await Directory(quickbmsDir).exists() || 
      !await File(path.join(quickbmsDir, 'quickbms_4gb_files.exe')).exists()) {
    
    // Создаем временный виджет для показа диалога
    final tempWidget = MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationService()),
      ],
      child: Consumer<LocalizationService>(
        builder: (context, localization, _) => MaterialApp(
          navigatorKey: GamePathsService.navigatorKey,
          locale: Locale(localization.currentLanguage),
          supportedLocales: LocalizationService.supportedLanguages
              .map((lang) => Locale(lang['code']!))
              .toList(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            backgroundColor: Colors.grey[900],
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    localization.translate('app.title'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localization.translate('app.initialization'),
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Показываем временное окно
    runApp(tempWidget);

    // Добавляем небольшую задержку, чтобы окно успело отрисоваться
    await Future.delayed(const Duration(seconds: 1));

    // Показываем диалог выбора языка
    final context = GamePathsService.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      final localization = context.read<LocalizationService>();
      final selectedLanguage = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(localization.translate('settings.language')),
          content: DropdownButton<String>(
            value: localization.currentLanguage,
            isExpanded: true,
            items: LocalizationService.supportedLanguages
                .map((lang) => DropdownMenuItem(
                      value: lang['code'],
                      child: Text(lang['name']!),
                    ))
                .toList(),
            onChanged: (String? langCode) {
              if (langCode != null) {
                Navigator.pop(context, langCode);
              }
            },
          ),
        ),
      );

      if (selectedLanguage != null) {
        await localization.setLanguage(selectedLanguage);
      }

      // Запрашиваем разрешение на загрузку
      if (!context.mounted) return;
      final shouldDownload = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(localization.translate('dialogs.components.title')),
          content: Text(localization.translate('dialogs.components.message')),
          actions: [
            TextButton(
              onPressed: () => exit(0),
              child: Text(localization.translate('dialogs.components.cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(localization.translate('dialogs.components.download')),
            ),
          ],
        ),
      );

      if (shouldDownload == true) {
        try {
          if (!context.mounted) return;
          await AssetsDownloaderService.downloadAndSetupQuickBMS(context);
        } catch (e) {
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(localization.translate('dialogs.error.title')),
                content: Text(localization.translate('dialogs.error.download_failed', {'error': e.toString()})),
                actions: [
                  TextButton(
                    onPressed: () => exit(0),
                    child: Text(localization.translate('dialogs.error.close')),
                  ),
                ],
              ),
            );
          }
          exit(1);
        }
      } else {
        exit(0);
      }
    }
  }

  // Запускаем основное приложение
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ModsProvider()),
        ChangeNotifierProvider(create: (_) => LocalizationService()),
      ],
      child: Consumer<LocalizationService>(
        builder: (context, localizationService, child) {
          return MaterialApp(
            title: localizationService.translate('app.title'),
            theme: ThemeData.dark(useMaterial3: true).copyWith(
              colorScheme: ColorScheme.dark(
                primary: Colors.blue,
                secondary: Colors.blueAccent,
                surface: Colors.grey[900]!,
                background: Colors.black87,
              ),
              cardTheme: CardTheme(
                color: Colors.grey[850],
                elevation: 4,
                margin: const EdgeInsets.all(8),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.grey[900],
                elevation: 0,
              ),
            ),
            navigatorKey: GamePathsService.navigatorKey,
            initialRoute: '/',
            routes: {
              '/': (context) => const InitialCheckScreen(),
              '/home': (context) => const HomeScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
            locale: Locale(localizationService.currentLanguage),
            supportedLocales: LocalizationService.supportedLanguages
                .map((lang) => Locale(lang['code']!))
                .toList(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }
}

class InitialCheckScreen extends StatefulWidget {
  const InitialCheckScreen({Key? key}) : super(key: key);

  @override
  State<InitialCheckScreen> createState() => _InitialCheckScreenState();
}

class _InitialCheckScreenState extends State<InitialCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkGamePath();
  }

  Future<void> _checkGamePath() async {
    try {
      final gamePath = await GamePathsService.getGamePath();
      if (!mounted) return;

      final localization = context.read<LocalizationService>();
      if (gamePath == null) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(localization.translate('dialogs.game_path.title')),
            content: Text(localization.translate('dialogs.game_path.message')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/settings');
                },
                child: Text(localization.translate('dialogs.game_path.go_to_settings')),
              ),
            ],
          ),
        );
      } else {
        // Проверяем наличие файла pakchunkCharacter-Windows.pak
        final paksPath = path.join(gamePath, 'MarvelGame', 'Marvel', 'Content', 'Paks');
        final characterPakPath = path.join(paksPath, 'pakchunkCharacter-Windows.pak');
        
        if (await File(characterPakPath).exists()) {
          if (!mounted) return;
          
          // Проверяем наличие QuickBMS
          try {
            print('Проверяем наличие QuickBMS...');
            await QuickBMSService.checkRequirements();
          } catch (e) {
            print('Ошибка при проверке QuickBMS: $e');
            if (mounted) {
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(localization.translate('dialogs.error.title')),
                  content: Text(localization.translate('dialogs.error.components_not_found', {'error': e.toString()})),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/settings'),
                      child: Text(localization.translate('dialogs.game_path.go_to_settings')),
                    ),
                  ],
                ),
              );
              return;
            }
          }
          
          final shouldUnpack = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text(localization.translate('dialogs.unpacking.title')),
              content: Text(localization.translate('dialogs.unpacking.message')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(localization.translate('dialogs.unpacking.cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(localization.translate('dialogs.unpacking.continue')),
                ),
              ],
            ),
          );

          if (shouldUnpack == true && mounted) {
            final confirmed = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                final localization = context.read<LocalizationService>();
                return AlertDialog(
                  title: Text(localization.translate('dialogs.unpacking.warning.title')),
                  content: Text(localization.translate('dialogs.unpacking.warning.message')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(localization.translate('dialogs.unpacking.warning.cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(localization.translate('dialogs.unpacking.warning.continue')),
                    ),
                  ],
                );
              },
            );

            if (confirmed == true && mounted) {
              try {
                print('Начинаем процесс распаковки...');
                
                // Показываем диалог прогресса
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const UnpackingProgressDialog(),
                );

                print('Диалог прогресса показан, запускаем распаковку...');
                
                // Распаковываем файл
                await QuickBMSService.unpackMod(
                  characterPakPath,
                  moveToBackup: true,
                );

                print('Распаковка завершена успешно');
                
                // Закрываем диалог прогресса
                if (mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                print('Ошибка при распаковке: $e');
                if (mounted) {
                  // Закрываем диалог прогресса
                  Navigator.of(context).pop();
                  
                  await showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      final localization = context.read<LocalizationService>();
                      return AlertDialog(
                        title: Text(localization.translate('dialogs.error.title')),
                        content: Text(localization.translate('dialogs.error.unpacking_failed', {'error': e.toString()})),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/settings'),
                            child: Text(localization.translate('dialogs.game_path.go_to_settings')),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }
              }
            }
          }
        }
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      print('Ошибка при проверке пути к игре: $e');
      if (mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            final localization = context.read<LocalizationService>();
            return AlertDialog(
              title: Text(localization.translate('dialogs.error.title')),
              content: Text(localization.translate('dialogs.error.general', {'error': e.toString()})),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/settings'),
                  child: Text(localization.translate('dialogs.game_path.go_to_settings')),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
} 