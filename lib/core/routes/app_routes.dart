/// Named routes. Path-based (no `#`) URL strategy is enabled in `main.dart`, and
/// product pages accept a `?color=` query param so a specific colour variant can
/// be deep-linked (PRD §6.3), e.g. `/product/cashmere-turtleneck?color=midnight-blue`.
abstract final class AppRoutes {
  static const String home = '/';
  static const String shop = '/shop';
  static const String product = '/product/:slug';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orderConfirmation = '/order/confirmed';
  static const String account = '/account';
  static const String login = '/login';
  static const String wishlist = '/wishlist';

  // Admin
  static const String adminDashboard = '/admin';
  static const String adminProducts = '/admin/products';
  static const String adminPromotions = '/admin/promotions';
  static const String adminOrders = '/admin/orders';

  /// Build a storefront product path, optionally targeting a colour group.
  static String productPath(String slug, {String? colorSlug}) {
    final base = '/product/$slug';
    return colorSlug == null ? base : '$base?color=$colorSlug';
  }
}
