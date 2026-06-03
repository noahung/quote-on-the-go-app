import 'package:flutter/material.dart';

/// A custom [ThemeExtension] that holds soft, luminous semantic colors
/// tailored for an AI-native, premium glassmorphic aesthetic.
class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Luminous accents for KPIs, charts, and key interface cards
  final Color accentPrimary;     // Luminous brand orange
  final Color accentOrange;      // Soft glow orange
  final Color accentBlue;        // Luminous sky blue
  final Color accentPurple;      // Luminous royal purple
  final Color accentGreen;       // Luminous mint green
  final Color accentDeepOrange;  // Luminous coral/rose
  final Color accentTeal;        // Luminous electric teal
  final Color accentIndigo;      // Luminous royal indigo

  const SemanticColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.accentPrimary,
    required this.accentOrange,
    required this.accentBlue,
    required this.accentPurple,
    required this.accentGreen,
    required this.accentDeepOrange,
    required this.accentTeal,
    required this.accentIndigo,
  });

  @override
  ThemeExtension<SemanticColors> copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? accentPrimary,
    Color? accentOrange,
    Color? accentBlue,
    Color? accentPurple,
    Color? accentGreen,
    Color? accentDeepOrange,
    Color? accentTeal,
    Color? accentIndigo,
  }) {
    return SemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentOrange: accentOrange ?? this.accentOrange,
      accentBlue: accentBlue ?? this.accentBlue,
      accentPurple: accentPurple ?? this.accentPurple,
      accentGreen: accentGreen ?? this.accentGreen,
      accentDeepOrange: accentDeepOrange ?? this.accentDeepOrange,
      accentTeal: accentTeal ?? this.accentTeal,
      accentIndigo: accentIndigo ?? this.accentIndigo,
    );
  }

  @override
  ThemeExtension<SemanticColors> lerp(
    covariant ThemeExtension<SemanticColors>? other,
    double t,
  ) {
    if (other is! SemanticColors) {
      return this;
    }
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      accentDeepOrange: Color.lerp(accentDeepOrange, other.accentDeepOrange, t)!,
      accentTeal: Color.lerp(accentTeal, other.accentTeal, t)!,
      accentIndigo: Color.lerp(accentIndigo, other.accentIndigo, t)!,
    );
  }

  /// Light mode luminous color palette
  static const light = SemanticColors(
    success: Color(0xFF10B981),          // Emerald
    warning: Color(0xFFF59E0B),          // Amber
    error: Color(0xFFEF4444),            // Coral Red
    info: Color(0xFF3B82F6),             // Blue
    accentPrimary: Color(0xFFF4781F),    // Brand Orange
    accentOrange: Color(0xFFF97316),     // Orange
    accentBlue: Color(0xFF0EA5E9),       // Sky Blue
    accentPurple: Color(0xFF8B5CF6),     // Violet
    accentGreen: Color(0xFF10B981),      // Success Emerald
    accentDeepOrange: Color(0xFFE11D48), // Rose/Ruby
    accentTeal: Color(0xFF0D9488),       // Teal
    accentIndigo: Color(0xFF6366F1),     // Indigo
  );

  /// Dark mode soft-glowing luminous palette
  static const dark = SemanticColors(
    success: Color(0xFF34D399),          // Luminous Mint
    warning: Color(0xFFFBBF24),          // Glowing Gold
    error: Color(0xFFF87171),            // Peach Coral
    info: Color(0xFF60A5FA),             // Luminous Blue
    accentPrimary: Color(0xFFFF9E59),    // Luminous Orange Accent
    accentOrange: Color(0xFFFB923C),     // Pastel Orange
    accentBlue: Color(0xFF38BDF8),       // Glowing Cyan
    accentPurple: Color(0xFFA78BFA),     // Lavender
    accentGreen: Color(0xFF34D399),      // Mint Green
    accentDeepOrange: Color(0xFFFB7185), // Soft Rose
    accentTeal: Color(0xFF2DD4BF),       // Electric Teal
    accentIndigo: Color(0xFF818CF8),     // Neon Indigo
  );
}
