import 'dart:io';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/app_theme_data.dart';
import '../services/settings_service.dart';

class ThemeProvider extends ChangeNotifier {
  final SettingsService _settings = SettingsService();
  AppThemeData _activeTheme;
  String? _customLogoPath;

  ThemeProvider({
    required AppThemeData initialTheme,
    String? initialLogoPath,
  }) : _activeTheme = initialTheme,
       _customLogoPath = initialLogoPath {
    AppTheme.setActive(initialTheme);
  }

  AppThemeData get activeTheme => _activeTheme;
  String? get customLogoPath => _customLogoPath;

  /// Returns the file used for the logo, or null if the bundled asset
  /// should be used. Verifies the file exists before returning it.
  File? get customLogoFile {
    if (_customLogoPath == null) return null;
    final file = File(_customLogoPath!);
    return file.existsSync() ? file : null;
  }

  /// Builds the logo widget — uses uploaded file if available,
  /// otherwise the theme's bundled default asset.
  Widget buildLogo({double? height, double? width, BoxFit? fit}) {
    final file = customLogoFile;
    if (file != null) {
      return Image.file(file, height: height, width: width, fit: fit);
    }
    return Image.asset(
      _activeTheme.defaultLogoAsset,
      height: height,
      width: width,
      fit: fit,
    );
  }

  Future<void> setTheme(String presetId) async {
    final next = themeForId(presetId);
    if (next.id == _activeTheme.id) return;
    _activeTheme = next;
    AppTheme.setActive(next);
    await _settings.updateThemeConfig(
      presetId: next.id,
      logoPath: _customLogoPath,
    );
    notifyListeners();
  }

  Future<void> setLogoPath(String? path) async {
    _customLogoPath = path;
    await _settings.updateThemeConfig(
      presetId: _activeTheme.id,
      logoPath: path,
    );
    notifyListeners();
  }

  static Future<ThemeProvider> load() async {
    final settings = SettingsService();
    final cfg = await settings.getThemeConfig();
    return ThemeProvider(
      initialTheme: themeForId(cfg['presetId'] as String?),
      initialLogoPath: cfg['logoPath'] as String?,
    );
  }
}
