// lib/widgets/liquid_blob.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidBlobBackground extends StatelessWidget {
  const LiquidBlobBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -100,
          child: _liquidBlob(
            width: 320,
            height: 420,
            color: const Color(0xFF9333EA),
            opacity: 0.28,
          ),
        ),
        Positioned(
          bottom: -160,
          right: -120,
          child: _liquidBlob(
            width: 380,
            height: 460,
            color: const Color(0xFF3B82F6),
            opacity: 0.26,
          ),
        ),
      ],
    );
  }

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