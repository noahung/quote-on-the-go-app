import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'semantic_colors.dart';

class AppTheme {
  AppTheme._();
  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final ink = dark ? DesignTokens.canvas : DesignTokens.ink;
    final panel = dark ? DesignTokens.darkPanel : DesignTokens.cream;
    final colors = ColorScheme.fromSeed(
            seedColor: DesignTokens.orange, brightness: brightness)
        .copyWith(
      primary: DesignTokens.orange,
      onPrimary: DesignTokens.ink,
      primaryContainer:
          dark ? const Color(0xFF553B26) : const Color(0xFFFFDEC4),
      onPrimaryContainer: ink,
      surface: dark ? DesignTokens.darkCanvas : DesignTokens.canvas,
      onSurface: ink,
      surfaceContainerLow: panel,
      surfaceContainer: panel,
      surfaceContainerHigh: panel,
      surfaceContainerHighest: panel,
      onSurfaceVariant: dark ? DesignTokens.darkMuted : DesignTokens.muted,
      outline: dark ? const Color(0xFF999B8C) : DesignTokens.outline,
      outlineVariant: dark ? const Color(0xFF45473B) : DesignTokens.divider,
    );
    final base =
        ThemeData(brightness: brightness, fontFamily: 'DMSans').textTheme;
    TextStyle style(double size, FontWeight weight,
            {double height = 1.3, double spacing = 0}) =>
        TextStyle(
            fontFamily: 'DMSans',
            fontSize: size,
            fontWeight: weight,
            height: height,
            letterSpacing: spacing,
            color: ink);
    final text = base.apply(bodyColor: ink, displayColor: ink).copyWith(
          headlineLarge:
              style(36, FontWeight.w800, height: 1.12, spacing: -1.2),
          headlineMedium:
              style(28, FontWeight.w700, height: 1.2, spacing: -0.6),
          titleLarge: style(22, FontWeight.w700, height: 1.25, spacing: -0.4),
          titleMedium: style(18, FontWeight.w700),
          bodyLarge: style(16, FontWeight.w400, height: 1.45),
          bodyMedium: style(14, FontWeight.w400, height: 1.4),
          labelLarge: style(16, FontWeight.w700),
        );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: color, width: width));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'DMSans',
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
          backgroundColor: colors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: text.titleLarge),
      cardTheme: CardThemeData(
          color: panel,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 56),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: text.labelLarge)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              minimumSize: const Size(48, 56),
              side: BorderSide(color: colors.outline),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: text.labelLarge)),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: ink,
              minimumSize: const Size(48, 48),
              textStyle: text.labelLarge)),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
              foregroundColor: ink, minimumSize: const Size(48, 48))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          border: inputBorder(colors.outline),
          enabledBorder: inputBorder(colors.outline),
          focusedBorder: inputBorder(ink, 2),
          errorBorder: inputBorder(colors.error),
          focusedErrorBorder: inputBorder(colors.error, 2),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18)),
      chipTheme: ChipThemeData(
          backgroundColor: panel,
          selectedColor: colors.primaryContainer,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          labelStyle: text.bodyMedium),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 76,
          indicatorColor: colors.primaryContainer,
          labelTextStyle: WidgetStatePropertyAll(style(12, FontWeight.w600))),
      tabBarTheme: TabBarThemeData(
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: DesignTokens.ink,
          unselectedLabelColor: colors.onSurfaceVariant,
          indicator: BoxDecoration(
              color: colors.primary, borderRadius: BorderRadius.circular(999))),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true),
      popupMenuTheme: PopupMenuThemeData(
          color: colors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: dark ? DesignTokens.cream : DesignTokens.ink,
          contentTextStyle: text.bodyMedium
              ?.copyWith(color: dark ? DesignTokens.ink : DesignTokens.canvas),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      dividerTheme:
          DividerThemeData(color: colors.outlineVariant, thickness: 1),
      extensions: [dark ? SemanticColors.dark : SemanticColors.light],
    );
  }
}
