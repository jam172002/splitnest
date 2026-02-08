import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Jaminnova palette (ONLY)
  static const Color green = Color(0xFF20C84A); // put your exact logo green here
  static const Color black = Color(0xFF0B0D0F);
  static const Color white = Color(0xFFFFFFFF);

  /// Helpers that still follow "only black/white + green"
  static Color bg(bool isDark) => isDark ? black : white;

  static Color card(bool isDark) =>
      isDark ? const Color(0xFF101214) : const Color(0xFFF7F8F9); // still neutral black/white family

  static Color stroke(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);

  static Color text(bool isDark) => isDark ? white : Colors.black;

  static Color subText(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.70) : Colors.black.withValues(alpha: 0.60);

  static Color inviteBg(bool isDark) =>
      isDark ? const Color(0xFF0F1511) : const Color(0xFFECF5EF);
}