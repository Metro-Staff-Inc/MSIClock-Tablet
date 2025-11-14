import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/punch.dart';
import '../models/soap_config.dart';
import '../services/punch_service.dart';
import '../config/app_config.dart';

class PunchProvider extends ChangeNotifier {
  final PunchService _punchService;
  String _currentLanguage = 'en';
  bool _isLoading = false;
  String? _error;
  Punch? _lastPunch;
  bool _isCameraEnabled = true;
  String? _selectedImagePath;
  File? _selectedImageFile;

  PunchProvider(SoapConfig config) : _punchService = PunchService(config);

  String get currentLanguage => _currentLanguage;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Punch? get lastPunch => _lastPunch;
  bool get isOnline => _punchService.isOnline;
  String? get connectionError => _punchService.connectionError;
  bool get isCameraInitialized => _punchService.isCameraInitialized;
  get cameraController => _punchService.cameraController;
  bool get isCameraEnabled => _isCameraEnabled;
  String? get selectedImagePath => _selectedImagePath;
  File? get selectedImageFile => _selectedImageFile;

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

  /// Prepares the SOAP connection for an immediate punch operation
  /// This is especially useful after coming out of sleep mode
  Future<bool> prepareForPunch() async {
    print(
      'PUNCH DEBUG: Preparing for punch operation at ${DateTime.now().toIso8601String()}',
    );
    try {
      // First, force a reconnection to ensure we have a fresh connection
      final isConnected = await checkConnectivity(forceReconnect: true);

      if (!isConnected) {
        print('PUNCH DEBUG: First connection attempt failed, retrying');
        // If first attempt failed, try again after a short delay
        await Future.delayed(const Duration(seconds: 1));
        final retryResult = await checkConnectivity(forceReconnect: true);

        if (!retryResult) {
          print('PUNCH DEBUG: Second connection attempt also failed');
          return false;
        }
      }

      print('PUNCH DEBUG: Connection established, ready for punch operation');
      return true;
    } catch (e) {
      print('PUNCH DEBUG: Error preparing for punch: $e');
      return false;
    }
  }

  /// Load camera settings from AppConfig
  Future<void> loadCameraSettings() async {
    try {
      _isCameraEnabled = await AppConfig.isCameraEnabled();
      _selectedImagePath = await AppConfig.getSelectedImagePath();

      // Load the selected image file if path is available
      if (_selectedImagePath != null) {
        _selectedImageFile = File(_selectedImagePath!);
        if (!await _selectedImageFile!.exists()) {
          _selectedImageFile = null;
        }
      } else {
        _selectedImageFile = null;
      }

      notifyListeners();
    } catch (e) {
      // Default to camera enabled if there's an error
      _isCameraEnabled = true;
      _selectedImagePath = null;
      _selectedImageFile = null;
    }
  }

  /// Update camera settings
  Future<void> updateCameraSettings({
    required bool isEnabled,
    String? selectedImagePath,
  }) async {
    try {
      await AppConfig.updateCameraSettings(
        isEnabled: isEnabled,
        selectedImagePath: selectedImagePath,
      );

      _isCameraEnabled = isEnabled;

      if (selectedImagePath != null) {
        _selectedImagePath = selectedImagePath;
        _selectedImageFile = File(selectedImagePath);
        if (!await _selectedImageFile!.exists()) {
          _selectedImageFile = null;
        }
      }

      notifyListeners();
    } catch (e) {
      _error =
          _currentLanguage == 'en'
              ? 'Failed to update camera settings'
              : 'Error al actualizar configuración de cámara';
      notifyListeners();
    }
  }

  Future<void> initializeCamera({bool forceReinit = false}) async {
    try {
      _error = null;

      // Load camera settings first
      await loadCameraSettings();

      // Only initialize camera if it's enabled
      if (_isCameraEnabled) {
        await _punchService.initializeCamera(forceReinit: forceReinit);
      } else {}

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
      _isLoading = true;
      _error = null;
      notifyListeners();

      // First, ensure we have connectivity and the connection is ready for a punch
      print(
        'PUNCH DEBUG: Preparing connection for punch at ${DateTime.now().toIso8601String()}',
      );
      final connectionReady = await prepareForPunch();

      if (!connectionReady) {
        print(
          'PUNCH DEBUG: Connection preparation failed, punch may not reach server',
        );
      } else {
        print('PUNCH DEBUG: Connection ready, proceeding with punch');
      }

      // Record the punch
      print(
        'PUNCH DEBUG: Recording punch for employee $employeeId at ${DateTime.now().toIso8601String()}',
      );
      _lastPunch = await _punchService.recordPunch(
        employeeId,
        isCameraEnabled: _isCameraEnabled,
      );
      print(
        'PUNCH DEBUG: Punch recorded with result: ${_lastPunch?.isSynced == true ? "SYNCED" : "NOT SYNCED"}',
      );

      // Don't set error message when punch has exception
      // The lastPunch object already contains the status message
      // and will be displayed in the UI
    } catch (e) {
      // Truncate error message to prevent layout issues
      final errorString = e.toString();
      final truncatedError =
          errorString.length > 50
              ? '${errorString.substring(0, 47)}...'
              : errorString;

      print('PUNCH DEBUG: Error recording punch: $truncatedError');
      _error =
          _currentLanguage == 'en'
              ? 'Failed to record punch'
              : 'Error al registrar marcación';
      _lastPunch = null;
    } finally {
      _isLoading = false;
      notifyListeners();
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
