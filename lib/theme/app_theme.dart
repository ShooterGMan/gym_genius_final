import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF09090B);
  static const Color surface = Color(0xFF18181B);
  static const Color accent = Color(0xFFCCFF00);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF71717A);
  static const Color border = Color(0x1AFFFFFF);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.accent,
      useMaterial3: true,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
        labelSmall: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  // Common styles
  static EdgeInsets get screenPadding => const EdgeInsets.all(24);
  static EdgeInsets get cardPadding => const EdgeInsets.all(20);
  static double get cardRadius => 20.0;
  static double get buttonHeight => 56.0;

  // Responsive helpers
  static EdgeInsets responsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return const EdgeInsets.all(16);
    if (width < 400) return const EdgeInsets.all(20);
    return const EdgeInsets.all(24);
  }

  static double responsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return baseSize * 0.85;
    if (width < 400) return baseSize * 0.92;
    return baseSize;
  }

  static TextStyle get headerStyle => const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
      );

  static TextStyle responsiveHeaderStyle(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final fontSize = width < 360 ? 22.0 : (width < 400 ? 25.0 : 28.0);
    return TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
    );
  }

  static TextStyle get sectionHeaderStyle => const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      );
}
