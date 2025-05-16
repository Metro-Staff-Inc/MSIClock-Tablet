import 'package:flutter/foundation.dart';
import '../models/punch.dart';
import '../models/soap_config.dart';
import '../services/punch_service.dart';

class PunchProvider extends ChangeNotifier {
  final PunchService _punchService;
  String _currentLanguage = 'en';
  bool _isLoading = false;
  String? _error;
  Punch? _lastPunch;

  PunchProvider(SoapConfig config) : _punchService = PunchService(config);

  String get currentLanguage => _currentLanguage;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Punch? get lastPunch => _lastPunch;
  bool get isOnline => _punchService.isOnline;
  String? get connectionError => _punchService.connectionError;
  bool get isCameraInitialized => _punchService.isCameraInitialized;
  get cameraController => _punchService.cameraController;

  void toggleLanguage() {
    _currentLanguage = _currentLanguage == 'en' ? 'es' : 'en';
    notifyListeners();
  }

  /// Checks connectivity to the SOAP server and updates the online status
  /// If forceReconnect is true, it will force a new connection attempt
  Future<bool> checkConnectivity({bool forceReconnect = false}) async {
    try {
      final isConnected = await _punchService.checkConnectivity(
        forceReconnect: forceReconnect,
      );
      notifyListeners(); // Notify UI to update the online status indicator
      return isConnected;
    } catch (e) {
      // Use a concise error message to prevent layout issues
      _error =
          _currentLanguage == 'en'
              ? 'Failed to check connectivity'
              : 'Error al verificar conexión';
      notifyListeners();
      return false;
    }
  }

  Future<void> initializeCamera({bool forceReinit = false}) async {
    try {
      _error = null;
      await _punchService.initializeCamera(forceReinit: forceReinit);
      notifyListeners();
    } catch (e) {
      // Use a concise error message to prevent layout issues
      _error =
          _currentLanguage == 'en'
              ? 'Failed to initialize camera'
              : 'Error al inicializar cámara';
      notifyListeners();
    }
  }

  Future<void> disposeCamera() async {
    await _punchService.disposeCamera();
    notifyListeners();
  }

  @override
  void dispose() {
    // Dispose of the punch service to clean up resources
    _punchService.dispose();
    super.dispose();
  }

  Future<void> recordPunch(String employeeId) async {
    if (employeeId.isEmpty) {
      _error =
          _currentLanguage == 'en'
              ? 'Please enter employee ID'
              : 'Por favor ingrese ID de empleado';
      notifyListeners();
      return;
    }

    try {
      // Debug: Log start time in PunchProvider
      final providerStartTime = DateTime.now();
      print(
        'TIMING: PunchProvider.recordPunch started at ${providerStartTime.toIso8601String()}',
      );

      _isLoading = true;
      _error = null;
      notifyListeners();

      // Debug: Log when calling PunchService
      print(
        'TIMING: Calling PunchService.recordPunch at ${DateTime.now().toIso8601String()}',
      );
      _lastPunch = await _punchService.recordPunch(employeeId);

      // Debug: Log when response is received from PunchService
      final providerEndTime = DateTime.now();
      final providerDuration = providerEndTime.difference(providerStartTime);
      print(
        'TIMING: PunchService.recordPunch returned at ${providerEndTime.toIso8601String()}',
      );
      print(
        'TIMING: Total time in PunchProvider.recordPunch: ${providerDuration.inMilliseconds}ms',
      );

      // Don't set error message when punch has exception
      // The lastPunch object already contains the status message
      // and will be displayed in the UI
    } catch (e) {
      // Debug: Log error timing
      print(
        'TIMING: Error in PunchProvider.recordPunch at ${DateTime.now().toIso8601String()}',
      );

      // Truncate error message to prevent layout issues
      final errorString = e.toString();
      final truncatedError =
          errorString.length > 50
              ? '${errorString.substring(0, 47)}...'
              : errorString;

      _error =
          _currentLanguage == 'en'
              ? 'Failed to record punch'
              : 'Error al registrar marcación';
      _lastPunch = null;
    } finally {
      _isLoading = false;
      notifyListeners();

      // Debug: Log completion time
      print(
        'TIMING: PunchProvider.recordPunch completed at ${DateTime.now().toIso8601String()}',
      );
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearLastPunch() {
    _lastPunch = null;
    notifyListeners();
  }
}
