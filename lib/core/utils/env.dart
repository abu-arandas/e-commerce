/// Compile-time environment configuration, supplied via `--dart-define`.
///
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=... \
///     --dart-define=SUPABASE_ANON_KEY=...
///
/// See `.env.example`. Values are baked at build time so no secrets file ships
/// with the bundle; the anon key is publishable and safe for the client.
///
/// Note: Dart only provides `fromEnvironment` on `String`, `int` and `bool` —
/// there is no `double.fromEnvironment` (the Flutter docs listed one in error,
/// see flutter/flutter#124665). Numeric defines are therefore read as strings
/// and parsed here.
abstract final class Env {
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static const String _flatShippingFee =
      String.fromEnvironment('FLAT_SHIPPING_FEE', defaultValue: '12.0');

  static const String _freeShippingThreshold =
      String.fromEnvironment('FREE_SHIPPING_THRESHOLD', defaultValue: '150.0');

  /// Fallback flat shipping fee. The live value is served by the backend (see
  /// [StoreSettings]); this is only used before/without a Supabase connection.
  static double get flatShippingFee =>
      double.tryParse(_flatShippingFee) ?? 12.0;

  /// Fallback free-shipping threshold. See [flatShippingFee].
  static double get freeShippingThreshold =>
      double.tryParse(_freeShippingThreshold) ?? 150.0;

  /// True when both Supabase credentials are present. When false the app runs
  /// against in-memory demo data so the UI is always explorable.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
