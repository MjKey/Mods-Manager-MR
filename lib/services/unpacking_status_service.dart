import 'dart:async';
import '../services/localization_service.dart';

class UnpackingStatusService {
  static final UnpackingStatusService _instance = UnpackingStatusService._internal();
  factory UnpackingStatusService() => _instance;
  UnpackingStatusService._internal();

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;
  final LocalizationService _localization = LocalizationService();

  String _currentStatus = '';
  String get currentStatus => _currentStatus;

  void startUnpacking(String fileName) {
    _currentStatus = _localization.translate('unpacking_status.start', {'file': fileName});
    _statusController.add(_currentStatus);
  }

  void updateStatus(String status) {
    _currentStatus = status;
    _statusController.add(_currentStatus);
  }

  void finishUnpacking() {
    _currentStatus = _localization.translate('unpacking_status.complete');
    _statusController.add(_currentStatus);
  }

  void dispose() {
    _statusController.close();
  }
} 