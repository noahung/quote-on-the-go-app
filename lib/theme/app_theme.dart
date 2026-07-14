import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'semantic_colors.dart';

/// Central theme builder for Quote On The Go, standardizing
/// on a premium, modern, pill-shaped and typography-driven UI.
class AppTheme {
  AppTheme._();

  static const _brandOrange = Color(0xFFF4781F);

  /// Builds a customized TextTheme with premium Inter typography,
  /// adjusting weights and letter spacing (tracking) for an AI-native feel.
  static TextTheme _buildTextTheme(TextTheme base, Brightness brightness) {
    final baseTextTheme = GoogleFonts.dmSansTextTheme(base);
    return baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _brandOrange,
      brightness: Brightness.light,
    ).copyWith(
      primary: _brandOrange,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFDBC8),
      onPrimaryContainer: const Color(0xFF5A1A00),
      surface: const Color(0xFFFBFBFD), // Premium, clean background slate
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: _buildTextTheme(ThemeData.light().textTheme, Brightness.light),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors
            .transparent, // Fully transparent to let Mesh background glow through
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide.none,
        ),
        color: Colors.white.withValues(
            alpha: 0.65), // Transparent base for glass backdrop filter
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.03),
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        backgroundColor: Colors.white.withValues(alpha: 0.7),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.1);
          }
          return const TextStyle(
              fontWeight: FontWeight.normal, fontSize: 12, letterSpacing: 0.1);
        }),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
        unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.1),
        indicator: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        color: const Color(0xFFF0F4F9),
        textStyle: GoogleFonts.dmSans(
          color: colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        contentTextStyle: GoogleFonts.dmSans(
          color: const Color(0xFF1F1F1F),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),
      extensions: [SemanticColors.light],
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFF4781F),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFF57C00),
      onPrimaryContainer: Color(0xFF572800),
      secondary: Color(0xFFC8C6C5),
      onSecondary: Color(0xFF303030),
      secondaryContainer: Color(0xFF474747),
      onSecondaryContainer: Color(0xFFB6B5B4),
      tertiary: Color(0xFFC8C6C6),
      onTertiary: Color(0xFF303030),
      tertiaryContainer: Color(0xFF9E9D9D),
      onTertiaryContainer: Color(0xFF353535),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF0C0C0E), // Deep rich AI-native dark background
      onSurface: Color(0xFFF1F1F4),
      surfaceContainerLowest: Color(0xFF070709),
      surfaceContainerLow: Color(0xFF131316),
      surfaceContainer: Color(0xFF18181C),
      surfaceContainerHigh: Color(0xFF222228),
      surfaceContainerHighest: Color(0xFF2C2C35),
      onSurfaceVariant: Color(0xFFDEC1AF),
      outline: Color(0xFFA68B7C),
      outlineVariant: Color(0xFF352B24),
      inverseSurface: Color(0xFFE5E2E1),
      onInverseSurface: Color(0xFF313030),
      inversePrimary: Color(0xFF964900),
      scrim: Color(0xFF000000),
      shadow: Color(0xFF000000),
      surfaceTint: Color(0xFFF4781F),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: _buildTextTheme(ThemeData.dark().textTheme, Brightness.dark),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent, // Fully transparent
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide.none,
        ),
        color: Colors.black
            .withValues(alpha: 0.35), // Dark semi-transparent container base
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: Color(0xFF2A2A32)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.1);
          }
          return const TextStyle(
              fontWeight: FontWeight.normal, fontSize: 12, letterSpacing: 0.1);
        }),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: colorScheme.onPrimary,
        unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
        unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.1),
        indicator: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        color: colorScheme.surfaceContainerHigh,
        textStyle: GoogleFonts.dmSans(
          color: colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2C2C35),
        contentTextStyle: GoogleFonts.dmSans(
          color: const Color(0xFFF1F1F4),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
      extensions: [SemanticColors.dark],
    );
  }
}
