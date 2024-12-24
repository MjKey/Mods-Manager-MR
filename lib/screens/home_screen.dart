import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mod.dart';
import '../services/mod_service.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  final String gamePath;

  const HomeScreen({
    super.key,
    required this.gamePath,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Mod> mods = [];
  bool _isDragging = false;
  late ModService _modService;

  @override
  void initState() {
    super.initState();
    _initModService();
  }

  Future<void> _initModService() async {
    final prefs = await SharedPreferences.getInstance();
    _modService = ModService(prefs, widget.gamePath);
    _loadMods();
  }

  Future<void> _loadMods() async {
    final loadedMods = await _modService.loadMods();
    setState(() {
      mods = loadedMods;
    });
  }

  Future<void> _saveMods() async {
    await _modService.saveMods(mods);
  }

  Widget _buildModTags(Mod mod) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Теги:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: ModTag.values.map((tag) {
            final isSelected = mod.tags.contains(tag);
            return FilterChip(
              label: Text(tag.getLocalizedLabel(AppLocalizations.of(context).get)),
              selected: isSelected,
              selectedColor: Colors.blue.withOpacity(0.2),
              checkmarkColor: Colors.blue,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    mod.tags.add(tag);
                  } else {
                    mod.tags.remove(tag);
                  }
                  _saveMods();
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _exportMods() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      try {
        final exportPath = await _modService.exportMods(mods, result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Моды экспортированы в: $exportPath')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при экспорте: $e')),
        );
      }
    }
  }

  Future<void> _importMods() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mrmm'],
    );

    if (result != null) {
      try {
        final importedMods = await _modService.importMods(
          result.files.single.path!,
          // Здесь нужно указать директорию для модов
          Directory.current.path,
        );
        setState(() {
          mods.addAll(importedMods);
          _saveMods();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Импортировано ${importedMods.length} модов')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при импорте: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Marvel Rivals Mod Manager'),
        actions: [
          Tooltip(
            message: 'Экспорт модов',
            child: TextButton.icon(
              icon: Icon(Icons.file_upload, color: Colors.white),
              label: Text('Экспорт', style: TextStyle(color: Colors.white)),
              onPressed: _exportMods,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Импорт модов',
            child: TextButton.icon(
              icon: Icon(Icons.file_download, color: Colors.white),
              label: Text('Импорт', style: TextStyle(color: Colors.white)),
              onPressed: _importMods,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // Открытие настроек
            },
          ),
        ],
      ),
      body: DropTarget(
        onDragDone: (details) async {
          // Обработка перетаскивания файл��в
        },
        onDragEntered: (details) {
          setState(() => _isDragging = true);
        },
        onDragExited: (details) {
          setState(() => _isDragging = false);
        },
        child: Stack(
          children: [
            ListView.builder(
              itemCount: mods.length,
              itemBuilder: (context, index) {
                final mod = mods[index];
                return Card(
                  child: ListTile(
                    title: Text(mod.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Размер: ${mod.formattedSize}'),
                        _buildModTags(mod),
                      ],
                    ),
                    trailing: Switch(
                      value: mod.isEnabled,
                      onChanged: (value) {
                        setState(() {
                          mod.isEnabled = value;
                          _saveMods();
                        });
                      },
                    ),
                  ),
                );
              },
            ),
            if (_isDragging)
              Container(
                color: Colors.blue.withOpacity(0.2),
                child: Center(
                  child: Text(
                    'Перетащите файлы модов сюда',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Добавление новых модов
        },
        child: Icon(Icons.add),
      ),
    );
  }
} 