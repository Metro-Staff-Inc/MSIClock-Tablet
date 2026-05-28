import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemeData {
  final String id;
  final String displayName;
  final String appTitle;
  final String defaultLogoAsset;

  final Color windowBackground;
  final Color frontFrames;
  final Color darkerFrames;
  final Color mainGreen;
  final Color hoverGreen;
  final Color defaultText;
  final Color errorColor;
  final Color successColor;
  final Color warningColor;
  final Color numberKeys;
  final Color backspaceKey;
  final Color clearKey;

  const AppThemeData({
    required this.id,
    required this.displayName,
    required this.appTitle,
    required this.defaultLogoAsset,
    required this.windowBackground,
    required this.frontFrames,
    required this.darkerFrames,
    required this.mainGreen,
    required this.hoverGreen,
    required this.defaultText,
    required this.errorColor,
    required this.successColor,
    required this.warningColor,
    required this.numberKeys,
    required this.backspaceKey,
    required this.clearKey,
  });

  Color get confirmationKey => mainGreen;

  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: windowBackground,
      colorScheme: ColorScheme.dark(
        primary: mainGreen,
        secondary: hoverGreen,
        surface: frontFrames,
        error: errorColor,
        onPrimary: windowBackground,
        onSecondary: windowBackground,
        onSurface: defaultText,
        onError: defaultText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkerFrames,
        foregroundColor: defaultText,
      ),
      cardTheme: CardTheme(color: frontFrames),
      dialogTheme: DialogTheme(backgroundColor: frontFrames),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: mainGreen,
        foregroundColor: windowBackground,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mainGreen,
          foregroundColor: windowBackground,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: mainGreen),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkerFrames,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: mainGreen),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.ibmPlexSansCondensed(
          fontWeight: FontWeight.bold,
          color: defaultText,
        ),
        displayMedium: GoogleFonts.ibmPlexSansCondensed(
          fontWeight: FontWeight.bold,
          color: defaultText,
        ),
        displaySmall: GoogleFonts.ibmPlexSansCondensed(
          fontWeight: FontWeight.bold,
          color: defaultText,
        ),
        headlineMedium: GoogleFonts.ibmPlexSans(
          fontWeight: FontWeight.w500,
          color: defaultText,
        ),
        bodyLarge: GoogleFonts.roboto(color: defaultText),
        bodyMedium: GoogleFonts.roboto(color: defaultText),
        bodySmall: GoogleFonts.roboto(color: defaultText),
      ),
    );
  }
}

/// Bundled theme presets. To add a new client, add an entry here and
/// drop their logo in assets/images/, then list it in pubspec.yaml.
const Map<String, AppThemeData> themePresets = {
  'msi': AppThemeData(
    id: 'msi',
    displayName: 'Metro Staff',
    appTitle: 'MSI Clock',
    defaultLogoAsset: 'assets/images/msi_logo.png',
    windowBackground: Color(0xFF121212),
    frontFrames: Color(0xFF303030),
    darkerFrames: Color(0xFF212121),
    mainGreen: Color(0xFFA4D233),
    hoverGreen: Color(0xFF8AB22B),
    defaultText: Color(0xFFF0F0F0),
    errorColor: Color(0xFFFF3B30),
    successColor: Color(0xFF34C759),
    warningColor: Color(0xFFF39C12),
    numberKeys: Color(0xFF4169E1),
    backspaceKey: Color(0xFFFFD700),
    clearKey: Color(0xFFFF4040),
  ),
  'bac': AppThemeData(
    id: 'bac',
    displayName: 'BAC',
    appTitle: 'BAC Time Clock',
    defaultLogoAsset: 'assets/images/bac_logo.png',
    windowBackground: Color(0xFF303030),
    frontFrames: Color(0xFF303030),
    darkerFrames: Color(0xFF212121),
    mainGreen: Color.fromARGB(255, 150, 0, 0),
    hoverGreen: Color.fromARGB(255, 178, 43, 43),
    defaultText: Color(0xFFF0F0F0),
    errorColor: Color(0xFFFF3B30),
    successColor: Color(0xFF34C759),
    warningColor: Color(0xFFF39C12),
    numberKeys: Color(0xFF4169E1),
    backspaceKey: Color(0xFFFFD700),
    clearKey: Color(0xFFFF4040),
  ),
};

const String defaultThemeId = 'msi';

AppThemeData themeForId(String? id) {
  return themePresets[id] ?? themePresets[defaultThemeId]!;
}
