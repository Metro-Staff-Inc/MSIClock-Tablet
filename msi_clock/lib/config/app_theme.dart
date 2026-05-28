import 'package:flutter/material.dart';
import 'app_theme_data.dart';

/// Static facade over the currently-active [AppThemeData].
///
/// Existing call sites use `AppTheme.mainGreen` etc.; those continue to
/// work and now resolve through the active preset. Call [setActive]
/// during app startup and whenever the user picks a new theme.
class AppTheme {
  static AppThemeData _active = themeForId(defaultThemeId);

  static void setActive(AppThemeData theme) {
    _active = theme;
  }

  static AppThemeData get active => _active;

  // Colors
  static Color get windowBackground => _active.windowBackground;
  static Color get frontFrames => _active.frontFrames;
  static Color get darkerFrames => _active.darkerFrames;
  static Color get mainGreen => _active.mainGreen;
  static Color get hoverGreen => _active.hoverGreen;
  static Color get defaultText => _active.defaultText;
  static Color get errorColor => _active.errorColor;
  static Color get successColor => _active.successColor;
  static Color get warningColor => _active.warningColor;
  static Color get numberKeys => _active.numberKeys;
  static Color get backspaceKey => _active.backspaceKey;
  static Color get clearKey => _active.clearKey;
  static Color get confirmationKey => _active.confirmationKey;

  // Theme data
  static ThemeData get darkTheme => _active.toThemeData();

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
