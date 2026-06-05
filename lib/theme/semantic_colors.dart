import 'package:flutter/material.dart';

/// A custom [ThemeExtension] that holds soft, luminous semantic colors
/// tailored for an AI-native, premium glassmorphic aesthetic.
class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Luminous accents for KPIs, charts, and key interface cards
  final Color accentPrimary; // Luminous brand orange
  final Color accentOrange; // Soft glow orange
  final Color accentBlue; // Luminous sky blue
  final Color accentPurple; // Luminous royal purple
  final Color accentGreen; // Luminous mint green
  final Color accentDeepOrange; // Luminous coral/rose
  final Color accentTeal; // Luminous electric teal
  final Color accentIndigo; // Luminous royal indigo

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
      accentDeepOrange:
          Color.lerp(accentDeepOrange, other.accentDeepOrange, t)!,
      accentTeal: Color.lerp(accentTeal, other.accentTeal, t)!,
      accentIndigo: Color.lerp(accentIndigo, other.accentIndigo, t)!,
    );
  }

  /// Light mode desaturated, clean color palette
  static const light = SemanticColors(
    success: Color(0xFF00966C), // Vibrant Emerald Green
    warning: Color(0xFFE28200), // Vibrant Amber
    error: Color(0xFFBA1A1A), // Vibrant Crimson
    info: Color(0xFF1A73E8), // Vibrant Info Blue
    accentPrimary: Color(0xFFF4781F), // Brand Orange
    accentOrange: Color(0xFFFF6B00), // Bright Orange
    accentBlue: Color(0xFF1A73E8), // Sky Blue
    accentPurple: Color(0xFF6200EE), // Royal Purple
    accentGreen: Color(0xFF00966C), // Mint Green / Success
    accentDeepOrange: Color(0xFFFF5722), // Coral / Rose
    accentTeal: Color(0xFF009688), // Teal
    accentIndigo: Color(0xFF3F51B5), // Royal Indigo
  );

  /// Dark mode soft-glowing desaturated palette
  static const dark = SemanticColors(
    success: Color(0xFF00BFA5), // Glowing Mint Green
    warning: Color(0xFFFFB300), // Glowing Amber
    error: Color(0xFFFF5252), // Glowing Coral Red
    info: Color(0xFF40C4FF), // Glowing Info Blue
    accentPrimary: Color(0xFFFF8F00), // Glowing Brand Orange
    accentOrange: Color(0xFFFF6B00), // Bright Orange
    accentBlue: Color(0xFF40C4FF), // Cyan Accent
    accentPurple: Color(0xFFB388FF), // Lavender Accent
    accentGreen: Color(0xFF00BFA5), // Mint Green
    accentDeepOrange: Color(0xFFFF8A80), // Rose Accent
    accentTeal: Color(0xFF1DE9B6), // Teal Accent
    accentIndigo: Color(0xFF8C9EFF), // Indigo Accent
  );
}
