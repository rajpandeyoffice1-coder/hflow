import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hflow/features/auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<Map<String, String>> pages = [
    {
      "title": "Smart Budgeting",
      "subtitle":
          "Effortlessly manage your spending and stay on track with personalized budget insights.",
      "image":
          "https://images.unsplash.com/photo-1554224155-6726b3ff858f",
    },
    {
      "title": "Track Expenses",
      "subtitle":
          "Understand exactly where your money goes every single day.",
      "image":
          "https://images.unsplash.com/photo-1556761175-4b46a572b786",
    },
    {
      "title": "Achieve Goals",
      "subtitle":
          "Plan smarter and achieve your financial goals with confidence.",
      "image":
          "https://images.unsplash.com/photo-1526304640581-d334cdbbf45e",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDesktop =
        kIsWeb && MediaQuery.of(context).size.width > 600;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
                width: 320,
                height: 420,
                color: const Color(0xFF9333EA),
                opacity: 0.30,
              ),
            ),
            Positioned(
              bottom: -140,
              right: -120,
              child: _liquidBlob(
                width: 360,
                height: 460,
                color: const Color(0xFF3B82F6),
                opacity: 0.28,
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 480 : double.infinity,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: pages.length,
                          onPageChanged: (i) => setState(() => _index = i),
                          itemBuilder: (context, i) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: kIsWeb
                                      ? _glassCard(i)
                                      : BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 22,
                                            sigmaY: 22,
                                          ),
                                          child: _glassCard(i),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          pages.length,
                          (i) => AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            width: _index == i ? 18 : 6,
                            decoration: BoxDecoration(
                              color: _index == i
                                  ? const Color(0xFF7AA2FF)
                                  : Colors.white.withOpacity(0.35),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 480 : double.infinity,
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                    child: kIsWeb
                        ? _bottomBar()
                        : BackdropFilter(
                            filter: ImageFilter.blur(
                                sigmaX: 20, sigmaY: 20),
                            child: _bottomBar(),
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

  Widget _glassCard(int i) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
          width: 0.6,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.network(
              pages[i]["image"]!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 26),
          Text(
            pages[i]["title"]!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE5E7EB),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            pages[i]["subtitle"]!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.22),
            width: 0.6,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _goToLogin,
            child: Text(
              "Skip",
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                if (_index < pages.length - 1) {
                  _controller.nextPage(
                    duration:
                        const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                } else {
                  _goToLogin();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF5B8CFF),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28),
              ),
              child: Text(
                _index == pages.length - 1
                    ? "Get Started"
                    : "Continue",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => const LoginScreen()),
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