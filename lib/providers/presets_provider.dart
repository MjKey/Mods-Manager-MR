import 'package:flutter/foundation.dart';
import '../models/preset.dart';
import '../models/mod.dart';
import '../services/presets_service.dart';
import '../services/localization_service.dart';
import 'mods_provider.dart';

class PresetsProvider with ChangeNotifier {
  List<ModPreset> _presets = [];
  bool _isLoading = false;
  final LocalizationService _localization = LocalizationService();

  List<ModPreset> get presets => _presets;
  bool get isLoading => _isLoading;

  Future<void> loadPresets() async {
    try {
      _isLoading = true;
      notifyListeners();

      _presets = await PresetsService.loadPresets();
      notifyListeners();
    } catch (e) {
      debugPrint(_localization.translate('presets.errors.load', {'error': e.toString()}));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> savePreset(String name, String? description, List<String> enabledMods) async {
    try {
      // Проверяем, не пустое ли имя
      if (name.trim().isEmpty) {
        throw Exception(_localization.translate('presets.errors.empty_name'));
      }

      // Проверяем, нет ли уже пресета с таким именем
      if (_presets.any((preset) => preset.name == name)) {
        throw Exception(_localization.translate('presets.errors.name_exists'));
      }

      final preset = ModPreset(
        name: name,
        enabledMods: enabledMods,
        createdAt: DateTime.now(),
        description: description,
      );

      await PresetsService.savePreset(preset);
      _presets.insert(0, preset); // Добавляем в начало списка
      notifyListeners();
    } catch (e) {
      debugPrint(_localization.translate('presets.errors.save', {'error': e.toString()}));
      rethrow;
    }
  }

  Future<void> deletePreset(ModPreset preset) async {
    try {
      await PresetsService.deletePreset(preset.name);
      _presets.remove(preset);
      notifyListeners();
    } catch (e) {
      debugPrint(_localization.translate('presets.errors.delete', {'error': e.toString()}));
      rethrow;
    }
  }

  Future<void> applyPreset(ModPreset preset, ModsProvider modsProvider) async {
    try {
      // Сначала отключаем все включенные моды
      final enabledMods = modsProvider.enabledMods;
      for (final mod in enabledMods) {
        await modsProvider.toggleMod(mod);
      }

      // Затем включаем моды из пресета
      for (final modName in preset.enabledMods) {
        final mod = modsProvider.mods.firstWhere(
          (m) => m.name == modName,
          orElse: () => Mod(
            name: modName,
            description: '',
            pakPath: '',
            unpackedPath: '',
            installDate: DateTime.now(),
            version: '',
            isEnabled: false
          ),
        );
        if (!mod.isEnabled) {
          await modsProvider.toggleMod(mod);
        }
      }
    } catch (e) {
      debugPrint(_localization.translate('presets.errors.load', {'error': e.toString()}));
      rethrow;
    }
  }
} 