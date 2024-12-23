import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/mod_manager.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
  late AppSettings settings;

  @override
  void initState() {
    super.initState();
    settings = AppSettings(
      autoEnableMods: widget.modManager.settings.autoEnableMods,
      showFileSize: widget.modManager.settings.showFileSize,
      customModsFolder: widget.modManager.settings.customModsFolder,
      language: widget.modManager.settings.language,
    );
  }

  Future<void> _selectCustomModsFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).get('mods_folder'),
    );

    if (result != null) {
      setState(() {
        settings.customModsFolder = result;
      });
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
            onPressed: () async {
              final oldLanguage = widget.modManager.settings.language;
              await widget.modManager.updateSettings(settings);
              if (mounted) {
                Navigator.of(context).pop(true);
                if (oldLanguage != settings.language) {
                  if (mounted) {
                    Phoenix.rebirth(context);
                  }
                }
              }
            },
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
            value: settings.autoEnableMods,
            onChanged: (value) {
              setState(() {
                settings.autoEnableMods = value;
              });
            },
          ),
          SwitchListTile(
            title: Text(l10n.get('show_file_size')),
            subtitle: Text(l10n.get('show_file_size_desc')),
            value: settings.showFileSize,
            onChanged: (value) {
              setState(() {
                settings.showFileSize = value;
              });
            },
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.get('language'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _LanguageOption(
                        isSelected: settings.language == 'en',
                        onTap: () {
                          setState(() {
                            settings.language = 'en';
                          });
                        },
                        name: 'English',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LanguageOption(
                        isSelected: settings.language == 'ru',
                        onTap: () {
                          setState(() {
                            settings.language = 'ru';
                          });
                        },
                        name: 'Русский',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            title: Text(l10n.get('mods_folder')),
            subtitle: Text(settings.customModsFolder ?? l10n.get('default_folder')),
            trailing: IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: _selectCustomModsFolder,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final String name;

  const _LanguageOption({
    required this.isSelected,
    required this.onTap,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 