import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:provider/provider.dart';
import '../providers/mods_provider.dart';
import '../services/localization_service.dart';

class DropTargetOverlay extends StatefulWidget {
  final Widget child;

  const DropTargetOverlay({
    super.key,
    required this.child,
  });

  @override
  State<DropTargetOverlay> createState() => _DropTargetOverlayState();
}

class _DropTargetOverlayState extends State<DropTargetOverlay> {
  bool _isDragging = false;
  final _localization = LocalizationService();

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) async {
        final modsProvider = Provider.of<ModsProvider>(context, listen: false);
        
        // Показываем индикатор загрузки
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          for (final file in details.files) {
            final extension = file.path.toLowerCase();
            if (extension.endsWith('.pak') || 
                extension.endsWith('.zip')) {
              await modsProvider.addMod(file.path);
            }
          }
        } finally {
          if (mounted) {
            Navigator.of(context).pop(); // Закрываем индикатор загрузки
          }
        }
      },
      onDragEntered: (details) {
        setState(() {
          _isDragging = true;
        });
      },
      onDragExited: (details) {
        setState(() {
          _isDragging = false;
        });
      },
      child: Stack(
        children: [
          widget.child,
          if (_isDragging)
            Container(
              color: Colors.blue.withOpacity(0.2),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.file_download,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _localization.translate('drop_target.drop_here'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _localization.translate('drop_target.supported_formats'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 