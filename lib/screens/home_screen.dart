import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/mods_provider.dart';
import '../widgets/mod_list_panel.dart';
import '../widgets/drop_target_overlay.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/settings_screen.dart';
import '../services/localization_service.dart';
import '../providers/presets_provider.dart';
import '../widgets/preset_save_dialog.dart';
import '../widgets/preset_load_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _enabledSearchQuery;
  String? _disabledSearchQuery;

  Future<void> _launchGame(String url) async {
    final localization = context.read<LocalizationService>();
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception(localization.translate('home.errors.game_launch'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.read<LocalizationService>();
    final String version = '2.2.1';
    return Scaffold(
      appBar: AppBar(
        title: Text('${localization.translate('app.title')} $version'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_esports),
            onPressed: () => _launchGame('steam://rungameid/2767030'),
            tooltip: localization.translate('home.tooltips.launch_steam'),
          ),
          IconButton(
            icon: const Icon(Icons.gamepad),
            onPressed: () => _launchGame('com.epicgames.launcher://apps/38e211ced4e448a5a653a8d1e13fef18%3A27556e7cd968479daee8cc7bd77aebdd%3A575efd0b5dd54429b035ffc8fe2d36d0?action=launch&silent=true'),
            tooltip: localization.translate('home.tooltips.launch_epic'),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              final modsProvider = Provider.of<ModsProvider>(context, listen: false);
              final enabledMods = modsProvider.enabledMods.map((m) => m.name).toList();
              
              if (enabledMods.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(localization.translate('presets.errors.no_enabled_mods'))),
                );
                return;
              }

              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (context) => PresetSaveDialog(enabledMods: enabledMods),
              );

              if (result != null && context.mounted) {
                try {
                  await Provider.of<PresetsProvider>(context, listen: false)
                    .savePreset(result['name'], result['description'], result['enabledMods']);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(localization.translate('presets.messages.saved'))),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              }
            },
            tooltip: localization.translate('presets.save.tooltip'),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () async {
              final presetsProvider = Provider.of<PresetsProvider>(context, listen: false);
              await presetsProvider.loadPresets();

              if (context.mounted) {
                final preset = await showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            localization.translate('presets.load.title'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Expanded(child: PresetLoadDialog()),
                        ],
                      ),
                    ),
                  ),
                );

                if (preset != null && context.mounted) {
                  try {
                    final modsProvider = Provider.of<ModsProvider>(context, listen: false);
                    await presetsProvider.applyPreset(preset, modsProvider);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(localization.translate('presets.messages.loaded'))),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                }
              }
            },
            tooltip: localization.translate('presets.load.tooltip'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addMod(context),
            tooltip: localization.translate('home.tooltips.add_mod'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
            tooltip: localization.translate('home.tooltips.settings'),
          ),
        ],
      ),
      body: DropTargetOverlay(
        child: Consumer<ModsProvider>(
          builder: (context, modsProvider, child) {
            if (modsProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final enabledMods = modsProvider.getEnabledMods(
              searchQuery: _enabledSearchQuery,
            );
            final disabledMods = modsProvider.getDisabledMods(
              searchQuery: _disabledSearchQuery,
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ModListPanel(
                    title: localization.translate('home.mod_lists.disabled'),
                    mods: disabledMods,
                    onSearch: (query) => setState(() => _disabledSearchQuery = query),
                    onToggle: (mod) => modsProvider.toggleMod(mod),
                    onRename: (mod, newName) => modsProvider.renameMod(mod, newName),
                    isEnabledList: false,
                  ),
                ),
                Expanded(
                  child: ModListPanel(
                    title: localization.translate('home.mod_lists.enabled'),
                    mods: enabledMods,
                    onSearch: (query) => setState(() => _enabledSearchQuery = query),
                    onToggle: (mod) => modsProvider.toggleMod(mod),
                    onRename: (mod, newName) => modsProvider.renameMod(mod, newName),
                    isEnabledList: true,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addMod(BuildContext context) async {
    final localization = context.read<LocalizationService>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: ['pak', 'zip'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        if (!mounted) return;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
        
        try {
          for (final file in result.files) {
            if (file.path != null) {
              await Provider.of<ModsProvider>(context, listen: false)
                  .addMod(file.path!);
            }
          }
        } finally {
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate('home.errors.add_mod', {'error': e.toString()}))),
      );
    }
  }
} 