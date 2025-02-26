import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/presets_provider.dart';
import '../services/localization_service.dart';
import 'package:intl/intl.dart';

class PresetLoadDialog extends StatelessWidget {
  final _localization = LocalizationService();

  PresetLoadDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PresetsProvider>(
      builder: (context, presetsProvider, _) {
        if (presetsProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (presetsProvider.presets.isEmpty) {
          return Center(
            child: Text(_localization.translate('presets.load.no_presets')),
          );
        }

        return ListView.builder(
          itemCount: presetsProvider.presets.length,
          itemBuilder: (context, index) {
            final preset = presetsProvider.presets[index];
            return ListTile(
              title: Text(preset.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preset.description != null && preset.description!.isNotEmpty)
                    Text(preset.description!),
                  Text(_localization.translate('presets.load.created_at', {
                    'date': DateFormat.yMd().add_Hm().format(preset.createdAt),
                  })),
                  Text(_localization.translate('presets.load.enabled_mods', {
                    'count': preset.enabledMods.length.toString(),
                  })),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(_localization.translate('presets.confirm.delete.title')),
                          content: Text(_localization.translate('presets.confirm.delete.message', {
                            'name': preset.name,
                          })),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(_localization.translate('presets.confirm.delete.cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: Text(_localization.translate('presets.confirm.delete.confirm')),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await presetsProvider.deletePreset(preset);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(_localization.translate('presets.messages.deleted'))),
                          );
                        }
                      }
                    },
                    tooltip: _localization.translate('presets.load.delete'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(_localization.translate('presets.confirm.load.title')),
                          content: Text(_localization.translate('presets.confirm.load.message')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(_localization.translate('presets.confirm.load.cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(_localization.translate('presets.confirm.load.confirm')),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        Navigator.pop(context, preset);
                      }
                    },
                    tooltip: _localization.translate('presets.load.load'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
} 