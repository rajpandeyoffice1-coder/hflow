import 'dart:ui';
import 'package:flutter/material.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B0F1A),
              Color(0xFF05060A),
            ],
          ),
        ),
        child: Stack(
          children: [
            // TOP-LEFT PURPLE GLOSS (like login image)
            Positioned(
              top: -80,
              left: -60,
              child: _glossyBlob(
                width: 300,
                height: 420,
                color: const Color(0xFF9333EA),
                opacity: 0.32,
              ),
            ),

            // BOTTOM-RIGHT BLUE / PURPLE GLOSS
            Positioned(
              bottom: -90,
              right: -70,
              child: _glossyBlob(
                width: 360,
                height: 460,
                color: const Color(0xFF3B82F6),
                opacity: 0.30,
              ),
            ),

            // CENTER LOGO (NO CARD)
            Center(
              child: Image.asset(
                'assets/images/logo_new.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),

            // VERSION TEXT
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Text(
                'Version 1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Glossy blob like your login image
  Widget _glossyBlob({
    required double width,
    required double height,
    required Color color,
    required double opacity,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 140, sigmaY: 140),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }
}
