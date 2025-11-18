import 'package:LunarStudio/src/core/theme/ThemeControllder.dart';
import 'package:flutter/material.dart';
import 'src/app.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: const MyApp(),
    ),
  );
}
