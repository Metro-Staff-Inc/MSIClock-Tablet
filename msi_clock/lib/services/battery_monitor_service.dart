import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import '../models/battery_check_in.dart';
import 'battery_api_service.dart';
import 'settings_service.dart';
/// Service responsible for monitoring battery levels and scheduling reports
class BatteryMonitorService {
  // Singleton instance
  static final BatteryMonitorService _instance =
      BatteryMonitorService._internal();
  factory BatteryMonitorService() => _instance;
  BatteryMonitorService._internal();
  // Dependencies
  final SettingsService _settingsService = SettingsService();
  final BatteryApiService _apiService = BatteryApiService();
  final Battery _battery = Battery();
  // Method channel for device information
  static const platform = MethodChannel('com.example.msi_clock/device_info');
  // Timer for periodic reporting
  Timer? _reportingTimer;
  // Flag to track if a report is currently in progress
  bool _isReporting = false;
  /// Initialize the service
  Future<void> initialize() async {
    // Schedule the first report
    _scheduleNextReport();
    // Log initialization
  }
  /// Schedule the next battery report
  void _scheduleNextReport() {
    // Cancel any existing timer
    _reportingTimer?.cancel();
    // Calculate time until next hour
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1, 0, 0);
    final duration = nextHour.difference(now);
    // Schedule the next report
    _reportingTimer = Timer(duration, () {
      _reportBatteryLevel();
      // Schedule the next report after this one completes
      _scheduleNextReport();
    });
  }
  /// Get the device's MAC address
  Future<String?> _getMacAddress() async {
    try {
      // Call native method to get MAC address
      final String macAddress = await platform.invokeMethod('getMacAddress');
      return macAddress;
    } catch (e) {
      return null;
    }
  }
  /// Report the current battery level
  Future<void> _reportBatteryLevel() async {
    // Prevent concurrent reports
    if (_isReporting) {
      return;
    }
    _isReporting = true;
    try {
      // Get device information from settings
      final deviceName = await _settingsService.getDeviceName();
      final location = await _settingsService.getDeviceLocation();
      // Get current battery level
      final batteryPct = await _getBatteryLevel();
      // Get MAC address
      final macAddress = await _getMacAddress();
      // Create check-in data
      final checkIn = BatteryCheckIn(
        deviceName: deviceName,
        location: location,
        batteryPct: batteryPct,
        macAddress: macAddress,
      );
      // Send to API
      final success = await _apiService.sendBatteryCheckIn(checkIn);
      if (success) {
      } else {
        // Schedule a retry in 5 minutes if the report fails
        Timer(const Duration(minutes: 5), _reportBatteryLevel);
      }
    } catch (e) {
      // Schedule a retry in 5 minutes if the report fails
      Timer(const Duration(minutes: 5), _reportBatteryLevel);
    } finally {
      _isReporting = false;
    }
  }
  /// Get the current battery level
  Future<int> _getBatteryLevel() async {
    try {
      // Get battery level using battery_plus package
      final level = await _battery.batteryLevel;
      return level;
    } catch (e) {
      // Return a default value if there's an error
      return 0;
    }
  }
  /// Manually trigger a battery report (for testing)
  Future<void> triggerManualReport() async {
    await _reportBatteryLevel();
  }
  /// Dispose the service
  void dispose() {
    _reportingTimer?.cancel();
  }
}
