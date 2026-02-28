import 'dart:ui';
import 'package:flutter/material.dart';

class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
                width: 0.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, 0),
                _navItem(Icons.receipt_long_rounded, 1),
                _centerItem(),
                _navItem(Icons.show_chart_rounded, 3),
                _navItem(Icons.settings_rounded, 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {
    final bool active = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? const Color(0xFF7AA2FF).withOpacity(0.95)
              : Colors.transparent,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF7AA2FF).withOpacity(0.55),
                    blurRadius: 18,
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          size: 22,
          color: active
              ? Colors.white
              : Colors.white.withOpacity(0.65),
        ),
      ),
    );
  }

  Widget _centerItem() {
    return GestureDetector(
      onTap: () => onTap(2),
      child: Container(
        width: 56,
        height: 56,
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
              color: const Color(0xFF5B8CFF).withOpacity(0.6),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(
          Icons.bolt_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
