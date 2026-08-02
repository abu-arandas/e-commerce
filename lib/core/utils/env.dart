/// Compile-time environment configuration, supplied via `--dart-define`.
///
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=... \
///     --dart-define=SUPABASE_ANON_KEY=...
///
/// See `.env.example`. Values are baked at build time so no secrets file ships
/// with the bundle; the anon key is publishable and safe for the client.
abstract final class Env {
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Flat shipping fee (minor currency unit handled at display time).
  static const double flatShippingFee =
      int.fromEnvironment('FLAT_SHIPPING_FEE', defaultValue: 12) * 1.0;

  /// Free-shipping threshold used for storefront messaging.
  static const double freeShippingThreshold =
      int.fromEnvironment('FREE_SHIPPING_THRESHOLD', defaultValue: 150) * 1.0;

  /// True when both Supabase credentials are present. When false the app runs
  /// against in-memory demo data so the UI is always explorable.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
