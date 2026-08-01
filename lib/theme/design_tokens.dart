import 'package:flutter/material.dart';

/// Centralized design tokens for consistent styling across the app.
/// Use these values instead of hardcoded numbers for spacing, radius, etc.
class DesignTokens {
  // ============== SPACING ==============
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;
  static const double space7 = 48;
  static const double space8 = 64;

  // ============== BORDER RADIUS ==============
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusFull = 9999;

  // ============== ANIMATION ==============
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  static const Duration durationVerySlow = Duration(milliseconds: 600);

  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveSharp = Curves.easeInOutCubic;

  // ============== RESPONSIVE BREAKPOINTS ==============
  static const double breakpointMobile = 600;
  static const double breakpointTablet = 900;
  static const double breakpointDesktop = 1200;

  // ============== MAX WIDTHS ==============
  static const double maxContentWidth = 1200;
  static const double maxCardWidth = 600;

  // ============== SHADOWS (Dark Theme) ==============
  static List<BoxShadow> get shadowNone => [];

  static List<BoxShadow> shadowSm(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.15),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> shadowMd(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> shadowLg(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> glowEffect(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.15),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];

  // ============== TAG/CATEGORY COLORS ==============
  static const Map<String, Color> tagColors = {
    'flutter': Color(0xFF02569B),
    'dart': Color(0xFF0175C2),
    'javascript': Color(0xFFF7DF1E),
    'python': Color(0xFF3776AB),
    'comptia': Color(0xFFC8102E),
    'a+': Color(0xFFC8102E),
    'hardware': Color(0xFF6B7280),
    'mobile-devices': Color(0xFF10B981),
    'laptops': Color(0xFF8B5CF6),
    'displays': Color(0xFFEC4899),
  };

  static Color getTagColor(String tag) {
    return tagColors[tag.toLowerCase()] ?? const Color(0xFF4FC3F7);
  }

  /// Pick a readable text/icon color for a given background.
  static Color readableOn(Color background) {
    return background.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;
  }

  // ============== HELPER METHODS ==============
  
  /// Get responsive horizontal padding based on screen width
  static double getHorizontalPadding(double screenWidth) {
    if (screenWidth > breakpointDesktop) return space7;
    if (screenWidth > breakpointTablet) return space6;
    if (screenWidth > breakpointMobile) return space5;
    return space4;
  }

  /// Get number of grid columns based on screen width
  static int getGridColumns(double screenWidth) {
    if (screenWidth > 1100) return 3;
    if (screenWidth > 750) return 2;
    return 1;
  }
}
