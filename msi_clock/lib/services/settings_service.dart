import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/soap_config.dart';

class SettingsService {
  static const String _settingsFileName = 'settings.json';
  static final SettingsService _instance = SettingsService._internal();

  // Default settings with the provided credentials
  static final Map<String, dynamic> _defaultSettings = {
    'soap': {
      'username': 'SG360WolfBackdoor',
      'password': 'summer2014',
      'clientId': '309',
    },
  };

  // In-memory settings for testing or when file access fails
  Map<String, dynamic>? _inMemorySettings;

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  Future<Map<String, dynamic>> loadSettings() async {
    try {
      // If we have in-memory settings, use those
      if (_inMemorySettings != null) {
        return _inMemorySettings!;
      }

      try {
        final file = await _getLocalFile();

        // If file doesn't exist, create it with default settings
        if (!await file.exists()) {
          await saveSettings(_defaultSettings);
          return _defaultSettings;
        }

        // Read the file
        final contents = await file.readAsString();
        return json.decode(contents) as Map<String, dynamic>;
      } catch (e) {
        // If file access fails, use in-memory settings
        print('Warning: Using in-memory settings due to error: $e');
        _inMemorySettings = Map<String, dynamic>.from(_defaultSettings);
        return _inMemorySettings!;
      }
    } catch (e) {
      print('Error loading settings: $e');
      // Return default settings if there's an error
      return _defaultSettings;
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      // Always update in-memory settings
      _inMemorySettings = Map<String, dynamic>.from(settings);

      try {
        // Try to save to file
        final file = await _getLocalFile();
        await file.writeAsString(json.encode(settings));
      } catch (e) {
        // If file access fails, just keep in-memory settings
        print('Warning: Settings saved only in memory due to error: $e');
      }
    } catch (e) {
      print('Error saving settings: $e');
      rethrow;
    }
  }

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_settingsFileName');
  }

  Future<SoapConfig> getSoapConfig() async {
    final settings = await loadSettings();
    final soapSettings = settings['soap'] as Map<String, dynamic>;

    // Get endpoint from settings or use default if not present
    String endpoint = 'https://msiwebtrax.com';

    // Check if there's a custom endpoint in settings
    if (settings.containsKey('endpoint') && settings['endpoint'] is String) {
      endpoint = settings['endpoint'] as String;
    }

    // Check if there's a fallback endpoint in settings
    List<String> fallbackEndpoints = [];
    if (settings.containsKey('fallbackEndpoints') &&
        settings['fallbackEndpoints'] is List) {
      fallbackEndpoints =
          (settings['fallbackEndpoints'] as List).whereType<String>().toList();
    }

    // If no fallback endpoints are configured, add some defaults
    if (fallbackEndpoints.isEmpty) {
      fallbackEndpoints = [
        'http://msiwebtrax.com', // Try HTTP if HTTPS fails
        'https://msiwebtrax.com:443', // Try explicit port
      ];
    }

    return SoapConfig(
      endpoint: endpoint,
      fallbackEndpoints: fallbackEndpoints,
      username: soapSettings['username'] as String? ?? '',
      password: soapSettings['password'] as String? ?? '',
      clientId: soapSettings['clientId'] as String? ?? '',
      timeout: const Duration(seconds: 30),
    );
  }

  /// Updates the SOAP endpoint
  Future<void> updateSoapEndpoint(String endpoint) async {
    final settings = await loadSettings();
    settings['endpoint'] = endpoint;
    await saveSettings(settings);
  }

  Future<void> updateSoapCredentials({
    required String username,
    required String password,
    required String clientId,
  }) async {
    final settings = await loadSettings();

    settings['soap'] = {
      'username': username,
      'password': password,
      'clientId': clientId,
    };

    await saveSettings(settings);
  }

  /// Updates the admin password
  Future<void> updateAdminPassword(String password) async {
    final settings = await loadSettings();

    // Add or update the admin password in settings
    settings['adminPassword'] = password;

    await saveSettings(settings);
  }

  /// Get the admin password from settings or return the default if not found
  Future<String> getAdminPassword() async {
    final settings = await loadSettings();

    // Return the admin password from settings or the default
    return settings.containsKey('adminPassword')
        ? settings['adminPassword'] as String
        : '1234'; // Default password
  }
}
