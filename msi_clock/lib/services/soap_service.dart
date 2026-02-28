// =============================================================================
// IMPORTANT: Date Format Fix for Early Punch Validation
// =============================================================================
// The server expects dates in the C# DateTime.ToString() default format:
// MM/dd/yyyy hh:mm:ss tt (e.g., "1/30/2026 01:04:10 PM")
//
// Previously, the application was sending dates in ISO 8601 format:
// yyyy-MM-ddTHH:mm:ss.SSSZ (e.g., "2026-01-30T13:04:10.206Z")
//
// This caused issues with the server's DateTime.Parse() method when validating
// if a punch was before the allowed shift start time. The server was not
// correctly identifying early punches, allowing them through when they should
// have been blocked.
//
// The fix implemented:
// 1. Added a new _formatTimestampForCSharp() method to format dates in C# style
// 2. Updated all SOAP service calls to use this format instead of ISO 8601
// 3. Added debug logging to verify the format conversion
//
// Date: 2026-01-30
// =============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/soap_config.dart';
import 'power_saving_manager.dart';

class SoapService {
  SoapConfig config;
  bool _isOnline = false;
  String? _connectionError;
  // Getters for config properties
  String get endpoint => config.currentEndpoint;
  String get username => config.username;
  String get password => config.password;
  String get clientId => config.clientId;
  Duration get timeout => config.timeout;
  // Cache for employee information to reduce redundant lookups
  // Each entry includes a timestamp for expiration
  final Map<String, Map<String, dynamic>> _employeeCache = {};
  // Cache expiration duration - 16 hours as requested
  final Duration _cacheExpiration = const Duration(hours: 16);
  // Cache for response data to avoid redundant parsing
  final Map<String, Map<String, dynamic>> _responseCache = {};
  // Response cache expiration - 5 seconds
  final Duration _responseCacheExpiration = const Duration(seconds: 5);
  // HTTP client for connection pooling
  late http.Client _httpClient;
  bool _isClientInitialized = false;
  // Heartbeat timer
  Timer? _heartbeatTimer;
  // Power saving manager
  final PowerSavingManager _powerSavingManager = PowerSavingManager();
  // Subscription to sleep mode state changes
  StreamSubscription? _sleepModeSubscription;
  SoapService(this.config) {
    // Initialize the HTTP client
    _initializeHttpClient();
    // Check connectivity before starting heartbeat
    Future.microtask(() async {
      final isConnected = await checkConnectivity();
      if (isConnected) {
        _startHeartbeat();
      }
    });
    // Listen to sleep mode state changes
    _sleepModeSubscription = _powerSavingManager.sleepModeStateStream.listen((
      isSleepModeActive,
    ) {
      // If sleep mode is deactivated (device waking up), immediately check connectivity
      if (!isSleepModeActive) {
        // Force a reconnection to ensure we have a fresh connection
        checkConnectivity(forceReconnect: true).then((isConnected) {
          if (isConnected) {
            // Send an immediate heartbeat to ensure the connection is fully established
            _sendHeartbeatRosterHello();
          }
        });
      }
    });
  }
  // Initialize or reset the HTTP client
  void _initializeHttpClient() {
    // Close existing client if it exists
    if (_isClientInitialized) {
      try {
        _httpClient.close();
      } catch (e) {}
    }
    // Create a new client
    _httpClient = http.Client();
    _isClientInitialized = true;
  }

