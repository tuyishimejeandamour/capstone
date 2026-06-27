import 'package:flutter/material.dart';

/// Central theme definition for Student Health Guide (Premium Dark Green Wellness Theme).
///
/// This theme implements a calming, high-end "Deep Forest" color palette.
/// The deep forest-green tones are chosen to reduce late-night anxiety
/// and make students feel safe and comfortable.
abstract final class AppTheme {
  // ---------------------------------------------------------------------------
  // Deep Forest Green Color Constants
  // ---------------------------------------------------------------------------

  /// Deep forest-green page background.
  static const Color background = Color(0xFF081510);

  /// Default surface container (cards, drawer background).
  static const Color surface = Color(0xFF0D1F14);

  /// Elevated surfaces (dialogs, input fields, active buttons).
  static const Color surfaceElevated = Color(0xFF132A1A);

  /// Primary calming wellness mint/teal accent. Used for bubbles, tags, indicators.
  static const Color accent = Color(0xFF3BE2B0);

  /// Secondary wellness lavender/violet accent. Used for student highlight text.
  static const Color secondaryAccent = Color(0xFF926BFF);

  /// AI response chat bubble background (subtle and readable).
  static const Color bubble = Color(0xFF0D1F14);

  /// User chat bubble background (solid flat).
  static const Color userBubble = Color(0xFF132A1A);

  /// Positive state.
  static const Color success = Color(0xFF3BE2B0);

  /// Calming rose red for error state.
  static const Color error = Color(0xFFE56B6B);

  /// Full-opacity soft white text.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Comforting slate blue secondary text.
  static const Color textSecondary = Color(0xFF8FA0B5);

  /// Very soft muted text for metadata and stamps.
  static const Color textMuted = Color(0x66FFFFFF);

  /// Subtle shadow color.
  static const Color shadow = Color(0x1A000000);

  // ---------------------------------------------------------------------------
  // Geometry & Borders
  // ---------------------------------------------------------------------------

  /// Default corner radius for cards and fields (20 dp).
  static const double radiusDefault = 20.0;

  /// Large corner radius for chat bubbles and sheets (24 dp).
  static const double radiusLarge = 24.0;

  /// Small corner radius for chips and icons (12 dp).
  static const double radiusSmall = 12.0;

  // ---------------------------------------------------------------------------
  // ThemeData Builder
  // ---------------------------------------------------------------------------

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,

      primary: accent,
      onPrimary: background,
      primaryContainer: surfaceElevated,
      onPrimaryContainer: textPrimary,

      secondary: secondaryAccent,
      onSecondary: textPrimary,
      secondaryContainer: surface,
      onSecondaryContainer: textPrimary,

      tertiary: success,
      onTertiary: background,
      tertiaryContainer: surface,
      onTertiaryContainer: textPrimary,

      error: error,
      onError: textPrimary,
      errorContainer: Color(0xFF2D1616),
      onErrorContainer: error,

      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceElevated,
      surfaceContainerHigh: bubble,
      surfaceContainer: surface,
      surfaceContainerLow: surface,
      surfaceContainerLowest: background,
      surfaceDim: background,
      surfaceBright: surfaceElevated,

      // ignore: deprecated_member_use
      background: background,
      // ignore: deprecated_member_use
      onBackground: textPrimary,

      outline: Color(0xFF1E3525),
      outlineVariant: Color(0xFF142019),

      shadow: shadow,
      scrim: Colors.black87,

      inverseSurface: textPrimary,
      onInverseSurface: background,
      inversePrimary: accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // Card
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusDefault)),
          side: const BorderSide(color: Color(0xFF1E3525), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        elevation: 12,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLarge)),
          side: const BorderSide(color: Color(0xFF1E3525), width: 1.5),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        contentTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceElevated,
        modalBackgroundColor: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusLarge),
          ),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        hintStyle: const TextStyle(
          color: textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: Color(0xFF1E3525), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: Color(0xFF1E3525), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusDefault)),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          ),
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent,
        disabledColor: surface,
        labelStyle: const TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: Color(0xFF1E3525), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // Switches
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? accent : textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.25)
              : surfaceElevated;
        }),
      ),

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 48,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          height: 1.15,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 38,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1.25,
        ),
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.33,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          height: 1.35,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          height: 1.45,
        ),
        titleSmall: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.4,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          height: 1.4,
        ),
        labelMedium: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          height: 1.35,
        ),
        labelSmall: TextStyle(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          height: 1.4,
        ),
      ),
    );
  }
}
