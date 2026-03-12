import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hflow/features/auth/signup_screen.dart';
import 'package:hflow/features/home/home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Container(
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
            ),

            Positioned(
              top: -120,
              left: -100,
              child: _liquidBlob(
                width: 300,
                height: 420,
                color: const Color(0xFF9333EA),
                opacity: 0.32,
              ),
            ),

            Positioned(
              bottom: -140,
              right: -120,
              child: _liquidBlob(
                width: 360,
                height: 460,
                color: const Color(0xFF3B82F6),
                opacity: 0.30,
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                                sigmaX: 22, sigmaY: 22),
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                color: Colors.white.withOpacity(0.12),
                                border: Border.all(
                                  color:
                                  Colors.white.withOpacity(0.22),
                                  width: 0.6,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),

                                  const Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    "Glad you're back!",
                                    style: TextStyle(
                                      color: Colors.white
                                          .withOpacity(0.65),
                                    ),
                                  ),

                                  const SizedBox(height: 28),

                                  _glassInput(
                                    hint: "Enter your email",
                                    icon: Icons.email_outlined,
                                  ),

                                  const SizedBox(height: 16),

                                  _glassInput(
                                    hint: "Enter your password",
                                    icon: Icons.lock_outline,
                                    obscure: true,
                                  ),

                                  const SizedBox(height: 10),

                                  Align(
                                    alignment:
                                    Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {},
                                      child: const Text(
                                        "Forgot password?",
                                        style: TextStyle(
                                          color: Color(0xFF7AA2FF),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      style:
                                      ElevatedButton.styleFrom(
                                        backgroundColor:
                                        const Color(0xFF5B8CFF),
                                        shape:
                                        RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(
                                              14),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                            const HomeScreen(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        "Login",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight:
                                          FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: Colors.white
                                              .withOpacity(0.25),
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Text(
                                          "or",
                                          style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: Colors.white
                                              .withOpacity(0.25),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  _socialButton(
                                    icon: Icons.g_mobiledata,
                                    text:
                                    "Continue with Google",
                                  ),

                                  const SizedBox(height: 12),

                                  _socialButton(
                                    icon: Icons.apple,
                                    text:
                                    "Continue with Apple",
                                  ),

                                  const SizedBox(height: 24),

                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account? ",
                                        style: TextStyle(
                                          color: Colors.white
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                              const SignupScreen(),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "Sign Up",
                                          style: TextStyle(
                                            color:
                                            Color(0xFF7AA2FF),
                                            fontWeight:
                                            FontWeight.w600,
                                          ),
                                        ),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassInput({
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      obscureText: obscure,
      style: const TextStyle(color: Color(0xFFE5E7EB)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon:
        Icon(icon, color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF7AA2FF),
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required IconData icon,
    required String text,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: Colors.white.withOpacity(0.85)),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liquidBlob({
    required double width,
    required double height,
    required Color color,
    required double opacity,
  }) {
    return ImageFiltered(
      imageFilter:
      ImageFilter.blur(sigmaX: 140, sigmaY: 140),
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