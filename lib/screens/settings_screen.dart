import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/game_paths_service.dart';
import '../services/game_finder_service.dart';
import '../services/mod_manager_service.dart';
import '../providers/mods_provider.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/localization_service.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _gamePath;
  String? _backupPath;
  String? _modsPath;
  bool _isLoading = true;
  late LocalizationService _localizationService;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _localizationService = LocalizationService();
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    final gamePath = await GamePathsService.getGamePath();
    final backupPath = await SettingsService.getBackupPath();
    final modsPath = await SettingsService.getModsPath();
    
    setState(() {
      _gamePath = gamePath;
      _backupPath = backupPath;
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
                    onChanged: (String? langCode) {
                      if (langCode != null) {
                        _localizationService.setLanguage(langCode);
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
                        icon: const Icon(Icons.refresh),
                        onPressed: () async {
                          setState(() => _isLoading = true);
                          final path = await GameFinderService.findGameFolderForced();
                          setState(() {
                            _gamePath = path;
                            _isLoading = false;
                          });
                        },
                        tooltip: _localizationService.translate('settings.paths.game.tooltips.auto_find'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: () async {
                          final result = await FilePicker.platform.getDirectoryPath();
                          if (result != null) {
                            try {
                              await GamePathsService.setGamePath(result);
                              setState(() => _gamePath = result);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_localizationService.translate('settings.paths.game.error', {'error': e.toString()}))),
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
                  title: Text(_localizationService.translate('settings.paths.backup.title')),
                  subtitle: Text(_backupPath ?? _localizationService.translate('settings.paths.backup.not_set')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await SettingsService.setBackupPath(
                            SettingsService.defaultAppDataPath + '\\Backups'
                          );
                          await _loadPaths();
                        },
                        child: Text(_localizationService.translate('settings.paths.backup.default')),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: () => _selectDirectory(
                          _localizationService.translate('settings.paths.backup.dialog_title'),
                          SettingsService.setBackupPath,
                        ),
                        tooltip: _localizationService.translate('settings.paths.backup.tooltip'),
                      ),
                    ],
                  ),
                ),
                
                ListTile(
                  title: Text(_localizationService.translate('settings.paths.mods.title')),
                  subtitle: Text(_modsPath ?? _localizationService.translate('settings.paths.mods.not_set')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await SettingsService.setModsPath(
                            SettingsService.defaultAppDataPath + '\\Unpacked Mods'
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
                const Divider(),
                ListTile(
                  title: Text(
                    _localizationService.translate('settings.reset.title'),
                    style: const TextStyle(color: Colors.red),
                  ),
                  subtitle: Text(
                    _localizationService.translate('settings.reset.subtitle'),
                    style: const TextStyle(color: Colors.red),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _showResetConfirmation(context),
                    child: Text(_localizationService.translate('settings.reset.button')),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Made with '),
                          const Icon(Icons.favorite, color: Colors.red, size: 16),
                          const Text(' | v2.0 | '),
                          InkWell(
                            onTap: () async {
                              final url = Uri.parse('https://mjkey.ru');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            child: const Text(
                              'MjKey',
                              style: TextStyle(
                                color: Color.fromARGB(255, 33, 194, 243),
                              ),
                            ),
                          ),
                          const Text(' | '),
                          InkWell(
                            onTap: () async {
                              final url = Uri.parse('https://www.donationalerts.com/c/mjk3y');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            child: const Text(
                              'Donate',
                              style: TextStyle(
                                color: Color.fromARGB(255, 243, 135, 33),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          setState(() => _isCheckingUpdate = true);
                          try {
                            final hasUpdate = await _checkForUpdates();
                            if (!mounted) return;
                            
                            if (hasUpdate) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(_localizationService.translate('settings.update.available.title')),
                                  content: Text(_localizationService.translate('settings.update.available.message')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(_localizationService.translate('settings.update.available.later')),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final url = Uri.parse('https://github.com/MjKey/Mods-Manager-MR/releases/latest');
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url);
                                        }
                                        if (mounted) Navigator.pop(context);
                                      },
                                      child: Text(_localizationService.translate('settings.update.available.download')),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_localizationService.translate('settings.update.no_updates')),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_localizationService.translate(
                                    'settings.update.error',
                                    {'error': e.toString()},
                                  )),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isCheckingUpdate = false);
                            }
                          }
                        },
                        icon: _isCheckingUpdate
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.update),
                        label: Text(_localizationService.translate('settings.update.check')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _showResetConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_localizationService.translate('settings.reset.confirmation.title')),
        content: Text(_localizationService.translate('settings.reset.confirmation.message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_localizationService.translate('settings.reset.confirmation.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_localizationService.translate('settings.reset.confirmation.confirm')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        setState(() => _isLoading = true);
        
        final gamePath = await GamePathsService.getGamePath();
        if (gamePath == null) {
          throw Exception(_localizationService.translate('mods.errors.game_path_not_found'));
        }

        await ModManagerService.resetAllMods(gamePath);
        
        // Обновляем ModsProvider
        await Provider.of<ModsProvider>(context, listen: false).loadMods();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_localizationService.translate('settings.reset.success'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_localizationService.translate('settings.reset.error', {'error': e.toString()}))),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<bool> _checkForUpdates() async {
    final response = await http.get(Uri.parse(
      'https://api.github.com/repos/MjKey/Mods-Manager-MR/releases/latest'
    ));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final latestVersion = data['tag_name'].toString().replaceAll('v', '');
      final currentVersion = '2.0';

      final List<String> latestParts = latestVersion.split('.');
      final List<String> currentParts = currentVersion.split('.');

      for (var i = 0; i < math.min(latestParts.length, currentParts.length); i++) {
        final latest = int.parse(latestParts[i]);
        final current = int.parse(currentParts[i]);
        if (latest > current) return true;
        if (latest < current) return false;
      }

      return latestParts.length > currentParts.length;
    }

    throw Exception('Failed to check for updates');
  }
} 