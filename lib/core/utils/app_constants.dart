/// App-wide constants: table names, storage buckets, and small UI limits.
abstract final class AppConstants {
  static const String appName = 'Vanguard Fashion';
  static const String tagline = 'Premium designer apparel';

  // Supabase table names (kept in one place so model mappers stay in sync).
  static const String tblProducts = 'products';
  static const String tblVariantGroups = 'variant_groups';
  static const String tblVariantItems = 'variant_items';
  static const String tblPromotions = 'promotions';
  static const String tblProfiles = 'profiles';
  static const String tblAddresses = 'addresses';
  static const String tblWishlists = 'wishlists';
  static const String tblOrders = 'orders';
  static const String tblOrderItems = 'order_items';

  // RPCs
  static const String rpcValidatePromotion = 'validate_promotion';
  static const String rpcPlaceOrder = 'place_order';
  static const String rpcRestockOrder = 'restock_order';

  static const String storageBucket = 'products';

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
