import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hflow/features/auth/otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isChecked = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                            const Text('Create Account', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFFE5E7EB))),
                            const SizedBox(height: 20),
                            _input(_nameController, 'Name', Icons.person_outline),
                            const SizedBox(height: 12),
                            _input(_emailController, 'Email', Icons.email_outlined, isEmail: true),
                            const SizedBox(height: 12),
                            _input(_mobileController, 'Mobile', Icons.phone_android_outlined, isMobile: true),
                            const SizedBox(height: 12),
                            _input(_passwordController, 'Password', Icons.lock_outline, obscure: true),
                            const SizedBox(height: 12),
                            _input(_confirmPasswordController, 'Confirm Password', Icons.lock_reset_outlined, obscure: true, match: _passwordController),
                            const SizedBox(height: 10),
                            CheckboxListTile(
                              value: _isChecked,
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFF7AA2FF),
                              checkColor: Colors.white,
                              title: Text('I agree to Terms & Privacy Policy', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                              onChanged: (value) => setState(() => _isChecked = value ?? false),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B8CFF)),
                                onPressed: () {
                                  if (!_formKey.currentState!.validate()) return;
                                  if (!_isChecked) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please accept Terms & Privacy Policy')));
                                    return;
                                  }
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyOtpScreen()));
                                },
                                child: const Text('Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
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

  Widget _input(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    bool isEmail = false,
    bool isMobile = false,
    TextEditingController? match,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: isMobile ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return '$hint is required';
        if (isEmail && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter valid email';
        if (isMobile && !RegExp(r'^\d{10}$').hasMatch(v)) return 'Enter valid 10-digit mobile';
        if (match != null && v != match.text.trim()) return 'Password does not match';
        if (hint == 'Password' && v.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white70),
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
        child: Stack(
          children: [
            Positioned(top: -120, left: -100, child: _liquidBlob(width: 300, height: 420, color: const Color(0xFF9333EA), opacity: 0.32)),
            Positioned(bottom: -140, right: -120, child: _liquidBlob(width: 360, height: 460, color: const Color(0xFF3B82F6), opacity: 0.30)),
          ],
        ),
      );

  Widget _liquidBlob({required double width, required double height, required Color color, required double opacity}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 140, sigmaY: 140),
      child: Container(width: width, height: height, decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: color.withOpacity(opacity))),
    );
  }
}
