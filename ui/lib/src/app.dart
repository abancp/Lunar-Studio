import 'package:LunarStudio/src/core/theme/colors.dart';
import 'package:LunarStudio/src/core/theme/theme_controllder.dart';
import 'package:LunarStudio/src/features/chat/presentation/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();

    return MaterialApp(
      themeMode: theme.mode,
      theme: AppTheme.dark, // use your custom theme
      darkTheme: AppTheme.dark, // use your custom dark theme
      debugShowCheckedModeBanner: false,
      home: const ChatPage(),
    );
  }
}
