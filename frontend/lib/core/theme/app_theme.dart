import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extension to provide consistent "Glassmorphism" properties across the app.
@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  final double blurSigma;
  final double baseOpacity;
  final double borderAlpha;
  final double pulseMinOpacity;

  const GlassTheme({
    this.blurSigma = 8.0,
    this.baseOpacity = 0.1,
    this.borderAlpha = 0.2,
    this.pulseMinOpacity = 0.4,
  });

  @override
  GlassTheme copyWith({
    double? blurSigma,
    double? baseOpacity,
    double? borderAlpha,
    double? pulseMinOpacity,
  }) {
    return GlassTheme(
      blurSigma: blurSigma ?? this.blurSigma,
      baseOpacity: baseOpacity ?? this.baseOpacity,
      borderAlpha: borderAlpha ?? this.borderAlpha,
      pulseMinOpacity: pulseMinOpacity ?? this.pulseMinOpacity,
    );
  }

  @override
  GlassTheme lerp(ThemeExtension<GlassTheme>? other, double t) {
    if (other is! GlassTheme) return this;
    return GlassTheme(
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t) ?? blurSigma,
      baseOpacity: lerpDouble(baseOpacity, other.baseOpacity, t) ?? baseOpacity,
      borderAlpha: lerpDouble(borderAlpha, other.borderAlpha, t) ?? borderAlpha,
      pulseMinOpacity:
          lerpDouble(pulseMinOpacity, other.pulseMinOpacity, t) ??
          pulseMinOpacity,
    );
  }

  static double? lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}

class AppTheme {
  static TextTheme _buildTextTheme(Brightness brightness) {
    final baseTheme = brightness == Brightness.light
        ? ThemeData(brightness: Brightness.light).textTheme
        : ThemeData(brightness: Brightness.dark).textTheme;

    return GoogleFonts.quicksandTextTheme(baseTheme).copyWith(
      displayLarge: GoogleFonts.quicksand(
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
      titleLarge: GoogleFonts.quicksand(
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 1.2,
      ),
      labelLarge: GoogleFonts.quicksand(
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      bodyLarge: GoogleFonts.quicksand(
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      bodyMedium: GoogleFonts.quicksand(
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      bodySmall: GoogleFonts.quicksand(
        fontWeight: FontWeight.w500,
        color: Colors.white70,
      ),
    );
  }

  static InputDecorationTheme _buildInputTheme(GlassTheme glass) {
    final border = OutlineInputBorder(
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: glass.borderAlpha),
      ),
      borderRadius: BorderRadius.circular(10),
    );
    final focusedBorder = border.copyWith(
      borderSide: const BorderSide(color: Colors.white),
    );
    final errorBorder = border.copyWith(
      borderSide: const BorderSide(color: Colors.redAccent),
    );

    return InputDecorationTheme(
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      floatingLabelStyle: const TextStyle(color: Colors.white),
      enabledBorder: border,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder,
      errorStyle: const TextStyle(color: Colors.redAccent),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  static ElevatedButtonThemeData _buildButtonTheme(GlassTheme glass) {
    return ElevatedButtonThemeData(
      style: _elevatedButtonFrom(
        backgroundColor: Colors.white.withValues(alpha: glass.baseOpacity * 2),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(
          alpha: glass.baseOpacity,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: glass.borderAlpha * 1.5),
          ),
        ),
        elevation: 0,
      ),
    );
  }

  // Helper for ElevatedButton.styleFrom equivalent since we can't call it easily in const
  static ButtonStyle _elevatedButtonFrom({
    required Color backgroundColor,
    required Color foregroundColor,
    required Color disabledBackgroundColor,
    required EdgeInsetsGeometry padding,
    required OutlinedBorder shape,
    required double elevation,
  }) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return disabledBackgroundColor;
        }
        return backgroundColor;
      }),
      foregroundColor: WidgetStateProperty.all(foregroundColor),
      padding: WidgetStateProperty.all(padding),
      shape: WidgetStateProperty.all(shape),
      elevation: WidgetStateProperty.all(elevation),
      overlayColor: WidgetStateProperty.all(Colors.white10),
    );
  }

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    const glass = GlassTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurpleAccent,
        brightness: brightness,
      ),
      textTheme: _buildTextTheme(brightness),
      inputDecorationTheme: _buildInputTheme(glass),
      elevatedButtonTheme: _buildButtonTheme(glass),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      extensions: const [glass],
    );
  }
}
