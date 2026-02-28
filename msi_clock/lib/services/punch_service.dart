import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import '../models/punch.dart';
import '../models/soap_config.dart';
import 'soap_service.dart';
import 'logger_service.dart';
import 'punch_database_service.dart';

class PunchService {
  final SoapService _soapService;
  final LoggerService _logger = LoggerService();
  final PunchDatabaseService _database = PunchDatabaseService();
  CameraController? _cameraController;
  bool _isInitialized = false;
  PunchService(SoapConfig config) : _soapService = SoapService(config);
  bool get isOnline => _soapService.isOnline;
  String? get connectionError => _soapService.connectionError;

  /// Checks connectivity to the SOAP server
  /// Returns true if the server is reachable, false otherwise
  /// If forceReconnect is true, it will force a new connection attempt
  Future<bool> checkConnectivity({bool forceReconnect = false}) async {
    return _soapService.checkConnectivity(forceReconnect: forceReconnect);
  }

  Future<void> initializeCamera({bool forceReinit = false}) async {
    if (_isInitialized && !forceReinit) return;
    // If forcing reinitialization, dispose of the current camera first
    if (_isInitialized && forceReinit) {
      await disposeCamera();
    }
    try {
      // Get the list of available cameras
      final cameras = await availableCameras();
      // Find front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      // Initialize the camera controller
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
      _isInitialized = true;
    } catch (e) {
      _cameraController = null;
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> disposeCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
      _isInitialized = false;
    }
  }

  /// Dispose of all resources, including camera and SOAP service
  Future<void> dispose() async {
    await disposeCamera();
    _soapService.dispose(); // Close the HTTP client
  }

  Future<Punch?> recordPunch(
    String employeeId, {
    bool isCameraEnabled = true,
  }) async {
    final punchServiceStartTime = DateTime.now();
    final timestamp = DateTime.now();

    await _logger.logPunch('Recording punch for employee: $employeeId');
    await _logger.logDebug('Punch service started at: $punchServiceStartTime');

    Uint8List? imageData;
    XFile? tempImageFile;
    try {
      final cameraStartTime = DateTime.now();
      // Capture photo if camera is available and enabled
      if (isCameraEnabled &&
          _cameraController != null &&
          _cameraController!.value.isInitialized) {
        await _logger.logDebug('Capturing camera image...');
        tempImageFile = await _cameraController!.takePicture();
        imageData = await tempImageFile.readAsBytes();
        final cameraEndTime = DateTime.now();
        final cameraDuration = cameraEndTime.difference(cameraStartTime);
        await _logger.logDebug(
          'Camera capture completed in ${cameraDuration.inMilliseconds}ms',
        );

        // CRITICAL FIX: Delete the temporary camera file immediately after reading
        try {
          final file = File(tempImageFile.path);
          if (await file.exists()) {
            await file.delete();
            await _logger.logDebug(
              'Deleted temporary camera file: ${tempImageFile.path}',
            );
          }
        } catch (deleteError) {
          await _logger.logWarning(
            'Failed to delete temporary camera file: $deleteError',
          );
        }
      } else if (!isCameraEnabled) {
        await _logger.logDebug('Camera disabled, skipping image capture');
      } else {
        await _logger.logWarning('Camera not initialized');
      }

      final soapStartTime = DateTime.now();
      await _logger.logDebug('Calling SOAP service...');

      // Record punch with SOAP service
      final response = await _soapService.recordPunch(
        employeeId: employeeId,
        punchTime: timestamp,
        imageData: imageData,
        imageTimestamp: timestamp,
      );

      final soapEndTime = DateTime.now();
      final soapDuration = soapEndTime.difference(soapStartTime);
      await _logger.logDebug(
        'SOAP service completed in ${soapDuration.inMilliseconds}ms',
      );

      // Create punch object from response
      final punch = Punch.fromResponse(
        employeeId,
        timestamp,
        response,
        imageData: imageData,
      );

      // Store punch in local database (regardless of sync status)
      try {
        await _database.insertPunch(punch);
        await _logger.logDebug('Punch stored in local database');
      } catch (e) {
        await _logger.logError('Failed to store punch in database: $e');
        // Continue even if database storage fails
      }

      final punchServiceEndTime = DateTime.now();
      final punchServiceDuration = punchServiceEndTime.difference(
        punchServiceStartTime,
      );

      // Check if the response contains an exception
      if (response['exception'] != null && response['exception'] > 0) {
        await _logger.logPunch(
          'Punch failed for employee $employeeId: Exception ${response['exception']}',
        );
      } else {
        await _logger.logPunch(
          'Punch successful for employee $employeeId (${punch.punchType ?? "unknown"}) - Total time: ${punchServiceDuration.inMilliseconds}ms',
        );
      }

      return punch;
    } catch (e) {
      await _logger.logError('Punch error for employee $employeeId: $e');

      // Create offline punch in case of error
      final offlinePunch = Punch(
        employeeId: employeeId,
        timestamp: timestamp,
        imageData: imageData,
        isSynced: false,
      );

      // Store offline punch in local database for later sync
      try {
        await _database.insertPunch(offlinePunch);
        await _logger.logDebug('Offline punch stored in local database');
      } catch (dbError) {
        await _logger.logError(
          'Failed to store offline punch in database: $dbError',
        );
      }

      return offlinePunch;
    }
  }

  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized =>
      _isInitialized && _cameraController?.value.isInitialized == true;

  /// Update SOAP configuration
  /// This allows settings changes to take effect without restarting the app
  Future<void> updateSoapConfig(SoapConfig newConfig) async {
    await _soapService.updateConfig(newConfig);
  }
}
