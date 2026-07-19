import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Thin wrapper around Supabase initialisation and client access.
///
/// When Supabase credentials are absent (see [Env.hasSupabase]) the app stays
/// fully explorable against in-memory demo data — controllers consult
/// [isReady] before hitting the network.
abstract final class SupabaseService {
  static bool _ready = false;

  /// True once [init] has successfully configured a live Supabase client.
  static bool get isReady => _ready;

  /// The active client. Only valid when [isReady] is true.
  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static Future<void> init() async {
    if (!Env.hasSupabase) {
      _ready = false;
      return;
    }
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _ready = true;
  }

  /// Public URL for an object in the products storage bucket.
  static String? storageUrl(String path) {
    if (!_ready) return null;
    return client.storage.from('products').getPublicUrl(path);
  }
}
