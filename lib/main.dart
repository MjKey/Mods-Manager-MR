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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows) {
    setWindowTitle('Marvel Rivals Mod Manager');
    setWindowMinSize(const Size(800, 600));
    setWindowMaxSize(Size.infinite);
  }
  
  final modManager = ModManager();
  runApp(Phoenix(child: ModManagerApp(modManager: modManager)));
}

class ModManagerApp extends StatelessWidget {
  final ModManager modManager;

  const ModManagerApp({
    super.key,
    required this.modManager,
  });

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
      locale: Locale(modManager.settings.language),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        ...GlobalMaterialLocalizations.delegates,
      ],
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: ModManagerHome(modManager: modManager),
    );
  }
}

class ModManagerHome extends StatefulWidget {
  final ModManager modManager;

  const ModManagerHome({
    super.key,
    required this.modManager,
  });

  @override
  State<ModManagerHome> createState() => _ModManagerHomeState();
}

class _ModManagerHomeState extends State<ModManagerHome> {
  String? gamePath;
  bool _isDragging = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await widget.modManager.loadSettings();
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
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).get('delete_mod')),
        content: Text('${AppLocalizations.of(context).get('delete_mod_confirm')} "${mod.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Удалить'),
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

        await widget.modManager.addMod(
          file,
          onProgress: (progress) {
            if (mounted) {
              progressKey.currentState?.updateProgress(progress);
            }
          },
        );

        if (mounted) {
          Navigator.of(context).pop();
        }

        setState(() {});
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
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
      child: Scaffold(
      appBar: AppBar(
          title: Text(l10n.get('app_title')),
          actions: [
            if (gamePath != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: Text(
                    '${l10n.get('game_folder')}: ${gamePath!}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
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
                }
              },
            ),
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
                child: DropTarget(
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
                        : ListView.builder(
                            itemCount: widget.modManager.mods.length,
                            itemBuilder: (context, index) {
                              final mod = widget.modManager.mods[index];
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
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.transparent,
                                      blurRadius: 4,
                                      spreadRadius: 1,
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
                                  title: Text(
                                    mod.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: widget.modManager.settings.showFileSize
                                      ? Text(mod.formattedSize)
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
            ),
          ],
        ),
        floatingActionButton: gamePath != null
            ? FloatingActionButton(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pak'],
                  );
                  if (result != null) {
                    await _handleFileDrop([result.files.first.path!]);
                  }
                },
                child: const Icon(Icons.add),
              )
            : null,
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

  static _ProgressDialogState? of(BuildContext context) {
    return context.findAncestorStateOfType<_ProgressDialogState>();
  }

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
