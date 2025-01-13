import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mod.dart';
import '../providers/mods_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/localization_service.dart';

class ModListItem extends StatelessWidget {
  final Mod mod;
  final VoidCallback onToggle;
  final Function(String) onRename;
  static final LocalizationService _localization = LocalizationService();

  ModListItem({
    Key? key,
    required this.mod,
    required this.onToggle,
    required this.onRename,
  }) : super(key: key);

  Future<void> _showEditDialog(BuildContext context) async {
    final nameController = TextEditingController(text: mod.name);
    final nexusUrlController = TextEditingController(text: mod.nexusUrl ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_localization.translate('mod_list_item.dialogs.edit.title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: _localization.translate('mod_list_item.dialogs.edit.name_label'),
                icon: const Icon(Icons.edit),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nexusUrlController,
              decoration: InputDecoration(
                labelText: _localization.translate('mod_list_item.dialogs.edit.nexus_url_label'),
                icon: const Icon(Icons.link),
                hintText: _localization.translate('mod_list_item.dialogs.edit.nexus_url_hint'),
              ),
            ),
            if (mod.nexusUrl != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await Provider.of<ModsProvider>(context, listen: false)
                        .updateModFromNexus(mod, mod.nexusUrl!);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.refresh),
                label: Text(_localization.translate('mod_list_item.dialogs.edit.update_info')),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localization.translate('mod_list_item.dialogs.edit.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text,
                'nexusUrl': nexusUrlController.text,
              });
            },
            child: Text(_localization.translate('mod_list_item.dialogs.edit.save')),
          ),
        ],
      ),
    );

    if (result != null) {
      print('Результат диалога: $result');
      if (result['name'] != mod.name) {
        print('Переименование мода: ${mod.name} -> ${result['name']}');
        onRename(result['name']!);
      }
      if (result['nexusUrl'] != mod.nexusUrl) {
        print('Обновление Nexus URL: ${mod.nexusUrl} -> ${result['nexusUrl']}');
        await Provider.of<ModsProvider>(context, listen: false)
            .updateModFromNexus(mod, result['nexusUrl']!);
      }
    }
  }

  Future<String?> _showAddTagDialog(BuildContext context) async {
    final tagController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_localization.translate('mod_list_item.dialogs.add_tag.title')),
        content: TextField(
          controller: tagController,
          decoration: InputDecoration(
            labelText: _localization.translate('mod_list_item.dialogs.add_tag.label'),
            hintText: _localization.translate('mod_list_item.dialogs.add_tag.hint'),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localization.translate('mod_list_item.dialogs.add_tag.cancel')),
          ),
          TextButton(
            onPressed: () {
              if (tagController.text.isNotEmpty) {
                Navigator.pop(context, tagController.text);
              }
            },
            child: Text(_localization.translate('mod_list_item.dialogs.add_tag.add')),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    try {
      final hasUpdate = await Provider.of<ModsProvider>(context, listen: false)
          .checkModUpdate(mod);
      
      if (!context.mounted) return;

      if (hasUpdate) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_localization.translate('mod_list_item.dialogs.update.title')),
            content: Text(_localization.translate('mod_list_item.dialogs.update.message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_localization.translate('mod_list_item.dialogs.update.later')),
              ),
              ElevatedButton(
                onPressed: () async {
                  await launchUrl(Uri.parse(mod.nexusUrl!));
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Text(_localization.translate('mod_list_item.dialogs.update.download')),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_localization.translate('mod_list_item.notifications.no_updates'))),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_localization.translate('mod_list_item.errors.update_check', {'error': e.toString()}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<Mod>(
      data: mod,
      feedback: Material(
        elevation: 4,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.4,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            mod.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: mod.nexusImageUrl != null
              ? Image.network(
                  mod.nexusImageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/img/cover.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  'assets/img/cover.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _showEditDialog(context),
                child: Text(mod.name),
              ),
            ),
            if (mod.version.isNotEmpty)
              Text(
                'v${mod.version}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            if (mod.nexusUrl != null)
              IconButton(
                icon: const Icon(Icons.update, size: 20),
                onPressed: () => _checkForUpdates(context),
                tooltip: _localization.translate('mod_list_item.tooltips.check_updates'),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              if (mod.character != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text(
                      mod.character!,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    visualDensity: VisualDensity.compact,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ...mod.tags.map((tag) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(
                    tag,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  onDeleted: () => Provider.of<ModsProvider>(context, listen: false).removeTag(mod, tag),
                  deleteIconColor: Colors.red.withOpacity(0.7),
                  deleteIcon: const Icon(Icons.close, size: 14),
                ),
              )),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () async {
                  final tag = await _showAddTagDialog(context);
                  if (tag != null) {
                    await Provider.of<ModsProvider>(context, listen: false).addTag(mod, tag);
                  }
                },
                tooltip: _localization.translate('mod_list_item.tooltips.add_tag'),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            mod.isEnabled ? Icons.arrow_back : Icons.arrow_forward,
            color: mod.isEnabled ? Colors.red : Colors.green,
          ),
          onPressed: onToggle,
          tooltip: mod.isEnabled 
            ? _localization.translate('mod_list_item.tooltips.disable')
            : _localization.translate('mod_list_item.tooltips.enable'),
        ),
      ),
    );
  }
} 