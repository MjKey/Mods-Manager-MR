import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/mods_provider.dart';
import 'providers/presets_provider.dart';
import 'services/game_paths_service.dart';
import 'services/localization_service.dart';
import 'services/presets_service.dart';
import 'services/patch_manager_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализируем сервис локализации
  await LocalizationService().init();
  
  // Инициализируем сервис пресетов
  await PresetsService.initialize();
  
  // Запускаем основное приложение
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  final String version = '2.2.1';

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ModsProvider()),
        ChangeNotifierProvider(create: (_) => PresetsProvider()),
        ChangeNotifierProvider(create: (_) => LocalizationService()),
      ],
      child: Consumer<LocalizationService>(
        builder: (context, localizationService, child) {
          return MaterialApp(
            title: '${localizationService.translate('app.title')} $version',
            theme: ThemeData.dark(useMaterial3: true).copyWith(
              colorScheme: ColorScheme.dark(
                primary: Colors.blue,
                secondary: Colors.blueAccent,
                surface: Colors.grey[900]!,
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
  const InitialCheckScreen({super.key});

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

      if (gamePath == null) {
        final localization = context.read<LocalizationService>();
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
        // Проверяем и переименовываем патч-файлы после нахождения пути к игре
        try {
          await PatchManagerService.renamePatchFiles();
        } catch (e) {
          print('Ошибка при проверке патч-файлов: $e');
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      print('Ошибка при проверке пути к игре: $e');
      if (mounted) {
        final localization = context.read<LocalizationService>();
        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
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