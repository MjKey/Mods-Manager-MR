import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'models/mod_manager.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'models/mod.dart';
import 'screens/settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'l10n/app_localizations.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

enum ModSort {
  addDate,
  name,
  size;

  String getLocalizedLabel(String Function(String) getLocalized) {
    switch (this) {
      case ModSort.addDate:
        return getLocalized('sort_by_date');
      case ModSort.name:
        return getLocalized('sort_by_name');
      case ModSort.size:
        return getLocalized('sort_by_size');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows) {
    setWindowTitle('Marvel Rivals Mod Manager');
    setWindowMinSize(const Size(800, 600));
    setWindowMaxSize(Size.infinite);
  }
  
  final modManager = ModManager();
  await modManager.loadSettings();
  
  runApp(Phoenix(child: ModManagerApp(modManager: modManager)));
}

class ModManagerApp extends StatefulWidget {
  final ModManager modManager;

  const ModManagerApp({
    super.key,
    required this.modManager,
  });

  @override
  State<ModManagerApp> createState() => _ModManagerAppState();
}

class _ModManagerAppState extends State<ModManagerApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marvel Rivals Mod Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(widget.modManager.settings.language),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: ModManagerHome(
        modManager: widget.modManager,
        onSettingsChanged: () => setState(() {}),
      ),
    );
  }
}

class ModManagerHome extends StatefulWidget {
  final ModManager modManager;
  final VoidCallback onSettingsChanged;

  const ModManagerHome({
    super.key,
    required this.modManager,
    required this.onSettingsChanged,
  });

  @override
  State<ModManagerHome> createState() => _ModManagerHomeState();
}

class _ModManagerHomeState extends State<ModManagerHome> {
  String? gamePath;
  bool _isDragging = false;
  bool _hasUnsavedChanges = false;
  ModSort _currentSort = ModSort.addDate;
  bool _sortAscending = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Mod> get _filteredAndSortedMods {
    final mods = List<Mod>.from(widget.modManager.mods);
    
    // Фильтрация
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      if (query.isNotEmpty) {
        mods.removeWhere((mod) {
          final displayNameMatch = mod.displayName.toLowerCase().contains(query);
          final tagsMatch = mod.tags.any((tag) => 
            tag.getLocalizedLabel(AppLocalizations.of(context).get).toLowerCase().contains(query)
          );
          return !displayNameMatch && !tagsMatch;
        });
      }
    }

