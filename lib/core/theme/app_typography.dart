import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typographic system: a high-contrast serif display face (Cormorant Garamond)
/// paired with a clean grotesque for body/UI (Inter). Sizes scale up gently at
/// larger breakpoints via [scaleFor] (PRD §6.2 "sm: adjust typography scaling").
abstract final class AppTypography {
  static TextTheme textTheme(Color primary, Color secondary) {
    final display = GoogleFonts.cormorantGaramond(
      color: primary,
      fontWeight: FontWeight.w500,
      height: 1.05,
    );
    final body = GoogleFonts.inter(color: primary, height: 1.5);

    return TextTheme(
      displayLarge: display.copyWith(
        fontSize: 64,
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
      ),
      displayMedium: display.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      displaySmall: display.copyWith(fontSize: 36, fontWeight: FontWeight.w600),
      headlineLarge: display.copyWith(fontSize: 32),
      headlineMedium: display.copyWith(fontSize: 26),
      headlineSmall: display.copyWith(fontSize: 22),
      titleLarge: GoogleFonts.inter(
        color: primary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.inter(
        color: primary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.inter(
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      bodyLarge: body.copyWith(fontSize: 16),
      bodyMedium: body.copyWith(fontSize: 14),
      bodySmall: body.copyWith(fontSize: 12.5, color: secondary),
      labelLarge: GoogleFonts.inter(
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      labelMedium: GoogleFonts.inter(
        color: secondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
      ),
      labelSmall: GoogleFonts.inter(
        color: secondary,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
      ),
    );
  }

  /// Uppercase "eyebrow" / label used for section kickers and nav.
  static TextStyle eyebrow({Color color = AppColors.gold}) => GoogleFonts.inter(
    color: color,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.4,
  );

  /// Serif brand wordmark style.
  static TextStyle wordmark({Color color = AppColors.ink, double size = 24}) =>
      GoogleFonts.cormorantGaramond(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 4,
      );

  /// Small viewport-driven scale factor for body/UI text (PRD §6.2).
  static double scaleFor(double width) {
    if (width < 576) return 0.94;
    if (width < 768) return 0.97;
    if (width < 1200) return 1.0;
    return 1.03;
  }
}