  bool get isOnline => _isOnline;
  String? get connectionError => _connectionError;
  // Start the heartbeat timer to keep the connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Get the heartbeat interval from the power saving manager
    final heartbeatInterval = Duration(
      seconds: _powerSavingManager.heartbeatIntervalSeconds,
    );
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      // Alternate between the two heartbeat approaches to compare performance
      if (DateTime.now().second % 2 == 0) {
        _sendHeartbeatRosterHello();
      } else {
        _sendHeartbeatHead();
      }
    });
    // Send an immediate heartbeat to establish connection right away
    _sendHeartbeatRosterHello();
  }

  // Send a lightweight request to the Roster/Hello endpoint (C# approach)
  Future<void> _sendHeartbeatRosterHello() async {
    try {
      final now = DateTime.now();
      final timestamp =
          '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final uri = Uri.parse('$endpoint/Roster/Hello?time=$timestamp');
      final response = await _httpClient
          .get(
            uri,
            headers: {
              'User-Agent': 'MSIClock-Flutter/1.0',
              'Connection': 'keep-alive',
            },
          )
          .timeout(const Duration(seconds: 5));
      // Update online status based on response
      _isOnline = response.statusCode == 200;
    } catch (e) {
      _isOnline = false;
      _connectionError = e.toString();
      // Reset the HTTP client on connection failure
      _initializeHttpClient();
      // If failed, wait longer before next attempt
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer(const Duration(seconds: 60), () {
        // Try to check connectivity before restarting heartbeat
        checkConnectivity().then((isConnected) {
          if (isConnected) {
            _startHeartbeat();
          } else {
            // If still not connected, try again later
            _heartbeatTimer = Timer(const Duration(seconds: 60), () {
              _startHeartbeat();
            });
          }
        });
      });
    }
  }

  // Send a lightweight HEAD request to keep the connection alive (alternative approach)
  Future<void> _sendHeartbeatHead() async {
    try {
      final uri = Uri.parse('$endpoint/Services/MSIWebTraxCheckInSummary.asmx');
      final response = await _httpClient
          .head(
            uri,
            headers: {
              'User-Agent': 'MSIClock-Flutter/1.0',
              'Connection': 'keep-alive',
            },
          )
          .timeout(const Duration(seconds: 5));
      // Update online status based on response
      _isOnline = response.statusCode == 200;
    } catch (e) {
      _isOnline = false;
      _connectionError = e.toString();
      // Reset the HTTP client on connection failure
      _initializeHttpClient();
      // Use the same error recovery approach as in _sendHeartbeatRosterHello
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer(const Duration(seconds: 60), () {
        // Try to check connectivity before restarting heartbeat
        checkConnectivity().then((isConnected) {
          if (isConnected) {
            _startHeartbeat();
          } else {
            // If still not connected, try again later
            _heartbeatTimer = Timer(const Duration(seconds: 60), () {
              _startHeartbeat();
            });
          }
        });
      });
    }
  }

  // Dispose method to clean up resources
  void dispose() {
    _heartbeatTimer?.cancel();
    _sleepModeSubscription?.cancel();
    if (_isClientInitialized) {
      _httpClient.close();
      _isClientInitialized = false;
    }
  }

  /// Update SOAP configuration
  /// This allows settings changes to take effect without restarting the app
  Future<void> updateConfig(SoapConfig newConfig) async {
    config = newConfig;
    // Reinitialize HTTP client with new configuration
    _initializeHttpClient();
    // Clear caches
    _employeeCache.clear();
    _responseCache.clear();
    // Restart heartbeat with new configuration
    _heartbeatTimer?.cancel();
    _startHeartbeat();
  }

  /// Checks connectivity to the SOAP server without making a full punch request
  /// Returns true if the server is reachable, false otherwise
  /// If forceReconnect is true, it will force a new connection attempt
  Future<bool> checkConnectivity({bool forceReconnect = false}) async {
    final startTime = DateTime.now();
    // Reset the HTTP client if forceReconnect is true
    if (forceReconnect) {
      _initializeHttpClient();
    }
    try {
      // First, try a simple DNS lookup using a HEAD request to a reliable site
      try {
        // Try to ping by IP address first to check if basic internet works
        final ipTestUri = Uri.parse('https://8.8.8.8');
        try {
          await _httpClient
              .head(
                ipTestUri,
                headers: {
                  'User-Agent': 'MSIClock-Flutter/1.0',
                  'Connection': 'close',
                },
              )
              .timeout(const Duration(seconds: 5));
        } catch (ipError) {}
        // Then try domain name resolution
        final testUri = Uri.parse('https://www.google.com');
        final testResponse = await _httpClient
            .head(
              testUri,
              headers: {
                'User-Agent': 'MSIClock-Flutter/1.0',
                'Connection': 'close', // Don't keep this connection alive
              },
            )
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        // Don't return here, still try the actual endpoint
      }
      // Use a dummy employee ID and current time for connectivity check
      // This won't actually record a punch but will verify server connectivity
      final dummyEmployeeId = 'PING';
      final currentTime = DateTime.now();
      final swipeInput =
          '$dummyEmployeeId|*|${_formatTimestampForCSharp(currentTime)}';
      // Build SOAP envelope using the same format as recordPunch
      final envelope = '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Header>
    <UserCredentials xmlns="http://msiwebtrax.com/">
      <UserName>$username</UserName>
      <PWD>$password</PWD>
    </UserCredentials>
  </soap:Header>
  <soap:Body>
    <RecordSwipeSummary xmlns="http://msiwebtrax.com/">
      <swipeInput>$swipeInput</swipeInput>
    </RecordSwipeSummary>
  </soap:Body>
</soap:Envelope>''';
      // Log the connectivity check request for debugging
      // Make the SOAP call using the persistent HTTP client
      final response = await _httpClient
          .post(
            Uri.parse('$endpoint/Services/MSIWebTraxCheckInSummary.asmx'),
            headers: {
              'Content-Type': 'text/xml; charset=utf-8',
              'SOAPAction': 'http://msiwebtrax.com/RecordSwipeSummary',
              'Connection': 'keep-alive', // Use keep-alive for connection reuse
              'User-Agent': 'MSIClock-Flutter/1.0',
            },
            body: envelope,
          )
          .timeout(timeout);
      // Log the connectivity check response for debugging
      // Update online status based on response
      _isOnline = response.statusCode == 200;
      _connectionError =
          _isOnline ? null : 'HTTP ${response.statusCode}: ${response.body}';
      // If we're online and the heartbeat timer isn't running, start it
      if (_isOnline && _heartbeatTimer == null) {
        _startHeartbeat();
      }
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      return _isOnline;
    } catch (e) {
      _isOnline = false;
      _connectionError = e.toString();
      return false;
    }
  }

  // Method to check and clear expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    // Find expired entries
    _employeeCache.forEach((employeeId, data) {
      if (data.containsKey('cache_timestamp')) {
        final cacheTime = DateTime.parse(data['cache_timestamp'] as String);
        if (now.difference(cacheTime) > _cacheExpiration) {
          expiredKeys.add(employeeId);
        }
      } else {
        // If no timestamp, consider it expired
        expiredKeys.add(employeeId);
      }
    });
    // Remove expired entries
    for (final key in expiredKeys) {
      _employeeCache.remove(key);
    }
  }

  // Clear all cache entries
  void clearCache() {
    _employeeCache.clear();
  }

  Future<Map<String, dynamic>> recordPunch({
    required String employeeId,
    required DateTime punchTime,
    Uint8List? imageData,
    DateTime? imageTimestamp,
  }) async {
    // Debug: Log start time
    final soapServiceStartTime = DateTime.now();
    // Log network information
    // Use the provided imageTimestamp or default to punchTime
    // This ensures the image and punch have the same timestamp
    final effectiveImageTimestamp = imageTimestamp ?? punchTime;
    // Implement a shorter timeout for better user experience
    // Windows apps might have different default timeout behavior
    final Duration effectiveTimeout = const Duration(
      seconds: 10,
    ); // Reduced from 30 seconds
    // We still clean expired cache entries for employee info
    _cleanExpiredCache();
    // Check if we have cached employee information for display purposes
    Map<String, dynamic>? cachedEmployeeInfo;
    if (_employeeCache.containsKey(employeeId)) {
      cachedEmployeeInfo = Map<String, dynamic>.from(
        _employeeCache[employeeId]!,
      );
      // Log that we're using the cache for display but still making the SOAP call
    }
    // Check if we have a recent cached response for this employee
    final cacheKey = '$employeeId-${punchTime.toIso8601String()}';
    final now = DateTime.now();
    if (_responseCache.containsKey(cacheKey)) {
      final cachedData = _responseCache[cacheKey]!;
      if (cachedData.containsKey('timestamp')) {
        final cacheTime = DateTime.parse(cachedData['timestamp'] as String);
        if (now.difference(cacheTime) < _responseCacheExpiration) {
          return Map<String, dynamic>.from(
            cachedData['data'] as Map<String, dynamic>,
          );
        }
      }
    }
    return await _executeWithRetry(
      () async {
        // Debug: Log retry attempt start time
        final retryStartTime = DateTime.now();
        try {
          // Format the swipe input string in C# compatible format
          final swipeInput =
              '$employeeId|*|${_formatTimestampForCSharp(punchTime)}';
          // Log all information being sent in the punch request
          // Build SOAP envelope
          final envelope = '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Header>
    <UserCredentials xmlns="http://msiwebtrax.com/">
      <UserName>$username</UserName>
      <PWD>$password</PWD>
    </UserCredentials>
  </soap:Header>
  <soap:Body>
    <RecordSwipeSummary xmlns="http://msiwebtrax.com/">
      <swipeInput>$swipeInput</swipeInput>
    </RecordSwipeSummary>
  </soap:Body>
</soap:Envelope>''';
          // Log the request for debugging
          // Debug: Log HTTP request start time
          final httpRequestStartTime = DateTime.now();
          // Make the SOAP call using the persistent HTTP client
          final response = await _httpClient
              .post(
                Uri.parse('$endpoint/Services/MSIWebTraxCheckInSummary.asmx'),
                headers: {
                  'Content-Type': 'text/xml; charset=utf-8',
                  'SOAPAction': 'http://msiwebtrax.com/RecordSwipeSummary',
                  'Connection':
                      'keep-alive', // Use keep-alive for connection reuse
                  'Accept-Encoding': 'identity', // Try without compression
                  'User-Agent': 'MSIClock-Flutter/1.0', // Add user agent
                },
                body: envelope,
              )
              .timeout(effectiveTimeout);
          // Debug: Log HTTP response received time and calculate duration
          final httpResponseTime = DateTime.now();
          final httpDuration = httpResponseTime.difference(
            httpRequestStartTime,
          );
          if (response.statusCode == 200) {
            _isOnline = true;
            _connectionError = null;
            // Debug: Log response parsing start time
            final parseStartTime = DateTime.now();
            // Parse response
            final result = _parsePunchResponse(response.body);
            // Log all information returned from the server
            // Debug: Log response parsing completion time
            final parseEndTime = DateTime.now();
            final parseDuration = parseEndTime.difference(parseStartTime);
            // Cache the response for future use
            _responseCache[cacheKey] = {
              'timestamp': now.toIso8601String(),
              'data': Map<String, dynamic>.from(result),
            };
            // Cache the employee information if punch was successful
            if (result['success'] == true &&
                result['firstName'] != null &&
                result['lastName'] != null) {
              // Create a copy of the result and add cache timestamp
              final cacheEntry = Map<String, dynamic>.from(result);
              cacheEntry['cache_timestamp'] = now.toIso8601String();
              _employeeCache[employeeId] = cacheEntry;
            }
            // Only upload the image if the punch was successful
            if (result['success'] == true && imageData != null) {
              // Fire and forget - don't await
              // Use the effective image timestamp to ensure it matches the punch
              _uploadImage(
                employeeId,
                imageData,
                effectiveImageTimestamp,
              ).then((success) {});
            } else if (imageData != null) {}
            // Debug: Log retry attempt completion time
            final retryEndTime = DateTime.now();
            final retryDuration = retryEndTime.difference(retryStartTime);
            // If we have cached employee info, merge it with the result for faster display
            // but still use the server's response for the actual punch data
            if (cachedEmployeeInfo != null) {
              // Only use cached name if the server didn't return one
              if (result['firstName'] == null &&
                  cachedEmployeeInfo['firstName'] != null) {
                result['firstName'] = cachedEmployeeInfo['firstName'];
              }
              if (result['lastName'] == null &&
                  cachedEmployeeInfo['lastName'] != null) {
                result['lastName'] = cachedEmployeeInfo['lastName'];
              }
            }
            return result;
          } else {
            _isOnline = false;
            _connectionError = 'HTTP ${response.statusCode}: ${response.body}';
            throw Exception('HTTP error: ${response.statusCode}');
          }
        } catch (e) {
          _isOnline = false;
          _connectionError = e.toString();
          // Check if this is a DNS resolution error
          if (e.toString().contains('Failed host lookup') ||
              e.toString().contains('SocketException')) {
            // Try switching to a fallback endpoint
            if (config.switchToNextEndpoint()) {
              // Don't throw, let the retry mechanism try again with the new endpoint
              throw Exception(
                'Switching to fallback endpoint: ${config.currentEndpoint}',
              );
            } else {}
          }
          throw e; // Rethrow for retry mechanism
        }
      },
      maxRetries: 2,
      employeeId: employeeId,
    );
  }

  // Method to retry a punch in the background without blocking the UI
  Future<void> _retryPunchInBackground(
    String employeeId,
    DateTime punchTime,
    Uint8List? imageData,
    DateTime imageTimestamp,
  ) async {
    try {
      // Format the swipe input string in C# compatible format
      final swipeInput =
          '$employeeId|*|${_formatTimestampForCSharp(punchTime)}';
      // Build SOAP envelope
      final envelope = '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Header>
    <UserCredentials xmlns="http://msiwebtrax.com/">
      <UserName>$username</UserName>
      <PWD>$password</PWD>
    </UserCredentials>
  </soap:Header>
  <soap:Body>
    <RecordSwipeSummary xmlns="http://msiwebtrax.com/">
      <swipeInput>$swipeInput</swipeInput>
    </RecordSwipeSummary>
  </soap:Body>
</soap:Envelope>''';
      // Make the SOAP call using the persistent HTTP client
      final response = await _httpClient
          .post(
            Uri.parse('$endpoint/Services/MSIWebTraxCheckInSummary.asmx'),
            headers: {
              'Content-Type': 'text/xml; charset=utf-8',
              'SOAPAction': 'http://msiwebtrax.com/RecordSwipeSummary',
              'Connection': 'keep-alive', // Use keep-alive for connection reuse
              'User-Agent': 'MSIClock-Flutter/1.0',
            },
            body: envelope,
          )
          .timeout(timeout);
      if (response.statusCode == 200) {
        _isOnline = true;
        _connectionError = null;
        // Parse response
        final result = _parsePunchResponse(response.body);
        // Cache the employee information if punch was successful
        if (result['success'] == true &&
            result['firstName'] != null &&
            result['lastName'] != null) {
          // Create a copy of the result and add cache timestamp
          final cacheEntry = Map<String, dynamic>.from(result);
          cacheEntry['cache_timestamp'] = DateTime.now().toIso8601String();
          _employeeCache[employeeId] = cacheEntry;
        }
        // Only upload the image if the background punch was successful
        if (result['success'] == true && imageData != null) {
          // Use the provided image timestamp to ensure it matches the punch
          // Log the exact timestamp being used for consistency
          final imageSuccess = await _uploadImage(
            employeeId,
            imageData,
            imageTimestamp, // Use the specific image timestamp
          );
        } else if (imageData != null) {}
      }
    } catch (e) {}
  }

  // Helper method to format timestamp for logging
  String _formatTimestampForLog(DateTime timestamp) {
    return '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';
  }

  // Helper method to format timestamp for C# DateTime.Parse compatibility
  // This matches the default C# DateTime.ToString() format: MM/dd/yyyy hh:mm:ss tt
  String _formatTimestampForCSharp(DateTime timestamp) {
    final hour =
        timestamp.hour > 12
            ? timestamp.hour - 12
            : (timestamp.hour == 0 ? 12 : timestamp.hour);
    final amPm = timestamp.hour >= 12 ? 'PM' : 'AM';
    final formattedTime =
        '${timestamp.month}/${timestamp.day}/${timestamp.year} ${hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')} $amPm';
    // Add debug logging to verify the format
    return formattedTime;
  }

  Future<bool> _uploadImage(
    String employeeId,
    Uint8List imageData,
    DateTime punchTime,
  ) async {
    // Format the filename with the exact timestamp from the punch
    final formattedTimestamp = _formatTimestampForLog(punchTime);
    final fileName = '${employeeId}__$formattedTimestamp.jpg';
    // Log the exact timestamp being used for the image
    // Build SOAP envelope for image upload
    final envelope = '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Header>
    <UserCredentials xmlns="http://msiwebtrax.com/">
      <UserName>$username</UserName>
      <PWD>$password</PWD>
    </UserCredentials>
  </soap:Header>
  <soap:Body>
    <SaveImage xmlns="http://msiwebtrax.com/">
      <fileName>$fileName</fileName>
      <data>${base64Encode(imageData)}</data>
      <dir>$clientId</dir>
    </SaveImage>
  </soap:Body>
</soap:Envelope>''';
    // Use retry mechanism for image upload too
    int attempts = 0;
    final maxRetries = 2;
    while (true) {
      attempts++;
      try {
        // Log the request for debugging
        // Make the SOAP call using the persistent HTTP client
        final response = await _httpClient
            .post(
              Uri.parse('$endpoint/Services/MSIWebTraxCheckIn.asmx'),
              headers: {
                'Content-Type': 'text/xml; charset=utf-8',
                'SOAPAction': 'http://msiwebtrax.com/SaveImage',
                'Connection':
                    'keep-alive', // Use keep-alive for connection reuse
                'Accept-Encoding': 'identity', // Try without compression
                'User-Agent': 'MSIClock-Flutter/1.0', // Add user agent
              },
              body: envelope,
            )
            .timeout(const Duration(seconds: 10));
        // Log the response status for debugging
        return response.statusCode == 200;
      } catch (e) {
        // If we've reached max retries, return failure
        if (attempts > maxRetries) {
          return false;
        }
        // Calculate backoff delay (exponential with jitter)
        final backoffMs = 500 * (1 << (attempts - 1)); // 500ms, 1s, 2s, etc.
        final jitter =
            (backoffMs *
                    0.2 *
                    (DateTime.now().millisecondsSinceEpoch % 10) /
                    10)
                .round();
        final delayMs = backoffMs + jitter;
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  Map<String, dynamic> _parsePunchResponse(String xmlResponse) {
    try {
      // Pre-check for common error patterns to fail fast
      if (xmlResponse.isEmpty ||
          !xmlResponse.contains('RecordSwipeReturnInfo')) {
        return _offlineResponse();
      }
      // Parse the XML document
      final document = XmlDocument.parse(xmlResponse);
      // Create a map to store all relevant elements - more efficient than multiple searches
      final Map<String, String?> extractedValues = {};
      // Find the RecordSwipeReturnInfo element
      final returnInfoElements = document.findAllElements(
        'RecordSwipeReturnInfo',
      );
      if (returnInfoElements.isEmpty) {
        return _offlineResponse();
      }
      final returnInfo = returnInfoElements.first;
      // Extract all child elements in one pass
      for (final child in returnInfo.childElements) {
        extractedValues[child.name.local] = child.text;
      }
      // Find CurrentWeeklyHours which might be at a different level - do this only once
      final weeklyHoursElements = document.findAllElements(
        'CurrentWeeklyHours',
      );
      final weeklyHours =
          weeklyHoursElements.isNotEmpty
              ? weeklyHoursElements.first.text
              : null;
      // Process the extracted values
      final punchSuccess =
          extractedValues['PunchSuccess']?.toLowerCase() == 'true';
      final punchException = int.tryParse(
        extractedValues['PunchException'] ?? '0',
      );
      return {
        'success': punchSuccess,
        'offline': false,
        'punchType': extractedValues['PunchType'],
        'firstName': extractedValues['FirstName'],
        'lastName': extractedValues['LastName'],
        'exception': punchException,
        'weeklyHours': weeklyHours,
      };
    } catch (e) {
      return _offlineResponse();
    }
  }

  String? _getXmlText(XmlElement element, String tagName) {
    try {
      final elements = element.findElements(tagName);
      return elements.isNotEmpty ? elements.first.text : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _offlineResponse() {
    return {
      'success': true,
      'offline': true,
      'message': 'Punch stored offline',
    };
  }

  /// Helper method to execute a function with retry logic
  /// This implements exponential backoff for retries
  Future<Map<String, dynamic>> _executeWithRetry(
    Future<Map<String, dynamic>> Function() operation, {
    int maxRetries = 2,
    required String employeeId,
  }) async {
    // Reset to primary endpoint at the start of a new operation
    config.resetToMainEndpoint();
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        // Try to execute the operation
        return await operation();
      } catch (e) {
        // If we've reached max retries, return offline response
        if (attempts > maxRetries) {
          // Reset the HTTP client after all retries have failed
          _initializeHttpClient();
          // Check if we have cached employee information to enhance the offline response
          if (_employeeCache.containsKey(employeeId)) {
            // Create an offline response with cached employee information
            final offlineResponse = _offlineResponse();
            final cachedInfo = _employeeCache[employeeId]!;
            // Add cached employee information to the offline response
            if (cachedInfo['firstName'] != null) {
              offlineResponse['firstName'] = cachedInfo['firstName'];
            }
            if (cachedInfo['lastName'] != null) {
              offlineResponse['lastName'] = cachedInfo['lastName'];
            }
            // Still mark as offline so the UI shows the appropriate message
            offlineResponse['offline'] = true;
            return offlineResponse;
          }
          // If no cached data, return standard offline response
          return _offlineResponse();
        }
        // Reset the HTTP client before retrying
        if (e.toString().contains('SocketException') ||
            e.toString().contains('ClientException')) {
          _initializeHttpClient();
        }
        // Calculate backoff delay (exponential with jitter)
        final backoffMs = 500 * (1 << (attempts - 1)); // 500ms, 1s, 2s, etc.
        final jitter =
            (backoffMs *
                    0.2 *
                    (DateTime.now().millisecondsSinceEpoch % 10) /
                    10)
                .round();
        final delayMs = backoffMs + jitter;
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }
}
