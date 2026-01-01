import 'package:flutter/material.dart';

class AppTheme {
  static final light = ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      background: Color(0xFFFFFFFF),
      surface: Color(0xFFF7F7F8),
      primary: Color(0xFF5A54F0),
      secondary: Color(0xFFE0E0E0),
      outline: Color(0xFFE0E0E0),
      onBackground: Color(0xFF1A1A1A),
      onSurface: Color(0xFF1A1A1A),
      onPrimary: Colors.white,
      surfaceVariant: Color(0xFFF0F0F2),
    ),
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
    useMaterial3: true,
    dividerTheme: const DividerThemeData(color: Color(0xFFE0E0E0)),
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      background: Color(0xFF0E0E0E),
      surface: Color(0xFF1C1C1C),
      primary: Color(0xFF6F65E8),
      secondary: Color(0xFF2B2D31),
      outline: Color(0xFF3E3E3E),
      onBackground: Color(0xFFECECEC),
      onSurface: Color(0xFFECECEC),
      onPrimary: Colors.white,
      surfaceVariant: Color(0xFF252525),
      shadow: Colors.black,
    ),
    scaffoldBackgroundColor: const Color(0xFF0E0E0E),
    useMaterial3: true,
    dividerTheme: const DividerThemeData(color: Color(0xFF3E3E3E)),
  );
}
