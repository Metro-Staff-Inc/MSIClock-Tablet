import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../services/battery_monitor_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/punch_provider.dart';
import '../services/power_saving_manager.dart';
import '../services/logger_service.dart';
import '../services/log_upload_service.dart';
import '../services/punch_sync_service.dart';
import '../services/punch_export_service.dart';
import '../services/punch_database_service.dart';

// Method channel for device information
const platform = MethodChannel('com.example.msi_clock/device_info');

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settings = SettingsService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _endpointController = TextEditingController();
  final _newAdminPasswordController = TextEditingController();
  final _confirmAdminPasswordController = TextEditingController();
  // Device information
  final _deviceNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _macAddressController = TextEditingController();
  final _batteryApiEndpointController = TextEditingController();
  bool _isLoadingMacAddress = true;
  bool _isPushingBatteryData = false;
  bool _isLoading = true;
  bool _showNewAdminPassword =
      false; // Toggle for new admin password visibility
  bool _showConfirmAdminPassword =
      false; // Toggle for confirm admin password visibility
  String? _error;
  // Camera settings
  bool _isCameraEnabled = true;
  String? _selectedImagePath;
  File? _selectedImageFile;
  final ImagePicker _imagePicker = ImagePicker();
  // Power saving settings
  final PowerSavingManager _powerSavingManager = PowerSavingManager();
  final _inactivityThresholdController = TextEditingController();
  final _heartbeatIntervalController = TextEditingController();
  // For update functionality
  final UpdateService _updateService = UpdateService();
  String _appVersion = "";
  bool _checkingForUpdates = false;
  String? _updateMessage;
  bool _updateAvailable = false;
  Map<String, dynamic>? _updateInfo;
  bool _downloading = false;
  double _downloadProgress = 0.0;
  // Logging settings
  final LoggerService _loggerService = LoggerService();
  final LogUploadService _logUploadService = LogUploadService();
  String _logLevel = 'normal';
  bool _uploadingLogs = false;
  // Punch database settings
  final PunchSyncService _punchSyncService = PunchSyncService();
  final PunchExportService _punchExportService = PunchExportService();
  final PunchDatabaseService _punchDatabaseService = PunchDatabaseService();
  final _punchRetentionDaysController = TextEditingController();
  bool _syncingPunches = false;
  bool _exportingPunches = false;
  Map<String, int>? _punchStats;
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
    _loadCameraSettings();
    _loadMacAddress();
    _loadPowerSavingSettings();
    _loadLoggingSettings();
    _loadPunchDatabaseSettings();
  }

  /// Load the current app version
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {}
  }

  /// Check for app updates
  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingForUpdates = true;
      _updateMessage = null;
      _updateAvailable = false;
      _updateInfo = null;
    });
    try {
      final updateInfo = await _updateService.checkForUpdate();
      setState(() {
        _checkingForUpdates = false;
        if (updateInfo.containsKey('error')) {
          _updateMessage = updateInfo['error'];
        } else if (updateInfo['isUpdateAvailable'] == true) {
          _updateAvailable = true;
          _updateInfo = updateInfo;
          _updateMessage = 'Update available: ${updateInfo['latestVersion']}';
        } else {
          _updateMessage = 'You have the latest version.';
        }
      });
      // Show update dialog if update is available
      if (_updateAvailable && _updateInfo != null) {
        final shouldUpdate = await _updateService.showUpdateDialog(
          context,
          _updateInfo!,
        );
        if (shouldUpdate && _updateInfo!['downloadUrl'] != null) {
          _downloadAndInstallUpdate(_updateInfo!['downloadUrl']);
        }
      }
    } catch (e) {
      setState(() {
        _checkingForUpdates = false;
        _updateMessage = 'Error checking for updates: $e';
      });
    }
  }

  /// Download and install update
  void _downloadAndInstallUpdate(String url) {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });
    _updateService.downloadAndInstallUpdate(
      url,
      (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
      (error) {
        setState(() {
          _downloading = false;
          _updateMessage = error;
        });
      },
      () {
        setState(() {
          _downloading = false;
        });
      },
    );
  }

  /// Load power saving settings
  Future<void> _loadPowerSavingSettings() async {
    setState(() {
      _inactivityThresholdController.text =
          _powerSavingManager.inactivityThresholdMinutes.toString();
      _heartbeatIntervalController.text =
          _powerSavingManager.heartbeatIntervalSeconds.toString();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _clientIdController.dispose();
    _endpointController.dispose();
    _newAdminPasswordController.dispose();
    _confirmAdminPasswordController.dispose();
    _deviceNameController.dispose();
    _locationController.dispose();
    _macAddressController.dispose();
    _batteryApiEndpointController.dispose();
    _inactivityThresholdController.dispose();
    _heartbeatIntervalController.dispose();
    super.dispose();
  }

  /// Load camera settings from AppConfig
  Future<void> _loadCameraSettings() async {
    try {
      _isCameraEnabled = await AppConfig.isCameraEnabled();
      _selectedImagePath = await AppConfig.getSelectedImagePath();
      if (_selectedImagePath != null) {
        _selectedImageFile = File(_selectedImagePath!);
        if (!await _selectedImageFile!.exists()) {
          _selectedImageFile = null;
          _selectedImagePath = null;
        }
      }
      setState(() {});
    } catch (e) {
      // Default to camera enabled if there's an error
      setState(() {
        _isCameraEnabled = true;
        _selectedImagePath = null;
        _selectedImageFile = null;
      });
    }
  }

  /// Pick an image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImagePath = pickedFile.path;
          _selectedImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  /// Load the device's MAC address
  Future<void> _loadMacAddress() async {
    setState(() {
      _isLoadingMacAddress = true;
    });
    try {
      String macAddress;
      // Try to get MAC address through platform-specific code
      try {
        // Call native method to get MAC address
        macAddress = await platform.invokeMethod('getMacAddress');
      } catch (methodError) {
        macAddress = 'Not available';
      }
      // If we couldn't get the MAC address, use a placeholder
      if (macAddress.isEmpty) {
        macAddress = 'Unknown';
      }
      setState(() {
        _macAddressController.text = macAddress;
        _isLoadingMacAddress = false;
      });
    } catch (e) {
      setState(() {
        _macAddressController.text = 'Error: Could not retrieve';
        _isLoadingMacAddress = false;
      });
    }
  }

  /// Load logging settings
  Future<void> _loadLoggingSettings() async {
    try {
      final level = await _settings.getLogLevel();
      setState(() {
        _logLevel = level;
      });
    } catch (e) {
      setState(() {
        _logLevel = 'normal';
      });
    }
  }

  /// Manually upload logs to R2
  Future<void> _uploadLogs() async {
    setState(() {
      _uploadingLogs = true;
    });
    try {
      final success = await _logUploadService.manualUpload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Logs uploaded successfully'
                  : 'Failed to upload logs. Check R2 configuration.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _uploadingLogs = false;
      });
    }
  }

  /// Load punch database settings
  Future<void> _loadPunchDatabaseSettings() async {
    try {
      final retentionDays = await _settings.getPunchRetentionDays();
      final stats = await _punchDatabaseService.getStatistics();
      setState(() {
        _punchRetentionDaysController.text = retentionDays.toString();
        _punchStats = stats;
      });
    } catch (e) {
      setState(() {
        _punchRetentionDaysController.text = '30';
        _punchStats = {'total': 0, 'synced': 0, 'unsynced': 0};
      });
    }
  }

  /// Manually sync unsynced punches
  Future<void> _syncPunches() async {
    setState(() {
      _syncingPunches = true;
    });
    try {
      final result = await _punchSyncService.manualSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync completed: ${result['succeeded']} succeeded, ${result['failed']} failed',
            ),
            backgroundColor:
                result['failed'] == 0 ? Colors.green : Colors.orange,
          ),
        );
      }
      // Reload stats
      await _loadPunchDatabaseSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing punches: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _syncingPunches = false;
      });
    }
  }

  /// Export and upload punch database
  Future<void> _exportPunchDatabase() async {
    setState(() {
      _exportingPunches = true;
    });
    try {
      final result = await _punchExportService.exportAndUpload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['success']
                  ? 'Exported: ${result['txtFileName']} and ${result['csvFileName']}'
                  : 'Failed to export punch database. Check R2 configuration.',
            ),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );
      }
      // Reload stats after export
      await _loadPunchDatabaseSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting punch database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _exportingPunches = false;
      });
    }
  }

  /// Clear all punches from database
  Future<void> _clearPunchDatabase() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.frontFrames,
            title: Text(
              'Clear Database?',
              style: TextStyle(color: AppTheme.defaultText),
            ),
            content: Text(
              'This will permanently delete ALL punch records from the database. This action cannot be undone.\n\nAre you sure?',
              style: TextStyle(color: AppTheme.defaultText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.defaultText),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.2),
                ),
                child: const Text(
                  'Clear Database',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final deletedCount = await _punchDatabaseService.clearAllPunches();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database cleared: $deletedCount records deleted'),
            backgroundColor: AppTheme.mainGreen,
          ),
        );
      }
      // Reload stats
      await _loadPunchDatabaseSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Manually push battery data to the API
  Future<void> _pushBatteryData() async {
    setState(() {
      _isPushingBatteryData = true;
    });
    try {
      // Get the battery monitor service
      final batteryMonitorService = BatteryMonitorService();
      // Trigger a manual report
      await batteryMonitorService.triggerManualReport();
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Battery data sent successfully'),
            backgroundColor: AppTheme.mainGreen,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send battery data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isPushingBatteryData = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);
      final settings = await _settings.loadSettings();
      final soapSettings = settings['soap'] as Map<String, dynamic>;
      // Get the endpoint from settings or use default
      String endpoint = 'https://msiwebtrax.com';
      if (settings.containsKey('endpoint') && settings['endpoint'] is String) {
        endpoint = settings['endpoint'] as String;
      }
      // Load device information
      if (settings.containsKey('battery') &&
          settings['battery'] is Map<String, dynamic>) {
        final batterySettings = settings['battery'] as Map<String, dynamic>;
        _deviceNameController.text =
            batterySettings['deviceName'] as String? ?? 'MSI-Tablet';
        _locationController.text =
            batterySettings['location'] as String? ?? 'Unknown';
        _batteryApiEndpointController.text =
            batterySettings['apiEndpoint'] as String? ??
            'https://battery-monitor-api.onrender.com';
      } else {
        // Default values
        _deviceNameController.text = 'MSI-Tablet';
        _locationController.text = 'Unknown';
        _batteryApiEndpointController.text =
            'https://battery-monitor-api.onrender.com';
      }
      setState(() {
        _usernameController.text = soapSettings['username'] as String;
        _passwordController.text = soapSettings['password'] as String;
        _clientIdController.text = soapSettings['clientId'] as String;
        _endpointController.text = endpoint;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      setState(() => _isLoading = true);
      // Update SOAP credentials
      await AppConfig.updateSoapCredentials(
        username: _usernameController.text,
        password: _passwordController.text,
        clientId: _clientIdController.text,
      );
      // Update endpoint
      await _settings.updateSoapEndpoint(_endpointController.text);
      // Update camera settings
      await AppConfig.updateCameraSettings(
        isEnabled: _isCameraEnabled,
        selectedImagePath: _selectedImagePath,
      );
      // Update device information including battery API endpoint
      await _settings.updateBatterySettings(
        apiEndpoint: _batteryApiEndpointController.text,
        deviceName: _deviceNameController.text,
        location: _locationController.text,
      );
      // Update power saving settings
      await _powerSavingManager.saveSettings(
        inactivityThresholdMinutes:
            int.tryParse(_inactivityThresholdController.text) ?? 2,
        heartbeatIntervalSeconds:
            int.tryParse(_heartbeatIntervalController.text) ?? 30,
      );
      // Update logging level
      await _settings.updateLogLevel(_logLevel);
      await _loggerService.setLogLevel(
        _logLevel == 'debug' ? LogLevel.debug : LogLevel.normal,
      );
      // Update punch retention days
      final retentionDays =
          int.tryParse(_punchRetentionDaysController.text) ?? 30;
      await _settings.updatePunchRetentionDays(retentionDays);
      // Update admin password if provided
      if (_newAdminPasswordController.text.isNotEmpty) {
        // Validate that passwords match
        if (_newAdminPasswordController.text !=
            _confirmAdminPasswordController.text) {
          setState(() {
            _error = "New admin passwords do not match";
            _isLoading = false;
          });
          return;
        }
        // Update the admin password
        await _settings.updateAdminPassword(_newAdminPasswordController.text);
        // Clear the admin password cache to ensure the new password is used immediately
        AppConfig.clearAdminPasswordCache();
        // Clear the password fields after successful update
        setState(() {
          _newAdminPasswordController.clear();
          _confirmAdminPasswordController.clear();
        });
      }
      // Update the PunchProvider with new settings
      if (mounted) {
        final provider = Provider.of<PunchProvider>(context, listen: false);
        // Update camera settings
        await provider.updateCameraSettings(
          isEnabled: _isCameraEnabled,
          selectedImagePath: _selectedImagePath,
        );
        // Reload SOAP configuration to apply new settings immediately
        await provider.reloadSoapConfig();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = 'Failed to save settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        backgroundColor: AppTheme.darkerFrames,
        foregroundColor: AppTheme.defaultText,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      // Device Information Section
                      Text(
                        'Device Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.defaultText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Device Name
                      TextFormField(
                        controller: _deviceNameController,
                        decoration: InputDecoration(
                          labelText: 'Device Name',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                          hintText: 'MSI-Tablet',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter device name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Location
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Location',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                          hintText: 'Front Desk',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // MAC Address (read-only)
                      TextFormField(
                        controller: _macAddressController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'MAC Address',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                          hintText: 'Loading...',
                          suffixIcon:
                              _isLoadingMacAddress
                                  ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.mainGreen,
                                      ),
                                    ),
                                  )
                                  : Icon(
                                    Icons.computer,
                                    color: AppTheme.defaultText.withOpacity(
                                      0.7,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Battery API Endpoint
                      TextFormField(
                        controller: _batteryApiEndpointController,
                        decoration: InputDecoration(
                          labelText: 'Battery API Endpoint',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                          hintText: 'https://battery-monitor-api.onrender.com',
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Push Battery Data Button
                      ElevatedButton.icon(
                        icon:
                            _isPushingBatteryData
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Icon(Icons.battery_full),
                        label: Text(
                          _isPushingBatteryData
                              ? 'Sending...'
                              : 'Push Battery Data',
                        ),
                        onPressed:
                            _isPushingBatteryData ? null : _pushBatteryData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mainGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // SOAP Configuration Section
                      Text(
                        'SOAP Configuration',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.defaultText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Username
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Password (no longer obscured)
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Client ID
                      TextFormField(
                        controller: _clientIdController,
                        decoration: InputDecoration(
                          labelText: 'Client ID',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter client ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Endpoint URL
                      TextFormField(
                        controller: _endpointController,
                        decoration: InputDecoration(
                          labelText: 'SOAP Endpoint URL',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                          hintText: 'https://msiwebtrax.com',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter endpoint URL';
                          }
                          if (!value.startsWith('http://') &&
                              !value.startsWith('https://')) {
                            return 'URL must start with http:// or https://';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If you are experiencing connection issues, try changing the endpoint URL.',
                        style: TextStyle(
                          color: AppTheme.defaultText.withOpacity(0.7),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Power Saving Settings Section
                      Text(
                        'Power Saving Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.defaultText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Inactivity Threshold
                      TextFormField(
                        controller: _inactivityThresholdController,
                        decoration: InputDecoration(
                          labelText: 'Inactivity Threshold (minutes)',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                          hintText: '2',
                          helperText: 'Time before entering sleep mode',
                          helperStyle: TextStyle(
                            color: AppTheme.defaultText.withOpacity(0.7),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a value';
                          }
                          final threshold = int.tryParse(value);
                          if (threshold == null || threshold <= 0) {
                            return 'Please enter a positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // SOAP Heartbeat Interval
                      TextFormField(
                        controller: _heartbeatIntervalController,
                        decoration: InputDecoration(
                          labelText: 'SOAP Heartbeat Interval (seconds)',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                          hintText: '30',
                          helperText: 'How often to check SOAP connection',
                          helperStyle: TextStyle(
                            color: AppTheme.defaultText.withOpacity(0.7),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a value';
                          }
                          final interval = int.tryParse(value);
                          if (interval == null || interval <= 0) {
                            return 'Please enter a positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      // Admin Password Section
                      Text(
                        'Admin Password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.defaultText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // New Admin Password
                      TextFormField(
                        controller: _newAdminPasswordController,
                        decoration: InputDecoration(
                          labelText: 'New Admin Password',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showNewAdminPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppTheme.defaultText.withOpacity(0.7),
                            ),
                            onPressed: () {
                              setState(() {
                                _showNewAdminPassword = !_showNewAdminPassword;
                              });
                            },
                          ),
                        ),
                        obscureText: !_showNewAdminPassword,
                      ),
                      const SizedBox(height: 16),
                      // Confirm Admin Password
                      TextFormField(
                        controller: _confirmAdminPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Admin Password',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showConfirmAdminPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppTheme.defaultText.withOpacity(0.7),
                            ),
                            onPressed: () {
                              setState(() {
                                _showConfirmAdminPassword =
                                    !_showConfirmAdminPassword;
                              });
                            },
                          ),
                        ),
                        obscureText: !_showConfirmAdminPassword,
                        validator: (_) {
                          if (_newAdminPasswordController.text.isNotEmpty &&
                              _newAdminPasswordController.text !=
                                  _confirmAdminPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      // Camera Settings Section
                      Text(
                        'Camera Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.defaultText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Camera Enable/Disable Toggle
                      Row(
                        children: [
                          Text(
                            'Enable Camera',
                            style: TextStyle(
                              color: AppTheme.defaultText,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _isCameraEnabled,
                            onChanged: (value) {
                              setState(() {
                                _isCameraEnabled = value;
                              });
                            },
                            activeColor: AppTheme.mainGreen,
                          ),
                        ],
                      ),
                      // Image selection (only visible when camera is disabled)
                      if (!_isCameraEnabled) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Select Image to Display',
                          style: TextStyle(
                            color: AppTheme.defaultText,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkerFrames.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.frontFrames,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _selectedImagePath != null
                                      ? _selectedImagePath!.split('/').last
                                      : 'No image selected',
                                  style: TextStyle(
                                    color: AppTheme.defaultText,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Browse'),
                              onPressed: _pickImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.mainGreen,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        // Image preview
                        if (_selectedImageFile != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Preview',
                            style: TextStyle(
                              color: AppTheme.defaultText,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppTheme.darkerFrames,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.frontFrames,
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImageFile!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 32),
                      // Version and Updates Section
                      Text(
                        'App Version and Updates',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.defaultText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Current version display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkerFrames.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current version: $_appVersion',
                              style: TextStyle(
                                color: AppTheme.defaultText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              icon:
                                  _checkingForUpdates
                                      ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : const Icon(Icons.refresh, size: 20),
                              label: Text(
                                _checkingForUpdates
                                    ? 'Checking...'
                                    : 'Check for Updates',
                              ),
                              onPressed:
                                  _checkingForUpdates ? null : _checkForUpdates,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.mainGreen,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Update status message
                      if (_updateMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            _updateMessage!,
                            style: TextStyle(
                              color:
                                  _updateAvailable
                                      ? AppTheme.mainGreen
                                      : AppTheme.defaultText,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      // Download progress indicator
                      if (_downloading)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Downloading update: ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(color: AppTheme.defaultText),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: _downloadProgress,
                                backgroundColor: Colors.grey[700],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.mainGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 32),
                      // Logging Settings Section
                      Text(
                        'Logging Settings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.defaultText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.frontFrames,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Log Level',
                              style: TextStyle(
                                color: AppTheme.defaultText,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text(
                                      'NORMAL',
                                      style: TextStyle(
                                        color: AppTheme.defaultText,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Punch data only',
                                      style: TextStyle(
                                        color: AppTheme.defaultText.withOpacity(
                                          0.7,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                    value: 'normal',
                                    groupValue: _logLevel,
                                    activeColor: AppTheme.mainGreen,
                                    onChanged: (value) {
                                      setState(() {
                                        _logLevel = value!;
                                      });
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text(
                                      'DEBUG',
                                      style: TextStyle(
                                        color: AppTheme.defaultText,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'All logging',
                                      style: TextStyle(
                                        color: AppTheme.defaultText.withOpacity(
                                          0.7,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                    value: 'debug',
                                    groupValue: _logLevel,
                                    activeColor: AppTheme.mainGreen,
                                    onChanged: (value) {
                                      setState(() {
                                        _logLevel = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(
                              color: AppTheme.defaultText.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Log Management',
                              style: TextStyle(
                                color: AppTheme.defaultText,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '• Logs are stored for 10 days\n'
                              '• Each day creates a new log file\n'
                              '• Logs auto-upload to R2 at 2 AM daily\n'
                              '• Log directory: ${_loggerService.logDirectoryPath ?? "Not initialized"}',
                              style: TextStyle(
                                color: AppTheme.defaultText.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon:
                                  _uploadingLogs
                                      ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : const Icon(
                                        Icons.cloud_upload,
                                        size: 20,
                                      ),
                              label: Text(
                                _uploadingLogs
                                    ? 'Uploading...'
                                    : 'Upload Yesterday\'s Logs Now',
                              ),
                              onPressed: _uploadingLogs ? null : _uploadLogs,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.mainGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Punch Database Settings Section
                      Text(
                        'Punch Database',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.defaultText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.frontFrames,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Database Statistics',
                              style: TextStyle(
                                color: AppTheme.defaultText,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_punchStats != null) ...[
                              Text(
                                '• Total Punches: ${_punchStats!['total']}\n'
                                '• Synced: ${_punchStats!['synced']}\n'
                                '• Unsynced: ${_punchStats!['unsynced']}',
                                style: TextStyle(
                                  color: AppTheme.defaultText.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Loading statistics...',
                                style: TextStyle(
                                  color: AppTheme.defaultText.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Divider(
                              color: AppTheme.defaultText.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Data Retention',
                              style: TextStyle(
                                color: AppTheme.defaultText,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _punchRetentionDaysController,
                              decoration: InputDecoration(
                                labelText: 'Keep Punches For (Days)',
                                labelStyle: TextStyle(
                                  color: AppTheme.defaultText.withOpacity(0.7),
                                ),
                                hintText: '30',
                                hintStyle: TextStyle(
                                  color: AppTheme.defaultText.withOpacity(0.5),
                                ),
                                filled: true,
                                fillColor: AppTheme.windowBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: TextStyle(color: AppTheme.defaultText),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter retention days';
                                }
                                final days = int.tryParse(value);
                                if (days == null || days < 1) {
                                  return 'Must be at least 1 day';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '• Punches older than this will be automatically deleted\n'
                              '• All punches are stored locally first\n'
                              '• Unsynced punches retry automatically every 5 minutes',
                              style: TextStyle(
                                color: AppTheme.defaultText.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(
                              color: AppTheme.defaultText.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Database Management',
                              style: TextStyle(
                                color: AppTheme.defaultText,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon:
                                        _syncingPunches
                                            ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                            : const Icon(Icons.sync, size: 20),
                                    label: Text(
                                      _syncingPunches
                                          ? 'Syncing...'
                                          : 'Sync Now',
                                    ),
                                    onPressed:
                                        _syncingPunches ? null : _syncPunches,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.mainGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon:
                                        _exportingPunches
                                            ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                            : const Icon(
                                              Icons.upload_file,
                                              size: 20,
                                            ),
                                    label: Text(
                                      _exportingPunches
                                          ? 'Exporting...'
                                          : 'Export to R2',
                                    ),
                                    onPressed:
                                        _exportingPunches
                                            ? null
                                            : _exportPunchDatabase,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.mainGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Clear Database Button
                            ElevatedButton.icon(
                              icon: const Icon(Icons.delete_forever, size: 20),
                              label: const Text('Clear Database'),
                              onPressed: _clearPunchDatabase,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '⚠️ Warning: This will permanently delete all punch records',
                              style: TextStyle(
                                color: Colors.red.withOpacity(0.8),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Save Button
                      ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.mainGreen,
                          foregroundColor: AppTheme.windowBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Close App Button
                      ElevatedButton(
                        onPressed: () {
                          // Show a confirmation dialog before closing
                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                backgroundColor: AppTheme.darkerFrames,
                                title: Text(
                                  'Confirm Exit',
                                  style: TextStyle(color: AppTheme.defaultText),
                                ),
                                content: Text(
                                  'Are you sure you want to close the application?',
                                  style: TextStyle(color: AppTheme.defaultText),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(
                                        dialogContext,
                                      ).pop(); // Close dialog
                                    },
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: AppTheme.mainGreen,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      // Close dialog first
                                      Navigator.of(dialogContext).pop();
                                      // First try to exit kiosk mode if on Android
                                      if (Platform.isAndroid) {
                                        try {
                                          const kioskPlatform = MethodChannel(
                                            'com.example.msi_clock/kiosk',
                                          );
                                          await kioskPlatform.invokeMethod(
                                            'exitKioskMode',
                                          );
                                          // Give a short delay for kiosk mode to exit
                                          await Future.delayed(
                                            const Duration(milliseconds: 500),
                                          );
                                        } catch (e) {}
                                      }
                                      // Then close the app
                                      SystemNavigator.pop();
                                    },
                                    child: Text(
                                      'Close App',
                                      style: TextStyle(
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Close Application',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
