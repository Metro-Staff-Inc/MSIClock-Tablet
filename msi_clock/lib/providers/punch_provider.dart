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
    try {
      // First, force a reconnection to ensure we have a fresh connection
      final isConnected = await checkConnectivity(forceReconnect: true);
      if (!isConnected) {
        // If first attempt failed, try again after a short delay
        await Future.delayed(const Duration(seconds: 1));
        final retryResult = await checkConnectivity(forceReconnect: true);
        if (!retryResult) {
          return false;
        }
      }
      return true;
    } catch (e) {
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
      final connectionReady = await prepareForPunch();
      if (!connectionReady) {
      } else {}
      // Record the punch
      final punch = await _punchService.recordPunch(
        employeeId,
        isCameraEnabled: _isCameraEnabled,
      );
      // Set the last punch to display the result to the user
      _lastPunch = punch;
      if (punch != null) {
        // Check if the punch has an exception
        if (punch.hasError) {
          // The punch object contains the exception information
          // which will be displayed in the UI via getStatusMessage()
        }
      } else {
        // Set an error message if no punch was returned
        _error =
            _currentLanguage == 'en'
                ? 'Failed to record punch'
                : 'Error al registrar marcación';
      }
    } catch (e) {
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

  /// Reload SOAP configuration from settings
  /// This allows settings changes to take effect without restarting the app
  Future<void> reloadSoapConfig() async {
    try {
      final newConfig = await AppConfig.getSoapConfig();
      await _punchService.updateSoapConfig(newConfig);
      // Force a reconnection with the new configuration
      await checkConnectivity(forceReconnect: true);
      notifyListeners();
    } catch (e) {
      _error =
          _currentLanguage == 'en'
              ? 'Failed to reload SOAP configuration'
              : 'Error al recargar configuración SOAP';
      notifyListeners();
    }
  }
}
