import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<ThemeMode>(
      value: ThemeService.instance.themeMode.value,
      onChanged: (mode) {
        if (mode != null) ThemeService.instance.setTheme(mode);
      },
      items: const [
        DropdownMenuItem(value: ThemeMode.system, child: Text('Auto')),
        DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
        DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
      ],
    );
  }
}
