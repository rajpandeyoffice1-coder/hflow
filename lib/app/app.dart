import 'package:flutter/material.dart';
import 'package:hflow/features/splash/splash_screen.dart';
import '../services/theme_service.dart';
import 'app_theme.dart';

class HFlowApp extends StatelessWidget {
  const HFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeMode,
      builder: (_, mode, _) {
        return MaterialApp(
          title: 'HFlow',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SplashScreen(),
        );
      },
    );
  }
}
