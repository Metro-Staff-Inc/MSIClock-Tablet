import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
class AppTheme {
  // Colors
  static const Color windowBackground = Color(0xFF121212);
  static const Color frontFrames = Color(0xFF303030);
  static const Color darkerFrames = Color(0xFF212121);
  static const Color mainGreen = Color(0xFFA4D233);
  static const Color hoverGreen = Color(0xFF8AB22B);
  static const Color defaultText = Color(0xFFF0F0F0);
  static const Color errorColor = Color(0xFFFF3B30);
  static const Color successColor = Color(0xFF34C759);
  static const Color warningColor = Color(0xFFF39C12);
  static const Color numberKeys = Color(0xFF4169E1);
  static const Color backspaceKey = Color(0xFFFFD700);
  static const Color clearKey = Color(0xFFFF4040);
  static const Color confirmationKey = mainGreen;
  // Theme data
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: windowBackground,
      colorScheme: const ColorScheme.dark(
        primary: mainGreen,
        secondary: hoverGreen,
        surface: frontFrames,
        error: errorColor,
        onPrimary: windowBackground,
        onSecondary: windowBackground,
        onSurface: defaultText,
        onError: defaultText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkerFrames,
        foregroundColor: defaultText,
      ),
      cardTheme: const CardTheme(color: frontFrames),
      dialogTheme: const DialogTheme(backgroundColor: frontFrames),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
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
          borderSide: const BorderSide(color: mainGreen),
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
          fontWeight: FontWeight.w500, // Medium
          color: defaultText,
        ),
        bodyLarge: GoogleFonts.roboto(color: defaultText),
        bodyMedium: GoogleFonts.roboto(color: defaultText),
        bodySmall: GoogleFonts.roboto(color: defaultText),
      ),
    );
  }
  // Custom button styles
  static ButtonStyle get numberKeyStyle => ElevatedButton.styleFrom(
    backgroundColor: numberKeys,
    foregroundColor: defaultText,
    minimumSize: const Size(80, 80),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
  static ButtonStyle get backspaceKeyStyle => ElevatedButton.styleFrom(
    backgroundColor: backspaceKey,
    foregroundColor: windowBackground,
    minimumSize: const Size(80, 80),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
  static ButtonStyle get clearKeyStyle => ElevatedButton.styleFrom(
    backgroundColor: clearKey,
    foregroundColor: defaultText,
    minimumSize: const Size(80, 80),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
  static ButtonStyle get confirmationKeyStyle => ElevatedButton.styleFrom(
    backgroundColor: confirmationKey,
    foregroundColor: windowBackground,
    minimumSize: const Size(80, 80),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}
