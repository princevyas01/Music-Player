import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Light Theme Colors
  static const Color background = Color(0xFFF5F3F8);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF1A1A1A);
  static const Color secondaryText = Color(0xFF8B8B93);
  static const Color accent = Color(0xFFE7B8B0); // Muted rose / peach
  static const Color dividerInactive = Color(0xFFC9C7D1);
  
  static const Color buttonBlack = Color(0xFF1A1A1A);
  static const Color activePillBg = Color(0xFFF0ECE3);
  
  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0D0D12);
  static const Color darkCardSurface = Color(0xFF181822);
  static const Color darkPrimaryText = Color(0xFFF5F5FC);
  static const Color darkSecondaryText = Color(0xFF9595A8);
  static const Color darkAccent = Color(0xFF6C5CE7); // Vibrant violet accent
  static const Color darkDividerInactive = Color(0xFF2C2C3C);
  static const Color darkActivePillBg = Color(0xFF222230);
  
  // Dynamic color getters based on context
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color bg(BuildContext context) => isDark(context) ? darkBackground : background;
  static Color surface(BuildContext context) => isDark(context) ? darkCardSurface : cardSurface;
  static Color textPrimary(BuildContext context) => isDark(context) ? darkPrimaryText : primaryText;
  static Color textSecondary(BuildContext context) => isDark(context) ? darkSecondaryText : secondaryText;
  static Color pillBg(BuildContext context) => isDark(context) ? darkActivePillBg : activePillBg;
  static Color divider(BuildContext context) => isDark(context) ? darkDividerInactive : dividerInactive;

  // Unified Shadow method supporting both softShadow() and softShadow(context)
  static List<BoxShadow> softShadow([BuildContext? context]) {
    final dark = context != null ? isDark(context) : false;
    return [
      BoxShadow(
        color: dark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> vinylShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 24,
      spreadRadius: 2,
      offset: const Offset(0, 10),
    ),
  ];
}
