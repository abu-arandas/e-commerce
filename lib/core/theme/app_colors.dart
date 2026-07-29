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

  // Admin surfaces
  static const Color inkLine = Color(0xFF2A2A30); // hairline on ink
  static const Color inkLineSoft = Color(0xFF23232A);

  // Translucent tints for status pills and highlighted borders.
  //
  // Written as explicit ARGB constants rather than derived with
  // `Color.withOpacity` / `withAlpha`: those are deprecated on newer Flutter,
  // while their replacement (`withValues`) does not exist on the SDK floor this
  // project supports — so no runtime derivation is safe across the range.
  // Alpha 0x29 ≈ 16%, 0x66 = 40%, 0x80 = 50%.
  static const Color goldTint = Color(0x29C9A24B);
  static const Color goldEdge = Color(0x80C9A24B);
  static const Color goldEdgeSoft = Color(0x66C9A24B);

  static const Color successTint = Color(0x293F7D5B);
  static const Color successEdge = Color(0x803F7D5B);

  static const Color warningTint = Color(0x29B8862B);
  static const Color warningEdge = Color(0x80B8862B);

  static const Color dangerTint = Color(0x29A23B3B);
  static const Color dangerEdge = Color(0x80A23B3B);

  static const Color infoTint = Color(0x293A5A7A);
  static const Color infoEdge = Color(0x803A5A7A);

  /// Parse a `#RRGGBB` swatch value (as stored on `variant_groups.color_hex`),
  /// falling back to a neutral for anything malformed.
  static Color fromHex(String? hex, {Color fallback = mist}) {
    final h = hex?.replaceFirst('#', '').trim();
    if (h == null || h.length != 6) return fallback;
    final value = int.tryParse('FF$h', radix: 16);
    return value == null ? fallback : Color(value);
  }
}
