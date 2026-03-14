import 'package:flutter/material.dart';
import 'package:hflow/features/Portfolio/investment_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'providers/auth_provider.dart';
import 'package:hflow/features/SettingScreen/setting_screen.dart'; // Adjust import path

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to load saved connection details
  final connectionDetails = await DatabaseConnectionService.loadConnectionDetails();

  if (connectionDetails['url'] != null && connectionDetails['anonKey'] != null) {
    await Supabase.initialize(
      url: connectionDetails['url']!,
      anonKey: connectionDetails['anonKey']!,
    );
  } else {
    // Fallback to default (for first run)
    await Supabase.initialize(
      url: 'https://ursptusooxjlldjzopwn.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVyc3B0dXNvb3hqbGxkanpvcHduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MzU0NTYsImV4cCI6MjA4NzQxMTQ1Nn0.jKjTaz7cLN7X_edCUTVpL_hosTjSwoPM5qNDsy45SeA',
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => InvestmentProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const HFlowApp(),
    ),
  );
}