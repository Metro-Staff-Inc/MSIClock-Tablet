import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/battery_check_in.dart';
import 'settings_service.dart';
import 'logger_service.dart';

/// Service responsible for communicating with the telemetry API
class BatteryApiService {
  // Singleton instance
  static final BatteryApiService _instance = BatteryApiService._internal();
  factory BatteryApiService() => _instance;
  BatteryApiService._internal();

  // Dependencies
  final SettingsService _settingsService = SettingsService();
  final LoggerService _logger = LoggerService();
  final http.Client _httpClient = http.Client();

  // Queue for failed requests
  final List<BatteryCheckIn> _pendingRequests = [];

  // Flag to track if retry is in progress
  bool _isRetrying = false;

  /// Send telemetry check-in to API
  Future<bool> sendBatteryCheckIn(BatteryCheckIn checkIn) async {
    try {
      // Get API endpoint and token from settings
      final apiEndpoint = await _settingsService.getBatteryApiEndpoint();
      final apiToken = await _settingsService.getBatteryApiToken();

      // Build the full API URL
      final uri = Uri.parse('$apiEndpoint/api/telemetry');

      // Send POST request with Bearer token authentication
      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiToken',
            },
            body: checkIn.toJsonString(),
          )
          .timeout(const Duration(seconds: 30));

      // Handle response based on status code
      if (response.statusCode == 200) {
        // Parse success response
        try {
          final responseData =
              json.decode(response.body) as Map<String, dynamic>;
          final deviceId = responseData['device_id'] as String?;
          await _logger.logInfo(
            'Telemetry sent successfully. Device ID: ${deviceId ?? 'unknown'}',
          );
        } catch (e) {
          await _logger.logInfo('Telemetry sent successfully');
        }

        // If this was successful and we have pending requests, try to send them
        if (_pendingRequests.isNotEmpty && !_isRetrying) {
          _retryPendingRequests();
        }
        return true;
      } else if (response.statusCode == 401) {
        // Authentication error - don't retry
        await _logger.logError(
          'Telemetry authentication failed (401). Check API token in settings.',
        );
        return false;
      } else if (response.statusCode == 400) {
        // Validation error - don't retry, log details
        try {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          await _logger.logError(
            'Telemetry validation failed (400): ${errorData['error'] ?? 'Unknown error'}',
          );
          if (errorData.containsKey('details')) {
            await _logger.logError('Details: ${errorData['details']}');
          }
        } catch (e) {
          await _logger.logError('Telemetry validation failed (400)');
        }
        return false;
      } else if (response.statusCode >= 500) {
        // Server error - retry
        await _logger.logWarning(
          'Telemetry server error (${response.statusCode}). Will retry.',
        );
        _addToPendingRequests(checkIn);
        return false;
      } else {
        // Other error - retry
        await _logger.logWarning(
          'Telemetry failed with status ${response.statusCode}. Will retry.',
        );
        _addToPendingRequests(checkIn);
        return false;
      }
    } catch (e) {
      // Network error or timeout - retry
      await _logger.logWarning('Telemetry network error: $e. Will retry.');
      _addToPendingRequests(checkIn);
      return false;
    }
  }

  /// Add a check-in to the pending requests queue
  void _addToPendingRequests(BatteryCheckIn checkIn) {
    // Only add if not already in the queue
    if (!_pendingRequests.any(
      (item) =>
          item.deviceName == checkIn.deviceName &&
          item.batteryPct == checkIn.batteryPct,
    )) {
      _pendingRequests.add(checkIn);
    }
  }

  /// Retry sending pending requests
  Future<void> _retryPendingRequests() async {
    if (_pendingRequests.isEmpty || _isRetrying) {
      return;
    }
    _isRetrying = true;
    // Create a copy of the list to avoid modification during iteration
    final requests = List<BatteryCheckIn>.from(_pendingRequests);
    for (final checkIn in requests) {
      try {
        final success = await sendBatteryCheckIn(checkIn);
        if (success) {
          _pendingRequests.remove(checkIn);
        }
      } catch (e) {}
      // Add a small delay between retries
      await Future.delayed(const Duration(seconds: 1));
    }
    _isRetrying = false;
  }

  /// Dispose the service
  void dispose() {
    _httpClient.close();
  }
}
