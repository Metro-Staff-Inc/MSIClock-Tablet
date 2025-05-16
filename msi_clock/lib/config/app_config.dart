import '../models/soap_config.dart';
import '../services/settings_service.dart';

class AppConfig {
  static final SettingsService _settings = SettingsService();

  // Admin password cache to avoid repeated async lookups
  static String? _cachedAdminPassword;

  static Future<SoapConfig> getSoapConfig() async {
    return _settings.getSoapConfig();
  }

  static Future<void> updateSoapCredentials({
    required String username,
    required String password,
    required String clientId,
  }) async {
    await _settings.updateSoapCredentials(
      username: username,
      password: password,
      clientId: clientId,
    );
  }

  static Future<void> updateSoapEndpoint(String endpoint) async {
    await _settings.updateSoapEndpoint(endpoint);
  }

  // Add other configuration settings here as needed
  static const bool enableOfflineMode = true;
  static const Duration photoRetentionPeriod = Duration(days: 10);
  static const Duration syncInterval = Duration(minutes: 5);

  // Get admin password (cached or from settings)
  static Future<String> getAdminPassword() async {
    if (_cachedAdminPassword != null) {
      return _cachedAdminPassword!;
    }

    _cachedAdminPassword = await _settings.getAdminPassword();
    return _cachedAdminPassword!;
  }

  // Clear admin password cache (call after password changes)
  static void clearAdminPasswordCache() {
    _cachedAdminPassword = null;
  }
}
