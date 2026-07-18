import 'package:flutter/material.dart';

ThemeData buildLightTheme() => _buildTheme(Brightness.light);

ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFF9DBBFF) : const Color(0xFF2457B8),
    onPrimary: dark ? const Color(0xFF08204E) : Colors.white,
    primaryContainer: dark ? const Color(0xFF173A78) : const Color(0xFFD9E5FF),
    onPrimaryContainer: dark
        ? const Color(0xFFD9E5FF)
        : const Color(0xFF0D1A36),
    secondary: dark ? const Color(0xFF9AD7B7) : const Color(0xFF16734B),
    onSecondary: dark ? const Color(0xFF00391F) : Colors.white,
    secondaryContainer: dark
        ? const Color(0xFF075531)
        : const Color(0xFFD1F0DD),
    onSecondaryContainer: dark
        ? const Color(0xFFB5F2CE)
        : const Color(0xFF062D1A),
    tertiary: dark ? const Color(0xFFFFCB86) : const Color(0xFF946200),
    onTertiary: dark ? const Color(0xFF4D2D00) : Colors.white,
    tertiaryContainer: dark ? const Color(0xFF6E4800) : const Color(0xFFFFE5B5),
    onTertiaryContainer: dark
        ? const Color(0xFFFFDDB0)
        : const Color(0xFF2B1A00),
    error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
    onError: dark ? const Color(0xFF690005) : Colors.white,
    errorContainer: dark ? const Color(0xFF93000A) : const Color(0xFFFFDAD6),
    onErrorContainer: dark ? const Color(0xFFFFDAD6) : const Color(0xFF410002),
    surface: dark ? const Color(0xFF1B1D21) : Colors.white,
    onSurface: dark ? const Color(0xFFE3E2E6) : const Color(0xFF1A1C1E),
    surfaceContainerHighest: dark
        ? const Color(0xFF303238)
        : const Color(0xFFE1E3E7),
    onSurfaceVariant: dark ? const Color(0xFFC4C6D0) : const Color(0xFF44474E),
    outline: dark ? const Color(0xFF8E9099) : const Color(0xFF74777F),
    outlineVariant: dark ? const Color(0xFF44474E) : const Color(0xFFC4C6D0),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: dark ? const Color(0xFFE3E2E6) : const Color(0xFF2F3033),
    onInverseSurface: dark ? const Color(0xFF2F3033) : const Color(0xFFF0F0F4),
    inversePrimary: dark ? const Color(0xFF2457B8) : const Color(0xFFB1C8FF),
  );

  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF141518)
        : const Color(0xFFF7F8FA),
    visualDensity: VisualDensity.standard,
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: scheme.onSurface),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      minWidth: 80,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
  );
}
