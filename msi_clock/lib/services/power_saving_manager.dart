import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'settings_service.dart';

/// Service responsible for managing power-saving features
class PowerSavingManager {
  // Singleton instance
  static final PowerSavingManager _instance = PowerSavingManager._internal();
  factory PowerSavingManager() => _instance;
  PowerSavingManager._internal();

  // Dependencies
  final SettingsService _settingsService = SettingsService();

  // Timer for inactivity detection
  Timer? _inactivityTimer;

  // State variables
  bool _isSleepModeActive = false;
  DateTime _lastInteractionTime = DateTime.now();
  double? _previousBrightness;

  // Default inactivity threshold (10 minutes)
  Duration _inactivityThreshold = const Duration(minutes: 10);

  // Default heartbeat interval (30 seconds)
  Duration _heartbeatInterval = const Duration(seconds: 30);

  // Callbacks
  VoidCallback? _onSleepModeActivated;
  VoidCallback? _onSleepModeDeactivated;

  // Event stream for sleep mode state changes
  final StreamController<bool> _sleepModeStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get sleepModeStateStream => _sleepModeStateController.stream;

  /// Initialize the power saving manager
  Future<void> initialize() async {
    // Load settings
    await _loadSettings();

    // Start inactivity timer
    _resetInactivityTimer();

    print('Power saving manager initialized');
  }

  /// Load power saving settings
  Future<void> _loadSettings() async {
    final settings = await _settingsService.loadSettings();

    if (settings.containsKey('powerSaving') &&
        settings['powerSaving'] is Map<String, dynamic>) {
      final powerSavingSettings =
          settings['powerSaving'] as Map<String, dynamic>;

      // Load inactivity threshold
      if (powerSavingSettings.containsKey('inactivityThresholdMinutes') &&
          powerSavingSettings['inactivityThresholdMinutes'] is int) {
        final minutes =
            powerSavingSettings['inactivityThresholdMinutes'] as int;
        _inactivityThreshold = Duration(minutes: minutes);
      }

      // Load heartbeat interval
      if (powerSavingSettings.containsKey('heartbeatIntervalSeconds') &&
          powerSavingSettings['heartbeatIntervalSeconds'] is int) {
        final seconds = powerSavingSettings['heartbeatIntervalSeconds'] as int;
        _heartbeatInterval = Duration(seconds: seconds);
      }
    }
  }

  /// Save power saving settings
  Future<void> saveSettings({
    int? inactivityThresholdMinutes,
    int? heartbeatIntervalSeconds,
  }) async {
    final settings = await _settingsService.loadSettings();

    // Get current power saving settings or create new ones
    final powerSavingSettings =
        settings.containsKey('powerSaving') &&
                settings['powerSaving'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(
              settings['powerSaving'] as Map<String, dynamic>,
            )
            : <String, dynamic>{
              'inactivityThresholdMinutes': 10,
              'heartbeatIntervalSeconds': 30,
            };

    // Update settings if provided
    if (inactivityThresholdMinutes != null) {
      powerSavingSettings['inactivityThresholdMinutes'] =
          inactivityThresholdMinutes;
      _inactivityThreshold = Duration(minutes: inactivityThresholdMinutes);
    }

    if (heartbeatIntervalSeconds != null) {
      powerSavingSettings['heartbeatIntervalSeconds'] =
          heartbeatIntervalSeconds;
      _heartbeatInterval = Duration(seconds: heartbeatIntervalSeconds);
    }

    // Save updated settings
    settings['powerSaving'] = powerSavingSettings;
    await _settingsService.saveSettings(settings);

    // Reset the inactivity timer with new threshold
    _resetInactivityTimer();
  }

  /// Register user interaction to reset the inactivity timer
  Future<void> registerUserInteraction() async {
    _lastInteractionTime = DateTime.now();

    // If sleep mode is active, deactivate it
    if (_isSleepModeActive) {
      await _deactivateSleepMode();
    }

    // Reset the inactivity timer
    _resetInactivityTimer();
  }

  /// Reset the inactivity timer
  void _resetInactivityTimer() {
    // Cancel any existing timer
    _inactivityTimer?.cancel();

    // Start a new timer
    _inactivityTimer = Timer(_inactivityThreshold, () async {
      await _activateSleepMode();
    });
  }

  /// Activate sleep mode
  Future<void> _activateSleepMode() async {
    if (_isSleepModeActive) return;

    try {
      // Save current brightness before dimming
      _previousBrightness = await ScreenBrightness().current;

      // Dim the screen (0.0 = darkest, 1.0 = brightest)
      await ScreenBrightness().setScreenBrightness(0.05); // very dim

      _isSleepModeActive = true;

      // Also update system UI style for consistency
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarBrightness: Brightness.dark),
      );

      // Call the callback if registered
      _onSleepModeActivated?.call();

      // Notify listeners through the stream
      _sleepModeStateController.add(true);

      print('Sleep mode activated, brightness set to 5%');
    } catch (e) {
      print('Error activating sleep mode: $e');
    }
  }

  /// Deactivate sleep mode
  Future<void> _deactivateSleepMode() async {
    if (!_isSleepModeActive) return;

    print(
      'SLEEP DEBUG: Beginning sleep mode deactivation at ${DateTime.now().toIso8601String()}',
    );

    try {
      // Restore previous brightness if available, otherwise set to full brightness
      if (_previousBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_previousBrightness!);
      } else {
        await ScreenBrightness().setScreenBrightness(1.0);
      }

      _isSleepModeActive = false;

      // Also update system UI style for consistency
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarBrightness: Brightness.light),
      );

      // Call the callback if registered
      print(
        'SLEEP DEBUG: Calling sleep mode deactivated callback at ${DateTime.now().toIso8601String()}',
      );
      _onSleepModeDeactivated?.call();

      // Notify listeners through the stream
      print(
        'SLEEP DEBUG: Notifying stream listeners of sleep mode deactivation',
      );
      _sleepModeStateController.add(false);

      print(
        'SLEEP DEBUG: Sleep mode deactivation completed at ${DateTime.now().toIso8601String()}',
      );
    } catch (e) {
      print('Error deactivating sleep mode: $e');
    }
  }

  /// Register callbacks for sleep mode state changes
  void registerCallbacks({
    VoidCallback? onSleepModeActivated,
    VoidCallback? onSleepModeDeactivated,
  }) {
    _onSleepModeActivated = onSleepModeActivated;
    _onSleepModeDeactivated = onSleepModeDeactivated;
  }

  /// Get the current sleep mode state
  bool get isSleepModeActive => _isSleepModeActive;

  /// Get the current inactivity threshold in minutes
  int get inactivityThresholdMinutes => _inactivityThreshold.inMinutes;

  /// Get the current heartbeat interval in seconds
  int get heartbeatIntervalSeconds => _heartbeatInterval.inSeconds;

  /// Dispose the power saving manager
  void dispose() {
    _inactivityTimer?.cancel();
    _sleepModeStateController.close();
    print('Power saving manager disposed');
  }
}
