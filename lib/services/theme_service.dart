import 'package:flutter/material.dart';

class ThemeService {
  ThemeService._();
  static final instance = ThemeService._();

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);

  void setTheme(ThemeMode mode) {
    themeMode.value = mode;
  }
}
