import 'package:flutter/material.dart';
import 'package:hflow/features/Portfolio/investment_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://ursptusooxjlldjzopwn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVyc3B0dXNvb3hqbGxkanpvcHduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MzU0NTYsImV4cCI6MjA4NzQxMTQ1Nn0.jKjTaz7cLN7X_edCUTVpL_hosTjSwoPM5qNDsy45SeA',
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => InvestmentProvider(),
      child: const HFlowApp(),
    ),
  );
}