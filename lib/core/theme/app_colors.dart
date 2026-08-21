import 'package:flutter/material.dart';

/// Vanguard Fashion palette — an editorial, high-contrast luxury system:
/// near-black "ink", warm ivory paper, and a restrained brushed-gold accent.
abstract final class AppColors {
  // Brand neutrals
  static const Color ink = Color(0xFF0E0E10); // near-black, primary brand
  static const Color inkSoft = Color(0xFF1B1B1F);
  static const Color charcoal = Color(0xFF36373B);
  static const Color slate = Color(0xFF6B6C72);
  static const Color mist = Color(0xFFA9AAB0);

  // Paper / surfaces
  static const Color paper = Color(0xFFF7F5F0); // warm off-white background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEFEBE3);
  static const Color line = Color(0xFFE3DED4); // hairline dividers

  // Accent — brushed gold
  static const Color gold = Color(0xFFC9A24B);
  static const Color goldDeep = Color(0xFFA9853A);
  static const Color goldSoft = Color(0xFFEBD9AE);

  // Semantic
  static const Color success = Color(0xFF3F7D5B);
  static const Color warning = Color(0xFFB8862B);
  static const Color danger = Color(0xFFA23B3B);
  static const Color info = Color(0xFF3A5A7A);

  // Text
  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF55565C);
  static const Color textOnInk = Color(0xFFF5F3EF);
  static const Color textMutedOnInk = Color(0xFFB4B2AC);

  // Stock signalling
  static const Color inStock = success;
  static const Color lowStock = warning;
  static const Color outOfStock = danger;
}
