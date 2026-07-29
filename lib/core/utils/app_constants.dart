/// App-wide constants: table names, RPC names, and small UI limits.
abstract final class AppConstants {
  static const String appName = 'Vanguard Fashion';

  // Supabase table names (kept in one place so model mappers stay in sync).
  static const String tblProducts = 'products';
  static const String tblPromotions = 'promotions';
  static const String tblProfiles = 'profiles';
  static const String tblOrders = 'orders';
  static const String tblStoreSettings = 'store_settings';

  // RPCs
  static const String rpcValidatePromotion = 'validate_promotion';
  static const String rpcPlaceOrder = 'place_order';
  static const String rpcRestockOrder = 'restock_order';
  static const String rpcSaveProduct = 'save_product';
  static const String rpcAdminStats = 'admin_stats';

  /// Select expression for a product with its full nested variant tree.
  static const String productTree = '*, variant_groups(*, variant_items(*))';

  static const int lowStockThreshold = 5;
  static const int freeReturnsDays = 30;
}

/// Product categories used for filtering and promo targeting.
abstract final class Categories {
  static const List<String> all = [
    'Knitwear',
    'Trousers',
    'Dresses',
    'Outerwear',
    'Accessories',
  ];
}
