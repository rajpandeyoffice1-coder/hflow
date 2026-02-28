import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class VerifyOtpScreen extends StatelessWidget {
  const VerifyOtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            /// DARK BASE BACKGROUND
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

            /// TOP-LEFT PURPLE LIQUID
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

            /// BOTTOM-RIGHT BLUE LIQUID
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

            /// OTP GLASS CARD
            Center(
              child: Padding(
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
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                          width: 0.6,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// ICON
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF5B8CFF)
                                  .withOpacity(0.18),
                            ),
                            child: const Icon(
                              Icons.mail_outline,
                              color: Color(0xFF7AA2FF),
                            ),
                          ),

                          const SizedBox(height: 16),

                          /// TITLE
                          const Text(
                            "Verify Email",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE5E7EB),
                            ),
                          ),

                          const SizedBox(height: 8),

                          /// SUBTITLE
                          Text(
                            "Enter the 6-digit code sent to\nyour email address",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                            ),
                          ),

                          const SizedBox(height: 28),

                          /// OTP FIELD
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final double boxWidth =
                                  (constraints.maxWidth - 40) / 6;

                              return PinCodeTextField(
                                appContext: context,
                                length: 6,
                                keyboardType: TextInputType.number,
                                animationType: AnimationType.fade,
                                cursorColor: const Color(0xFF7AA2FF),
                                enableActiveFill: true,
                                textStyle: const TextStyle(
                                  color: Color(0xFFE5E7EB),
                                  fontWeight: FontWeight.w600,
                                ),
                                pinTheme: PinTheme(
                                  shape: PinCodeFieldShape.box,
                                  borderRadius: BorderRadius.circular(14),
                                  fieldHeight: 48,
                                  fieldWidth:
                                      boxWidth.clamp(36, 44),
                                  activeFillColor:
                                      Colors.white.withOpacity(0.14),
                                  inactiveFillColor:
                                      Colors.white.withOpacity(0.08),
                                  selectedFillColor:
                                      Colors.white.withOpacity(0.18),
                                  activeColor:
                                      Colors.white.withOpacity(0.30),
                                  inactiveColor:
                                      Colors.white.withOpacity(0.20),
                                  selectedColor:
                                      const Color(0xFF7AA2FF),
                                  borderWidth: 0.8,
                                ),
                                onChanged: (_) {},
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          /// TIMER
                          const Text(
                            "Code expires in 59s",
                            style: TextStyle(
                              color: Color(0xFF7AA2FF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 12),

                          /// RESEND
                          TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.refresh,
                              color: Color(0xFF7AA2FF),
                            ),
                            label: const Text(
                              "Resend Code",
                              style: TextStyle(
                                color: Color(0xFF7AA2FF),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          /// VERIFY BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF5B8CFF),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {},
                              child: const Text(
                                "Verify Account",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
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

  /// LIQUID BLOB (same system everywhere)
  Widget _liquidBlob({
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
