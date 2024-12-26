import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/mod_manager.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  final ModManager modManager;

  const SettingsScreen({
    super.key,
    required this.modManager,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _autoEnableMods;
  late bool _showFileSize;
  late String _language;
  String? _disabledModsPath;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _autoEnableMods = widget.modManager.settings.autoEnableMods;
    _showFileSize = widget.modManager.settings.showFileSize;
    _language = widget.modManager.settings.language;
    _disabledModsPath = widget.modManager.settings.disabledModsPath;
  }

  Future<void> _selectDisabledModsFolder() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.get('select_disabled_mods_folder'),
    );

    if (result != null) {
      setState(() {
        _disabledModsPath = result;
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectGameFolder() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.get('select_game_folder'),
    );

    if (result != null) {
      if (widget.modManager.isValidGamePath(result)) {
        await widget.modManager.setGamePath(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.get('game_folder_changed'))),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.get('invalid_folder')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveSettings() async {
    final newSettings = AppSettings(
      language: _language,
      autoEnableMods: _autoEnableMods,
      showFileSize: _showFileSize,
      disabledModsPath: _disabledModsPath,
    );

    await widget.modManager.updateSettings(newSettings);
    
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.get('settings')),
        actions: [
          TextButton(
            onPressed: _hasChanges
                ? () async {
                    await _saveSettings();
                  }
                : null,
            child: Text(l10n.get('save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text(l10n.get('auto_enable_mods')),
            subtitle: Text(l10n.get('auto_enable_mods_desc')),
            value: _autoEnableMods,
            onChanged: (value) {
              setState(() {
                _autoEnableMods = value;
                _hasChanges = true;
              });
            },
          ),
          SwitchListTile(
            title: Text(l10n.get('show_file_size')),
            subtitle: Text(l10n.get('show_file_size_desc')),
            value: _showFileSize,
            onChanged: (value) {
              setState(() {
                _showFileSize = value;
                _hasChanges = true;
              });
            },
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.get('game_folder')),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.get('game_folder_desc')),
                if (widget.modManager.gamePath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      widget.modManager.gamePath!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            trailing: TextButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.get('change_game_folder')),
              onPressed: _selectGameFolder,
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.get('disabled_mods_folder')),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.get('disabled_mods_folder_desc')),
                if (_disabledModsPath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _disabledModsPath!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_disabledModsPath != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _disabledModsPath = null;
                        _hasChanges = true;
                      });
                    },
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: Text(_disabledModsPath == null
                      ? l10n.get('select_folder')
                      : l10n.get('change_folder')),
                  onPressed: _selectDisabledModsFolder,
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.get('language')),
            trailing: DropdownButton<String>(
              value: _language,
              items: const [
                DropdownMenuItem(
                  value: 'en',
                  child: Text('English'),
                ),
                DropdownMenuItem(
                  value: 'ru',
                  child: Text('Русский'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _language = value;
                    _hasChanges = true;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              l10n.get('made_with_love'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
} 