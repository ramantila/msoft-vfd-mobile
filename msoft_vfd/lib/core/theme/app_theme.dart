import 'package:flutter/material.dart';

enum AppThemeMode { defaultMode, neumorphic }

class AppColors {
  static const primary = Color(0xFF0BA06A);
  static const primaryDark = Color(0xFF067A53);
  static const primaryLight = Color(0xFF3FC793);

  // Default theme
  static const bgDefault = Color(0xFFF4F6F5);
  static const surfaceDefault = Color(0xFFFFFFFF);
  static const borderDefault = Color(0xFFE4EAE7);

  // Neumorphic theme
  static const bgNeu = Color(0xFFE6EBE8);
  static const shadowDarkNeu = Color(0xFFC5CEC9);
  static const shadowLightNeu = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF0E1A16);
  static const textSecondary = Color(0xFF8A988F);
  static const textMuted = Color(0xFF6B7B74);
  static const textPrimaryNeu = Color(0xFF313D38);
  static const textSecondaryNeu = Color(0xFF7C8A84);

  static const warning = Color(0xFFFFF8EC);
  static const warningBorder = Color(0xFFFBE6C0);
  static const warningText = Color(0xFFB26A00);
  static const warningIcon = Color(0xFFB26A00);

  static const error = Color(0xFFC2353A);
  static const blue = Color(0xFF2E7FF1);
  static const purple = Color(0xFF7C4DFF);
}

class AppTheme {
  static BoxDecoration neuCard({double radius = 20}) => BoxDecoration(
        color: AppColors.bgNeu,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 13, offset: Offset(6, 6)),
          BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 13, offset: Offset(-6, -6)),
        ],
      );

  static BoxDecoration neuInset({double radius = 16}) => BoxDecoration(
        color: AppColors.bgNeu,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 10, offset: Offset(5, 5)),
          BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 10, offset: Offset(-5, -5)),
        ],
      );

  static BoxDecoration neuInsetDeep({double radius = 16}) => BoxDecoration(
        color: AppColors.bgNeu,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowDarkNeu,
              blurRadius: 10,
              offset: Offset(5, 5),
              spreadRadius: 0),
          BoxShadow(
              color: AppColors.shadowLightNeu,
              blurRadius: 10,
              offset: Offset(-5, -5),
              spreadRadius: 0),
        ],
      );

  static BoxDecoration defaultCard({double radius = 18}) => BoxDecoration(
        color: AppColors.surfaceDefault,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.borderDefault),
      );
}