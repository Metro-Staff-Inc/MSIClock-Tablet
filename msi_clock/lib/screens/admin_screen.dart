import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../services/settings_service.dart';
import '../main.dart';
import '../services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/punch_provider.dart';

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
  bool _isLoading = true;
  bool _showPassword = false; // State variable to toggle password visibility
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

  // For update functionality
  final UpdateService _updateService = UpdateService();
  String _appVersion = "";
  bool _checkingForUpdates = false;
  String? _updateMessage;
  bool _updateAvailable = false;
  Map<String, dynamic>? _updateInfo;
  bool _downloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
    _loadCameraSettings();
  }

  /// Load the current app version
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      print('Error loading app version: $e');
    }
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _clientIdController.dispose();
    _endpointController.dispose();
    _newAdminPasswordController.dispose();
    _confirmAdminPasswordController.dispose();
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
      print('Error loading camera settings: $e');
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

      // Update the PunchProvider with new camera settings
      if (mounted) {
        final provider = Provider.of<PunchProvider>(context, listen: false);
        await provider.updateCameraSettings(
          isEnabled: _isCameraEnabled,
          selectedImagePath: _selectedImagePath,
        );
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

                      // SOAP Settings Section
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

                      // Password with visibility toggle
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: AppTheme.defaultText),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppTheme.defaultText.withOpacity(0.7),
                            ),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          ),
                        ),
                        obscureText: !_showPassword, // Toggle based on state
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
                                      // First try to exit kiosk mode if on Android
                                      if (Platform.isAndroid) {
                                        try {
                                          await platform.invokeMethod(
                                            'exitKioskMode',
                                          );
                                          // Give a short delay for kiosk mode to exit
                                          await Future.delayed(
                                            const Duration(milliseconds: 500),
                                          );
                                        } catch (e) {
                                          print('Error exiting kiosk mode: $e');
                                        }
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
