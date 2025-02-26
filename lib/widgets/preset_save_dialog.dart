import 'package:flutter/material.dart';
import '../services/localization_service.dart';

class PresetSaveDialog extends StatefulWidget {
  final List<String> enabledMods;

  const PresetSaveDialog({
    super.key,
    required this.enabledMods,
  });

  @override
  State<PresetSaveDialog> createState() => _PresetSaveDialogState();
}

class _PresetSaveDialogState extends State<PresetSaveDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _localization = LocalizationService();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_localization.translate('presets.save.title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: _localization.translate('presets.save.name_label'),
              icon: const Icon(Icons.bookmark),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: _localization.translate('presets.save.description_label'),
              icon: const Icon(Icons.description),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_localization.translate('presets.save.cancel')),
        ),
        TextButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'description': _descriptionController.text.trim(),
                'enabledMods': widget.enabledMods,
              });
            }
          },
          child: Text(_localization.translate('presets.save.save')),
        ),
      ],
    );
  }
} 