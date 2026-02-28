import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/battery_check_in.dart';
import 'settings_service.dart';
/// Service responsible for communicating with the battery monitoring API
class BatteryApiService {
  // Singleton instance
  static final BatteryApiService _instance = BatteryApiService._internal();
  factory BatteryApiService() => _instance;
  BatteryApiService._internal();
  // Dependencies
  final SettingsService _settingsService = SettingsService();
  final http.Client _httpClient = http.Client();
  // Queue for failed requests
  final List<BatteryCheckIn> _pendingRequests = [];
  // Flag to track if retry is in progress
  bool _isRetrying = false;
  /// Send battery check-in to API
  Future<bool> sendBatteryCheckIn(BatteryCheckIn checkIn) async {
    try {
      // Get API endpoint from settings
      final apiEndpoint = await _settingsService.getBatteryApiEndpoint();
      final uri = Uri.parse('$apiEndpoint/checkin');
      // Send POST request
      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: checkIn.toJsonString(),
          )
          .timeout(const Duration(seconds: 10));
      // Check response
      if (response.statusCode == 200) {
        // If this was successful and we have pending requests, try to send them
        if (_pendingRequests.isNotEmpty && !_isRetrying) {
          _retryPendingRequests();
        }
        return true;
      } else {
        // Add to pending requests for later retry
        _addToPendingRequests(checkIn);
        return false;
      }
    } catch (e) {
      // Add to pending requests for later retry
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
      } catch (e) {
      }
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