    // Сортировка
    switch (_currentSort) {
      case ModSort.addDate:
        mods.sort((a, b) => _sortAscending 
          ? a.addedDate.compareTo(b.addedDate)
          : b.addedDate.compareTo(a.addedDate));
      case ModSort.name:
        mods.sort((a, b) => _sortAscending 
          ? a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase())
          : b.displayName.toLowerCase().compareTo(a.displayName.toLowerCase()));
      case ModSort.size:
        mods.sort((a, b) => _sortAscending 
          ? a.fileSize.compareTo(b.fileSize)
          : b.fileSize.compareTo(a.fileSize));
    }
    return mods;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() {
      gamePath = widget.modManager.gamePath;
    });
  }

  Future<void> _selectGameFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).get('select_game_folder'),
    );

    if (result != null) {
      if (widget.modManager.isValidGamePath(result)) {
        await widget.modManager.setGamePath(result);
        setState(() {
          gamePath = result;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Выбрана неверная папка. Пожалуйста, выберите папку, где установлена Marvel Rivals'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<bool> _confirmDelete(Mod mod) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.get('delete_mod')),
        content: Text('${l10n.get('delete_mod_confirm')} "${mod.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(l10n.get('delete')),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _handleFileDrop(List<String> files) async {
    for (final file in files) {
      try {
        final progressKey = GlobalKey<_ProgressDialogState>();
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _ProgressDialog(
              key: progressKey,
              title: AppLocalizations.of(context).get('adding_mod'),
              message: '${AppLocalizations.of(context).get('copying_file')} ${path.basename(file)}...',
            ),
          );
        }

        try {
          await widget.modManager.addMod(
            file,
            onProgress: (progress) {
              if (mounted) {
                progressKey.currentState?.updateProgress(progress);
              }
            },
          );
          
          if (mounted) {
            Navigator.of(context).pop(); // Закрываем диалог прогресса
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop(); // Закрываем диалог прогресса
          }

          if (e is ModManagerException && e.toString() == 'mod_exists') {
            final l10n = AppLocalizations.of(context);
            final shouldReplace = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.get('mod_exists')),
                content: Text(l10n.get('mod_exists_desc')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.get('cancel')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: Text(l10n.get('replace')),
                  ),
                ],
              ),
            );

            if (shouldReplace == true) {
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => _ProgressDialog(
                    key: progressKey,
                    title: l10n.get('adding_mod'),
                    message: '${l10n.get('copying_file')} ${path.basename(file)}...',
                  ),
                );
              }

              await widget.modManager.addMod(
                file,
                onProgress: (progress) {
                  if (mounted) {
                    progressKey.currentState?.updateProgress(progress);
                  }
                },
                replace: true,
              );
              
              if (mounted) {
                Navigator.of(context).pop(); // Закрываем диалог прогресса
              }
            }
          } else {
            rethrow;
          }
        }

        setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).get('close_app')),
        content: Text(AppLocalizations.of(context).get('unsaved_changes')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).get('cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).get('close')),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: gamePath != null && _searchQuery.isNotEmpty
                ? TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.get('search_placeholder'),
                      border: InputBorder.none,
                      hintStyle: const TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    autofocus: true,
                  )
                : Text(l10n.get('app_title')),
              actions: [
                if (gamePath != null) ...[
                  IconButton(
                    icon: Icon(_searchQuery.isEmpty ? Icons.search : Icons.close),
                    tooltip: l10n.get('search_mods'),
                    onPressed: () {
                      setState(() {
                        if (_searchQuery.isNotEmpty) {
                          _searchQuery = '';
                          _searchController.clear();
                        } else {
                          _searchController.text = '';
                          _searchQuery = '';
                          Future.delayed(Duration.zero, () {
                            setState(() {
                              _searchQuery = ' '; // Активируем поле поиска
                            });
                          });
                        }
                      });
                    },
                  ),
                  if (gamePath != null)
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: l10n.get('add_mod'),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pak'],
                        );
                        if (result != null) {
                          await _handleFileDrop([result.files.first.path!]);
                        }
                      },
                    ),
                  PopupMenuButton<ModSort>(
                    tooltip: l10n.get('sort_by'),
                    icon: Icon(Icons.sort),
                    onSelected: (ModSort sort) {
                      setState(() {
                        if (_currentSort == sort) {
                          _sortAscending = !_sortAscending;
                        } else {
                          _currentSort = sort;
                          _sortAscending = true;
                        }
                      });
                    },
                    itemBuilder: (context) => ModSort.values.map((sort) => PopupMenuItem(
                      value: sort,
                      child: Row(
                        children: [
                          Icon(
                            _currentSort == sort
                              ? _sortAscending ? Icons.arrow_upward : Icons.arrow_downward
                              : Icons.sort,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(sort.getLocalizedLabel(l10n.get)),
                        ],
                      ),
                    )).toList(),
                  ),
                  PopupMenuButton<String>(
                    tooltip: l10n.get('play_game'),
                    icon: const Icon(Icons.play_circle_filled, color: Colors.green),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'steam',
                        child: Row(
                          children: [
                            const Icon(Icons.sports_esports, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(l10n.get('play_with_steam')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'launcher',
                        child: Row(
                          children: [
                            const Icon(Icons.rocket_launch, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(l10n.get('play_with_launcher')),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      try {
                        if (value == 'steam') {
                          await widget.modManager.launchGameSteam();
                        } else {
                          await widget.modManager.launchGameLauncher();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  Tooltip(
                    message: l10n.get('export_mods'),
                    child: TextButton.icon(
                      icon: const Icon(Icons.file_upload, color: Colors.white),
                      label: Text(l10n.get('export'), style: const TextStyle(color: Colors.white)),
                      onPressed: () async {
                        final result = await FilePicker.platform.getDirectoryPath();
                        if (result != null) {
                          try {
                            final exportPath = await widget.modManager.exportMods(result);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${l10n.get('mods_exported_to')}: $exportPath')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${l10n.get('export_error')}: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: l10n.get('import_mods'),
                    child: TextButton.icon(
                      icon: const Icon(Icons.file_download, color: Colors.white),
                      label: Text(l10n.get('import'), style: const TextStyle(color: Colors.white)),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['mrmm'],
                        );
                        if (result != null) {
                          try {
                            final importedMods = await widget.modManager.importMods(result.files.single.path!);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${l10n.get('imported_mods_count')}: ${importedMods.length}')),
                              );
                              setState(() {});
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${l10n.get('import_error')}: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(modManager: widget.modManager),
                        ),
                      );
                      if (result == true) {
                        setState(() {});
                        widget.onSettingsChanged();
                      }
                    },
                  ),
                ],
              ],
            ),
            body: Column(
              children: [
                if (gamePath == null)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.get('welcome')),
                          const SizedBox(height: 8),
                          Text(l10n.get('start_instruction')),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.folder_open),
                            label: Text(l10n.get('select_game_folder')),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            onPressed: _selectGameFolder,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Stack(
                      children: [
                        DropTarget(
                          onDragDone: (detail) async {
                            await _handleFileDrop(detail.files.map((e) => e.path).toList());
                          },
                          onDragEntered: (detail) {
                            setState(() => _isDragging = true);
                          },
                          onDragExited: (detail) {
                            setState(() => _isDragging = false);
                          },
                          child: Container(
                            color: _isDragging ? Colors.blue.withOpacity(0.2) : null,
                            child: widget.modManager.mods.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.get('drag_drop_instruction'),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                )
                              : _filteredAndSortedMods.isEmpty
                                ? Center(
                                    child: Text(
                                      l10n.get('no_mods_found'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _filteredAndSortedMods.length,
                                    itemBuilder: (context, index) {
                                      final mod = _filteredAndSortedMods[index];
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: mod.isEnabled 
                                                  ? Colors.green.withOpacity(0.1)
                                                  : Colors.transparent,
                                              blurRadius: 2,
                                              spreadRadius: 0.5,
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          leading: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 300),
                                            transitionBuilder: (Widget child, Animation<double> animation) {
                                              return ScaleTransition(scale: animation, child: child);
                                            },
                                            child: Icon(
                                              Icons.extension,
                                              key: ValueKey(mod.isEnabled),
                                              color: mod.isEnabled ? Colors.green : Colors.grey,
                                            ),
                                          ),
                                          title: InkWell(
                                            onTap: () async {
                                              final TextEditingController controller = TextEditingController(text: mod.displayName);
                                              final newName = await showDialog<String>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text(l10n.get('rename_mod')),
                                                  content: TextField(
                                                    controller: controller,
                                                    decoration: InputDecoration(
                                                      labelText: l10n.get('mod_name'),
                                                      hintText: l10n.get('enter_new_name'),
                                                    ),
                                                    autofocus: true,
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: Text(l10n.get('cancel')),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, controller.text),
                                                      child: Text(l10n.get('save')),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (newName != null && newName.isNotEmpty) {
                                                setState(() {
                                                  mod.displayName = newName;
                                                  widget.modManager.saveSettings();
                                                });
                                              }
                                            },
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    mod.displayName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                Icon(Icons.edit, size: 16, color: Colors.grey),
                                              ],
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${l10n.get('file_name')}: ${mod.name}'),
                                              if (widget.modManager.settings.showFileSize)
                                                Text(mod.formattedSize),
                                              if (mod.tags.isNotEmpty)
                                                Wrap(
                                                  spacing: 4,
                                                  children: mod.tags.map((tag) {
                                                    return Chip(
                                                      label: Text(tag.getLocalizedLabel(l10n.get)),
                                                      onDeleted: () {
                                                        setState(() {
                                                          mod.tags.remove(tag);
                                                          widget.modManager.saveSettings();
                                                        });
                                                      },
                                                    );
                                                  }).toList(),
                                                ),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.label),
                                                tooltip: l10n.get('add_tags'),
                                                onPressed: () async {
                                                  final selectedTags = await showDialog<Set<ModTag>>(
                                                    context: context,
                                                    builder: (context) => TagSelectionDialog(
                                                      currentTags: mod.tags,
                                                    ),
                                                  );
                                                  if (selectedTags != null) {
                                                    setState(() {
                                                      mod.tags
                                                        ..clear()
                                                        ..addAll(selectedTags);
                                                      widget.modManager.saveSettings();
                                                    });
                                                  }
                                                },
                                              ),
                                              Switch(
                                                value: mod.isEnabled,
                                                onChanged: (value) async {
                                                  try {
                                                    await widget.modManager.toggleMod(mod);
                                                    setState(() {});
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(e.toString()),
                                                          backgroundColor: Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                color: Colors.red,
                                                onPressed: () async {
                                                  if (await _confirmDelete(mod)) {
                                                    try {
                                                      await widget.modManager.deleteMod(mod);
                                                      setState(() {});
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('${l10n.get('error_deleting')}: ${e.toString()}'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        if (_isDragging)
                          AnimatedOpacity(
                            opacity: _isDragging ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              color: Colors.black.withOpacity(0.7),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.file_download,
                                      size: 64,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.get('drop_files_here'),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProgressDialog extends StatefulWidget {
  final String title;
  final String message;

  const _ProgressDialog({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  double _progress = 0;

  void updateProgress(double value) {
    setState(() {
      _progress = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toStringAsFixed(1)}%'),
        ],
      ),
    );
  }
}

class TagSelectionDialog extends StatefulWidget {
  final Set<ModTag> currentTags;

  const TagSelectionDialog({
    super.key,
    required this.currentTags,
  });

  @override
  State<TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<TagSelectionDialog> {
  late Set<ModTag> selectedTags;

  @override
  void initState() {
    super.initState();
    selectedTags = Set.from(widget.currentTags);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.get('select_tags')),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ModTag.values.map((tag) {
          return FilterChip(
            label: Text(tag.getLocalizedLabel(l10n.get)),
            selected: selectedTags.contains(tag),
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  selectedTags.add(tag);
                } else {
                  selectedTags.remove(tag);
                }
              });
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.get('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(selectedTags),
          child: Text(l10n.get('save')),
        ),
      ],
    );
  }
}
