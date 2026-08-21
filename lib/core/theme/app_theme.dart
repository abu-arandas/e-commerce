import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the light (storefront) and dark (admin ink) [ThemeData].
abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: AppColors.textOnInk,
      secondary: AppColors.gold,
      onSecondary: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: AppTypography.textTheme(
          AppColors.textPrimary, AppColors.textSecondary),
      dividerColor: AppColors.line,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.textOnInk,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(AppSpacing.rSm)),
          textStyle: base.textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(AppSpacing.rSm)),
          textStyle: base.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.goldDeep),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(AppSpacing.rMd)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(AppSpacing.rSm),
          borderSide: BorderSide(color: AppColors.line),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(AppSpacing.rSm),
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(AppSpacing.rSm),
          borderSide: BorderSide(color: AppColors.gold, width: 1.5),
        ),
        labelStyle: base.textTheme.bodyMedium,
        hintStyle: base.textTheme.bodyMedium?.copyWith(color: AppColors.mist),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceAlt,
        side: BorderSide.none,
        labelStyle: base.textTheme.labelMedium,
        shape: const StadiumBorder(),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: AppColors.textOnInk),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Ink theme used for the admin panel — a focused, low-glare dark surface.
  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: AppColors.ink,
      secondary: AppColors.goldSoft,
      onSecondary: AppColors.ink,
      surface: AppColors.inkSoft,
      onSurface: AppColors.textOnInk,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.ink,
      textTheme: AppTypography.textTheme(
          AppColors.textOnInk, AppColors.textMutedOnInk),
      dividerColor: const Color(0xFF2A2A30),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.textOnInk,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.inkSoft,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(AppSpacing.rMd)),
      ),
      dividerTheme: const DividerThemeData(
          color: Color(0xFF2A2A30), thickness: 1, space: 1),
    );
  }
}
