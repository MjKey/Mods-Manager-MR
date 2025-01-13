import 'package:flutter/material.dart';
import '../models/mod.dart';
import 'mod_list_item.dart';
import '../services/localization_service.dart';

class ModListPanel extends StatelessWidget {
  final String title;
  final List<Mod> mods;
  final Function(String) onSearch;
  final Function(Mod) onToggle;
  final Function(Mod, String) onRename;
  final bool isEnabledList;
  static final LocalizationService _localization = LocalizationService();

  const ModListPanel({
    Key? key,
    required this.title,
    required this.mods,
    required this.onSearch,
    required this.onToggle,
    required this.onRename,
    required this.isEnabledList,
  }) : super(key: key);

  Future<void> _handleToggle(BuildContext context, Mod mod) async {
    try {
      await onToggle(mod);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_localization.translate('mod_list_panel.errors.toggle', {'error': e.toString()}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<Mod>(
      onWillAccept: (mod) => mod?.isEnabled != isEnabledList,
      onAccept: (mod) => _handleToggle(context, mod),
      builder: (context, candidateData, rejectedData) {
        return Card(
          margin: const EdgeInsets.all(8.0),
          color: candidateData.isNotEmpty
              ? (isEnabledList ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1))
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: SizedBox(
                        height: 36.0,
                        child: TextField(
                          onChanged: onSearch,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            hintText: _localization.translate('mod_list_panel.search'),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            fillColor: Theme.of(context).colorScheme.surface,
                            filled: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (mods.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Text(
                    isEnabledList 
                      ? _localization.translate('mod_list_panel.empty_list.enabled')
                      : _localization.translate('mod_list_panel.empty_list.disabled'),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mods.length,
                  itemBuilder: (context, index) {
                    final mod = mods[index];
                    return ModListItem(
                      mod: mod,
                      onToggle: () => _handleToggle(context, mod),
                      onRename: (newName) async {
                        try {
                          await onRename(mod, newName);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(_localization.translate('mod_list_panel.errors.toggle', {'error': e.toString()}))),
                          );
                        }
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
} 