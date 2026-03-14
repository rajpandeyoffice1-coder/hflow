// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hflow/features/splash/splash_screen.dart';
import 'package:hflow/features/auth/login_screen.dart';
import 'package:hflow/features/auth/signup_screen.dart';
import 'package:hflow/features/home/home_screen.dart';
import 'package:hflow/providers/auth_provider.dart';
import 'package:hflow/services/theme_service.dart';
import 'app_theme.dart';

class HFlowApp extends StatelessWidget {
  const HFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeMode,
      builder: (_, mode, __) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            // Add other providers here if needed
            // ChangeNotifierProvider(create: (_) => InvestmentProvider()),
          ],
          child: MaterialApp(
            title: 'HFlow',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/home': (context) => const HomeScreen(),
            },
            // Optional: Handle unknown routes
            onGenerateRoute: (settings) {
              // You can add custom route generation here if needed
              return null;
            },
            // Optional: Error handling for routes
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const SplashScreen(),
              );
            },
          ),
        );
      },
    );
  }
}