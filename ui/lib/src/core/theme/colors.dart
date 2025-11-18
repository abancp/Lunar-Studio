import 'package:flutter/material.dart';

class AppTheme {
  static final light = ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      background: Color(0xFFF5F5F5),
      surface: Color(0xFFFFFFFF),
      primary: Color(0xFF5A54F0),
      secondary: Color(0xFFE0E0E0),
      outline: Color(0xFF8D86FF),
      onBackground: Colors.black87,
      onSurface: Colors.black87,
      onPrimary: Colors.white,
    ),
    useMaterial3: true,
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      background: Color(0xFF0F1116),
      surface: Color(0xFF1A1C22),
      primary: Color(0xFF635BFF),
      secondary: Color(0xFF2C2F36),
      outline: Color(0xFF3D347F),
      onBackground: Colors.white,
      onSurface: Colors.white70,
      onPrimary: Colors.white,
    ),
    useMaterial3: true,
  );
}
