import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/game_paths_service.dart';
import '../services/game_finder_service.dart';
import '../services/settings_service.dart';
import '../services/localization_service.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _gamePath;
  String? _modsPath;
  bool _isLoading = true;
  late LocalizationService _localizationService;

  @override
  void initState() {
    super.initState();
    _localizationService = LocalizationService();
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    final gamePath = await GamePathsService.getGamePath();
    final modsPath = await SettingsService.getModsPath();
    
    setState(() {
      _gamePath = gamePath;
      _modsPath = modsPath;
      _isLoading = false;
    });
  }

  Future<void> _selectDirectory(String title, Function(String) onSelected) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: title,
    );
    if (result != null) {
      await onSelected(result);
      await _loadPaths();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_localizationService.translate('settings.title')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  title: Text(_localizationService.translate('settings.language')),
                  trailing: DropdownButton<String>(
                    value: _localizationService.currentLanguage,
                    items: LocalizationService.supportedLanguages
                        .map((lang) => DropdownMenuItem(
                              value: lang['code'],
                              child: Text(lang['name']!),
                            ))
                        .toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        _localizationService.setLanguage(newValue);
                        setState(() {});
                      }
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  title: Text(_localizationService.translate('settings.paths.game.title')),
                  subtitle: Text(_gamePath ?? _localizationService.translate('settings.paths.game.not_found')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () async {
                          final path = await GameFinderService.findGameFolder();
                          if (path != null) {
                            try {
                              await GamePathsService.setGamePath(path);
                              await _loadPaths();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_localizationService.translate(
                                    'settings.paths.game.error',
                                    {'error': e.toString()},
                                  ))),
                                );
                              }
                            }
                          }
                        },
                        tooltip: _localizationService.translate('settings.paths.game.tooltips.auto_find'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: () async {
                          final result = await FilePicker.platform.getDirectoryPath(
                            dialogTitle: _localizationService.translate('settings.paths.game.title'),
                          );
                          if (result != null) {
                            try {
                              await GamePathsService.setGamePath(result);
                              await _loadPaths();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_localizationService.translate(
                                    'settings.paths.game.error',
                                    {'error': e.toString()},
                                  ))),
                                );
                              }
                            }
                          }
                        },
                        tooltip: _localizationService.translate('settings.paths.game.tooltips.manual_select'),
                      ),
                    ],
                  ),
                ),
                if (_gamePath == null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _localizationService.translate('settings.paths.game.warning'),
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                const Divider(),
                ListTile(
                  title: Text(_localizationService.translate('settings.paths.mods.title')),
                  subtitle: Text(_modsPath ?? _localizationService.translate('settings.paths.mods.not_set')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await SettingsService.setModsPath(
                            path.join(SettingsService.defaultAppDataPath, 'Disabled Mods')
                          );
                          await _loadPaths();
                        },
                        child: Text(_localizationService.translate('settings.paths.mods.default')),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: () => _selectDirectory(
                          _localizationService.translate('settings.paths.mods.dialog_title'),
                          SettingsService.setModsPath,
                        ),
                        tooltip: _localizationService.translate('settings.paths.mods.tooltip'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Dev. MjKey | 2025 | Made with '),
                          const Icon(Icons.favorite, color: Colors.red, size: 16),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse('https://www.donationalerts.com/r/mjk3y')),
                        icon: const Icon(Icons.favorite_border),
                        label: const Text('Поддержать разработку'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
} 