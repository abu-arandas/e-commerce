import 'package:flutter/widgets.dart';

/// An 8-pt spacing scale plus shared radii and a couple of premium shadows,
/// so spacing stays consistent across the storefront and admin surfaces.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 72;

  // Section vertical rhythm scales with the viewport.
  static double section(double width) =>
      width < 768 ? 48 : (width < 1200 ? 72 : 96);

  // Radii
  static const double radiusSm = 6;
  static const double radiusMd = 12;
  static const double radiusLg = 20;
  static const Radius rSm = Radius.circular(radiusSm);
  static const Radius rMd = Radius.circular(radiusMd);
  static const Radius rLg = Radius.circular(radiusLg);
}

abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F14141A), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A14141A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> lifted = [
    BoxShadow(color: Color(0x1F14141A), blurRadius: 40, offset: Offset(0, 18)),
  ];

  static const List<BoxShadow> nav = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
}
