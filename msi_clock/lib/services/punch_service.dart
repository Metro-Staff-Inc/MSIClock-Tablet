import 'dart:typed_data';
import 'package:camera/camera.dart';
import '../models/punch.dart';
import '../models/soap_config.dart';
import 'soap_service.dart';

class PunchService {
  final SoapService _soapService;
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
      print('Failed to initialize camera: $e');
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

  Future<Punch> recordPunch(String employeeId) async {
    // Debug: Log start time
    final punchServiceStartTime = DateTime.now();
    print(
      'TIMING: PunchService.recordPunch started at ${punchServiceStartTime.toIso8601String()}',
    );

    // Use a single timestamp for both punch and image to ensure they match
    final timestamp = DateTime.now();
    Uint8List? imageData;

    try {
      // Debug: Log camera capture start
      final cameraStartTime = DateTime.now();
      print(
        'TIMING: Camera capture started at ${cameraStartTime.toIso8601String()}',
      );

      // Capture photo if camera is available
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final image = await _cameraController!.takePicture();
        imageData = await image.readAsBytes();

        // Debug: Log camera capture completion
        final cameraEndTime = DateTime.now();
        final cameraDuration = cameraEndTime.difference(cameraStartTime);
        print(
          'TIMING: Camera capture completed at ${cameraEndTime.toIso8601String()}',
        );
        print('TIMING: Camera capture took ${cameraDuration.inMilliseconds}ms');
      } else {
        print('TIMING: Camera not initialized, skipping photo capture');
      }

      // Debug: Log SOAP service call start
      final soapStartTime = DateTime.now();
      print(
        'TIMING: SoapService.recordPunch started at ${soapStartTime.toIso8601String()}',
      );

      // Record punch with SOAP service, passing the exact same timestamp
      // for both punch and image to ensure they match in the system
      final response = await _soapService.recordPunch(
        employeeId: employeeId,
        punchTime: timestamp,
        imageData: imageData,
        // Explicitly pass the same timestamp for image upload to ensure they match
        imageTimestamp: timestamp,
      );

      // Debug: Log SOAP service call completion
      final soapEndTime = DateTime.now();
      final soapDuration = soapEndTime.difference(soapStartTime);
      print(
        'TIMING: SoapService.recordPunch completed at ${soapEndTime.toIso8601String()}',
      );
      print(
        'TIMING: SoapService.recordPunch took ${soapDuration.inMilliseconds}ms',
      );

      // Create punch object from response with the same timestamp
      final punch = Punch.fromResponse(
        employeeId,
        timestamp,
        response,
        imageData: imageData,
      );

      // Debug: Log PunchService completion
      final punchServiceEndTime = DateTime.now();
      final punchServiceDuration = punchServiceEndTime.difference(
        punchServiceStartTime,
      );
      print(
        'TIMING: PunchService.recordPunch completed at ${punchServiceEndTime.toIso8601String()}',
      );
      print(
        'TIMING: Total time in PunchService.recordPunch: ${punchServiceDuration.inMilliseconds}ms',
      );

      return punch;
    } catch (e) {
      // Debug: Log error
      print(
        'TIMING: Error in PunchService.recordPunch at ${DateTime.now().toIso8601String()}: $e',
      );

      // Return offline punch in case of error
      return Punch(
        employeeId: employeeId,
        timestamp: timestamp,
        imageData: imageData,
        isSynced: false,
      );
    }
  }

  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized =>
      _isInitialized && _cameraController?.value.isInitialized == true;
}
