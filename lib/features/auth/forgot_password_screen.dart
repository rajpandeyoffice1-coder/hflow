import 'dart:ui';

import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _contactKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 420,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: _step == 0 ? _contactStep() : _resetStep(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactStep() {
    return Form(
      key: _contactKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Forgot Password', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Enter email and mobile to receive OTP.', style: TextStyle(color: Colors.white.withOpacity(0.7))),
          const SizedBox(height: 20),
          _field(_emailController, 'Email', icon: Icons.email_outlined, isEmail: true),
          const SizedBox(height: 12),
          _field(_mobileController, 'Mobile', icon: Icons.phone_android_outlined, isPhone: true),
          const SizedBox(height: 12),
          _field(_otpController, 'OTP', icon: Icons.password_outlined, isOtp: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_contactKey.currentState!.validate()) {
                  setState(() => _step = 1);
                }
              },
              child: const Text('Verify OTP'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resetStep() {
    return Form(
      key: _resetKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Set New Password', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          _field(_newPasswordController, 'New Password', icon: Icons.lock_outline, obscure: true),
          const SizedBox(height: 12),
          _field(_confirmPasswordController, 'Confirm Password', icon: Icons.lock_reset_outlined, obscure: true, match: _newPasswordController),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 0),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_resetKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successful.')));
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    required IconData icon,
    bool obscure = false,
    bool isEmail = false,
    bool isPhone = false,
    bool isOtp = false,
    TextEditingController? match,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: isPhone || isOtp ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return '$hint is required';
        if (isEmail && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter valid email';
        if (isPhone && !RegExp(r'^\d{10}$').hasMatch(v)) return 'Enter 10-digit mobile';
        if (isOtp && !RegExp(r'^\d{4,6}$').hasMatch(v)) return 'Enter valid OTP';
        if (match != null && v != match.text.trim()) return 'Passwords do not match';
        return null;
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _background() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B0F1A), Color(0xFF05060A)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -100, left: -90, child: _blob(320, 420, const Color(0xFF9333EA), 0.3)),
          Positioned(bottom: -140, right: -120, child: _blob(360, 460, const Color(0xFF3B82F6), 0.28)),
        ],
      ),
    );
  }

  Widget _blob(double width, double height, Color color, double opacity) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 130, sigmaY: 130),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: color.withOpacity(opacity), borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}
