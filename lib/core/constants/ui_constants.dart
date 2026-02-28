import 'package:flutter/material.dart';
import 'colors.dart';

LinearGradient bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    AppColors.primary.withOpacity(0.95),
    AppColors.secondary.withOpacity(0.85),
  ],
);

LinearGradient darkBgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    AppColors.secondary.withOpacity(0.35),
    AppColors.black,
  ],
);

Color primaryColor = AppColors.primary;
Color secondaryColor = AppColors.secondary;
Color appBackground = AppColors.background;