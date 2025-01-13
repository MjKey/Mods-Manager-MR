import 'package:flutter/material.dart';
import '../services/unpacking_status_service.dart';
import '../services/localization_service.dart';

class UnpackingProgressDialog extends StatelessWidget {
  static final LocalizationService _localization = LocalizationService();
  const UnpackingProgressDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: UnpackingStatusService().statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? _localization.translate('unpacking_progress.default_status');
        
        return Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, 
                  size: 48, 
                  color: Colors.amber
                ),
                const SizedBox(height: 16),
                Text(
                  _localization.translate('unpacking_progress.title'),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _localization.translate('unpacking_progress.message'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  status,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
    );
  }
} 