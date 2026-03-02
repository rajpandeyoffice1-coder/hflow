import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hflow/features/auth/forgot_password_screen.dart';
import 'package:hflow/features/auth/signup_screen.dart';
import 'package:hflow/features/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        body: Stack(
          children: [
            _background(),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: Colors.white.withOpacity(0.12),
                        border: Border.all(color: Colors.white.withOpacity(0.22), width: 0.6),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Login', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFFE5E7EB))),
                            const SizedBox(height: 24),
                            _glassInput(_emailController, hint: 'Enter your email', icon: Icons.email_outlined, isEmail: true),
                            const SizedBox(height: 16),
                            _glassInput(_passwordController, hint: 'Enter your password', icon: Icons.lock_outline, obscure: true),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                                child: const Text('Forgot password?', style: TextStyle(color: Color(0xFF7AA2FF))),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B8CFF)),
                                onPressed: () {
                                  if (!_formKey.currentState!.validate()) return;
                                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                                },
                                child: const Text('Login', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Don't have an account? ", style: TextStyle(color: Colors.white.withOpacity(0.6))),
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                                  child: const Text('Sign Up', style: TextStyle(color: Color(0xFF7AA2FF), fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassInput(
    TextEditingController controller, {
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool isEmail = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Color(0xFFE5E7EB)),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return '$hint is required';
        if (isEmail && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter a valid email';
        return null;
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _background() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B0F1A), Color(0xFF05060A)]),
        ),
        child: Stack(children: [
          Positioned(top: -120, left: -100, child: _liquidBlob(width: 300, height: 420, color: const Color(0xFF9333EA), opacity: 0.32)),
          Positioned(bottom: -140, right: -120, child: _liquidBlob(width: 360, height: 460, color: const Color(0xFF3B82F6), opacity: 0.30)),
        ]),
      );

  Widget _liquidBlob({required double width, required double height, required Color color, required double opacity}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 140, sigmaY: 140),
      child: Container(width: width, height: height, decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: color.withOpacity(opacity))),
    );
  }
}
