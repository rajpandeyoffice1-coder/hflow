import 'dart:ui';
import 'package:flutter/material.dart';

class UltraGlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const UltraGlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _glassBase(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, 0),
              _navItem(Icons.receipt_long_rounded, 1),
              const SizedBox(width: 60),
              _navItem(Icons.show_chart_rounded, 3),
              _navItem(Icons.settings_rounded, 4),
            ],
          ),
          _centerButton(),
        ],
      ),
    );
  }

  Widget _glassBase() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.20),
                Colors.white.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 35,
                offset: const Offset(0, 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {
    final active = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: active
              ? const LinearGradient(
            colors: [
              Color(0xFF4F8CFF),
              Color(0xFF8E5CFF),
            ],
          )
              : null,
          boxShadow: active
              ? [
            BoxShadow(
              color: const Color(0xFF7C8CFF).withOpacity(0.8),
              blurRadius: 18,
              spreadRadius: 1,
            )
          ]
              : [],
        ),
        child: Icon(
          icon,
          size: 20,
          color: active
              ? Colors.white
              : Colors.white.withOpacity(0.65),
        ),
      ),
    );
  }

  Widget _centerButton() {
    return Positioned(
      bottom: 8,
      child: GestureDetector(
        onTap: () => onTap(2),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF3B82F6),
                Color(0xFF9333EA),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B8CFF).withOpacity(0.9),
                blurRadius: 26,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.bolt_rounded,
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}