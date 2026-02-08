import 'package:flutter/material.dart';

class AppTheme {
  // ✅ Brand accent (logo-like green)
  static const Color brandGreen = Color(0xFF20C84A);

  static ThemeData light(BuildContext context) {
    final shared = _SharedStyles(context);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandGreen,
        brightness: Brightness.light,
        primary: brandGreen,
        surface: Colors.grey.shade50,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Colors.grey.shade50,
        surfaceContainer: Colors.grey.shade100,
        surfaceContainerHigh: Colors.grey.shade200,
      ),
      scaffoldBackgroundColor: Colors.white,

      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),

      filledButtonTheme: FilledButtonThemeData(style: shared.filled),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: shared.outlined.copyWith(
          side: WidgetStateProperty.all(
            BorderSide(color: brandGreen.withValues(alpha: 0.55)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: shared.text),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: brandGreen.withValues(alpha: 0.95), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, height: 1.25),
        headlineMedium: TextStyle(fontSize: 28, height: 1.28),
        headlineSmall: TextStyle(fontSize: 24, height: 1.33),
        titleLarge: TextStyle(fontSize: 22, height: 1.27, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, height: 1.43),
        labelLarge: TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w500),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
    );
  }

  static ThemeData dark(BuildContext context) {
    final shared = _SharedStyles(context);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandGreen,
        brightness: Brightness.dark,
        primary: brandGreen,
        surface: const Color(0xFF0B0D0F),
        surfaceContainerLowest: const Color(0xFF07090B),
        surfaceContainerLow: const Color(0xFF101418),
        surfaceContainer: const Color(0xFF141A20),
        surfaceContainerHigh: const Color(0xFF1A2129),
      ),
      scaffoldBackgroundColor: const Color(0xFF0B0D0F),

      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),

      filledButtonTheme: FilledButtonThemeData(style: shared.filled),
      outlinedButtonTheme: OutlinedButtonThemeData(style: shared.outlined),
      textButtonTheme: TextButtonThemeData(style: shared.text),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF101418),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: brandGreen.withValues(alpha: 0.95), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
    );
  }
}

class _SharedStyles {
  final ButtonStyle filled;
  final ButtonStyle outlined;
  final ButtonStyle text;

  _SharedStyles(BuildContext context)
      : filled = FilledButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    minimumSize: const Size(0, 52),
    elevation: 0,
  ),
        outlined = OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 52),
        ),
        text = TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
}