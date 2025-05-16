import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/soap_config.dart';

class SoapService {
  final SoapConfig config;
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

  // Heartbeat interval - 30 seconds
  final Duration _heartbeatInterval = const Duration(seconds: 30);

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
  }

  // Initialize or reset the HTTP client
  void _initializeHttpClient() {
    // Close existing client if it exists
    if (_isClientInitialized) {
      try {
        _httpClient.close();
      } catch (e) {
        print('Error closing HTTP client: $e');
      }
    }

    // Create a new client
    _httpClient = http.Client();
    _isClientInitialized = true;
    print('SOAP DEBUG: HTTP client initialized/reset');
  }

  bool get isOnline => _isOnline;
  String? get connectionError => _connectionError;

  // Start the heartbeat timer to keep the connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      // Alternate between the two heartbeat approaches to compare performance
      if (DateTime.now().second % 2 == 0) {
        _sendHeartbeatRosterHello();
      } else {
        _sendHeartbeatHead();
      }
    });
  }

  // Send a lightweight request to the Roster/Hello endpoint (C# approach)
  Future<void> _sendHeartbeatRosterHello() async {
    try {
      final now = DateTime.now();
      final timestamp =
          '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final uri = Uri.parse('$endpoint/Roster/Hello?time=$timestamp');

      print('HEARTBEAT: Sending Roster/Hello request');
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
      print(
        'HEARTBEAT (Roster/Hello): Connection ${_isOnline ? 'ACTIVE' : 'INACTIVE'}',
      );
    } catch (e) {
      print('HEARTBEAT (Roster/Hello): Failed - $e');
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

      print('HEARTBEAT: Sending HEAD request');
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
      print(
        'HEARTBEAT (HEAD): Connection ${_isOnline ? 'ACTIVE' : 'INACTIVE'}',
      );
    } catch (e) {
      print('HEARTBEAT (HEAD): Failed - $e');
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
    if (_isClientInitialized) {
      _httpClient.close();
      _isClientInitialized = false;
    }
  }

  /// Checks connectivity to the SOAP server without making a full punch request
  /// Returns true if the server is reachable, false otherwise
  /// If forceReconnect is true, it will force a new connection attempt
  Future<bool> checkConnectivity({bool forceReconnect = false}) async {
    print('SOAP DEBUG: Using persistent connection for connectivity check');
    print('SOAP DEBUG: Attempting to connect to endpoint: $endpoint');

    // Reset the HTTP client if forceReconnect is true
    if (forceReconnect) {
      _initializeHttpClient();
    }

    try {
      // First, try a simple DNS lookup using a HEAD request to a reliable site
      try {
        print('NETWORK DEBUG: Testing basic internet connectivity...');

        // Try to ping by IP address first to check if basic internet works
        final ipTestUri = Uri.parse('https://8.8.8.8');
        try {
          print('NETWORK DEBUG: Testing connectivity to IP address 8.8.8.8...');
          await _httpClient
              .head(
                ipTestUri,
                headers: {
                  'User-Agent': 'MSIClock-Flutter/1.0',
                  'Connection': 'close',
                },
              )
              .timeout(const Duration(seconds: 5));
          print(
            'NETWORK DEBUG: IP connectivity test SUCCESS - can reach IP addresses',
          );
        } catch (ipError) {
          print('NETWORK DEBUG: IP connectivity test FAILED: $ipError');
        }

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

        print(
          'NETWORK DEBUG: Internet connectivity test result: ${testResponse.statusCode == 200 ? "SUCCESS" : "FAILED"}',
        );
      } catch (e) {
        print('NETWORK DEBUG: Internet connectivity test failed: $e');
        print(
          'NETWORK DEBUG: Device appears to be offline or has restricted connectivity',
        );
        // Don't return here, still try the actual endpoint
      }

      // Use a dummy employee ID and current time for connectivity check
      // This won't actually record a punch but will verify server connectivity
      final dummyEmployeeId = 'PING';
      final currentTime = DateTime.now();
      final swipeInput = '$dummyEmployeeId|*|${currentTime.toIso8601String()}';

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
      print(
        'CONNECTIVITY CHECK URL: $endpoint/Services/MSIWebTraxCheckInSummary.asmx',
      );

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
      print('CONNECTIVITY CHECK RESPONSE STATUS: ${response.statusCode}');

      // Update online status based on response
      _isOnline = response.statusCode == 200;

      _connectionError =
          _isOnline ? null : 'HTTP ${response.statusCode}: ${response.body}';

      print('CONNECTIVITY CHECK RESULT: ${_isOnline ? 'ONLINE' : 'OFFLINE'}');

      // If we're online and the heartbeat timer isn't running, start it
      if (_isOnline && _heartbeatTimer == null) {
        _startHeartbeat();
      }

      return _isOnline;
    } catch (e) {
      _isOnline = false;
      _connectionError = e.toString();
      print('Connectivity check failed: $e');
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
      print('Removing expired cache entry for employee: $key');
      _employeeCache.remove(key);
    }
  }

  // Clear all cache entries
  void clearCache() {
    _employeeCache.clear();
    print('Employee cache cleared');
  }

  Future<Map<String, dynamic>> recordPunch({
    required String employeeId,
    required DateTime punchTime,
    Uint8List? imageData,
    DateTime? imageTimestamp,
  }) async {
    // Debug: Log start time
    final soapServiceStartTime = DateTime.now();
    print(
      'TIMING: SoapService.recordPunch started at ${soapServiceStartTime.toIso8601String()}',
    );
    print('SOAP DEBUG: Starting recordPunch with employeeId: $employeeId');
    print('SOAP DEBUG: Using persistent connection for this punch request');

    // Log network information
    print('SOAP DEBUG: Request timestamp: ${DateTime.now().toIso8601String()}');

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
      print('TIMING: Found cached employee information for $employeeId');
      cachedEmployeeInfo = Map<String, dynamic>.from(
        _employeeCache[employeeId]!,
      );

      // Log that we're using the cache for display but still making the SOAP call
      print(
        'TIMING: Using cached employee data for display, but still making SOAP call',
      );
    }

    // Check if we have a recent cached response for this employee
    final cacheKey = '$employeeId-${punchTime.toIso8601String()}';
    final now = DateTime.now();
    if (_responseCache.containsKey(cacheKey)) {
      final cachedData = _responseCache[cacheKey]!;
      if (cachedData.containsKey('timestamp')) {
        final cacheTime = DateTime.parse(cachedData['timestamp'] as String);
        if (now.difference(cacheTime) < _responseCacheExpiration) {
          print('TIMING: Using cached response for $employeeId');
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
        print(
          'TIMING: SOAP retry attempt started at ${retryStartTime.toIso8601String()}',
        );

        try {
          // Format the swipe input string
          final swipeInput = '$employeeId|*|${punchTime.toIso8601String()}';

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
          print(
            'SOAP REQUEST URL: $endpoint/Services/MSIWebTraxCheckInSummary.asmx',
          );
          print('SOAP DEBUG: Request envelope size: ${envelope.length} bytes');

          // Debug: Log HTTP request start time
          final httpRequestStartTime = DateTime.now();
          print(
            'TIMING: HTTP request started at ${httpRequestStartTime.toIso8601String()}',
          );

          // Make the SOAP call using the persistent HTTP client
          print(
            'SOAP DEBUG: Sending request at ${DateTime.now().toIso8601String()}',
          );
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
          print(
            'TIMING: HTTP response received at ${httpResponseTime.toIso8601String()}',
          );
          print('TIMING: HTTP request took ${httpDuration.inMilliseconds}ms');

          print(
            'SOAP DEBUG: Received response at ${DateTime.now().toIso8601String()}',
          );
          print('SOAP RESPONSE STATUS: ${response.statusCode}');
          print('SOAP DEBUG: Response headers: ${response.headers}');

          if (response.statusCode == 200) {
            _isOnline = true;
            _connectionError = null;

            // Debug: Log response parsing start time
            final parseStartTime = DateTime.now();
            print(
              'TIMING: Response parsing started at ${parseStartTime.toIso8601String()}',
            );

            // Parse response
            final result = _parsePunchResponse(response.body);

            // Debug: Log response parsing completion time
            final parseEndTime = DateTime.now();
            final parseDuration = parseEndTime.difference(parseStartTime);
            print(
              'TIMING: Response parsing completed at ${parseEndTime.toIso8601String()}',
            );
            print(
              'TIMING: Response parsing took ${parseDuration.inMilliseconds}ms',
            );

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
              print('Cached employee information for $employeeId');
            }

            // Only upload the image if the punch was successful
            if (result['success'] == true && imageData != null) {
              print('SOAP DEBUG: Uploading image for successful punch');
              // Fire and forget - don't await
              // Use the effective image timestamp to ensure it matches the punch
              print(
                'Using timestamp for non-cached punch image: ${_formatTimestampForLog(effectiveImageTimestamp)}',
              );
              _uploadImage(
                employeeId,
                imageData,
                effectiveImageTimestamp,
              ).then((success) {
                print(
                  'Async image upload ${success ? 'succeeded' : 'failed'} with timestamp: ${_formatTimestampForLog(effectiveImageTimestamp)}',
                );
              });
            } else if (imageData != null) {
              print('SOAP DEBUG: Skipping image upload for unsuccessful punch');
            }

            // Debug: Log retry attempt completion time
            final retryEndTime = DateTime.now();
            final retryDuration = retryEndTime.difference(retryStartTime);
            print(
              'TIMING: SOAP retry attempt completed at ${retryEndTime.toIso8601String()}',
            );
            print(
              'TIMING: SOAP retry attempt took ${retryDuration.inMilliseconds}ms',
            );

            // If we have cached employee info, merge it with the result for faster display
            // but still use the server's response for the actual punch data
            if (cachedEmployeeInfo != null) {
              print(
                'TIMING: Merging cached employee info with server response',
              );

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
            print('SOAP DEBUG: Error response body: ${response.body}');
            throw Exception('HTTP error: ${response.statusCode}');
          }
        } catch (e) {
          _isOnline = false;
          _connectionError = e.toString();
          print('SOAP ERROR: $e');

          // Check if this is a DNS resolution error
          if (e.toString().contains('Failed host lookup') ||
              e.toString().contains('SocketException')) {
            // Try switching to a fallback endpoint
            if (config.switchToNextEndpoint()) {
              print(
                'ENDPOINT DEBUG: Trying fallback endpoint after DNS resolution failure',
              );
              print('ENDPOINT DEBUG: New endpoint: ${config.currentEndpoint}');
              // Don't throw, let the retry mechanism try again with the new endpoint
              throw Exception(
                'Switching to fallback endpoint: ${config.currentEndpoint}',
              );
            } else {
              print('ENDPOINT DEBUG: No more fallback endpoints available');
            }
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
    print('Retrying punch in background for employee: $employeeId');
    print('SOAP DEBUG: Using persistent connection for background retry');

    try {
      // Format the swipe input string
      final swipeInput = '$employeeId|*|${punchTime.toIso8601String()}';

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

      print('BACKGROUND RETRY RESPONSE STATUS: ${response.statusCode}');

      if (response.statusCode == 200) {
        _isOnline = true;
        _connectionError = null;

        print('Background punch sync successful for employee: $employeeId');

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
          print(
            'Cached employee information for $employeeId from background sync',
          );
        }

        // Only upload the image if the background punch was successful
        if (result['success'] == true && imageData != null) {
          print('SOAP DEBUG: Uploading image for successful background punch');
          // Use the provided image timestamp to ensure it matches the punch
          // Log the exact timestamp being used for consistency
          print(
            'Using timestamp for background retry image: ${_formatTimestampForLog(imageTimestamp)}',
          );
          final imageSuccess = await _uploadImage(
            employeeId,
            imageData,
            imageTimestamp, // Use the specific image timestamp
          );
          print(
            'Background image upload ${imageSuccess ? 'succeeded' : 'failed'} with timestamp: ${_formatTimestampForLog(imageTimestamp)}',
          );
        } else if (imageData != null) {
          print(
            'SOAP DEBUG: Skipping image upload for unsuccessful background punch',
          );
        }
      }
    } catch (e) {
      print('Background punch retry failed: $e');
    }
  }

  // Helper method to format timestamp for logging
  String _formatTimestampForLog(DateTime timestamp) {
    return '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';
  }

  Future<bool> _uploadImage(
    String employeeId,
    Uint8List imageData,
    DateTime punchTime,
  ) async {
    print('SOAP DEBUG: Starting image upload for employeeId: $employeeId');
    print('SOAP DEBUG: Using persistent connection for image upload');

    // Format the filename with the exact timestamp from the punch
    final formattedTimestamp = _formatTimestampForLog(punchTime);
    final fileName = '${employeeId}__$formattedTimestamp.jpg';

    // Log the exact timestamp being used for the image
    print('Using timestamp for image: $formattedTimestamp');

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
        print(
          'SOAP DEBUG: Image upload attempt $attempts for employeeId: $employeeId',
        );

        // Log the request for debugging
        print('IMAGE UPLOAD URL: $endpoint/Services/MSIWebTraxCheckIn.asmx');
        print(
          'IMAGE UPLOAD FILENAME: $fileName (Timestamp: $formattedTimestamp)',
        );
        print(
          'SOAP DEBUG: Image request envelope size: ${envelope.length} bytes',
        );

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
        print('IMAGE UPLOAD RESPONSE STATUS: ${response.statusCode}');

        return response.statusCode == 200;
      } catch (e) {
        print('Image upload failed: $e');

        // If we've reached max retries, return failure
        if (attempts > maxRetries) {
          print(
            'SOAP DEBUG: Max retries ($maxRetries) reached for image upload, employeeId: $employeeId',
          );
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

        print(
          'SOAP DEBUG: Retry image upload attempt $attempts after $delayMs ms for employeeId: $employeeId',
        );

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
        print('Error: Invalid or empty XML response');
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
        print('Error: RecordSwipeReturnInfo element not found in response');
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
      print('Error parsing SOAP response: $e');
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
    print('ENDPOINT DEBUG: Using endpoint: ${config.currentEndpoint}');
    int attempts = 0;

    while (true) {
      attempts++;
      try {
        // Try to execute the operation
        return await operation();
      } catch (e) {
        // If we've reached max retries, return offline response
        if (attempts > maxRetries) {
          print(
            'SOAP DEBUG: Max retries ($maxRetries) reached for employeeId: $employeeId',
          );

          // Reset the HTTP client after all retries have failed
          _initializeHttpClient();

          // Check if we have cached employee information to enhance the offline response
          if (_employeeCache.containsKey(employeeId)) {
            print(
              'TIMING: Using cached employee data for offline response after failed retries',
            );

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
          print(
            'SOAP DEBUG: Resetting HTTP client before retry attempt ${attempts + 1}',
          );
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

        print(
          'SOAP DEBUG: Retry attempt $attempts after $delayMs ms for employeeId: $employeeId',
        );

        // Wait before retrying
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }
}
