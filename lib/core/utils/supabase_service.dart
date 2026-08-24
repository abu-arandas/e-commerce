import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_constants.dart';
import 'env.dart';

/// Thin wrapper around Supabase initialisation and client access.
///
/// When Supabase credentials are absent (see [Env.hasSupabase]) the app stays
/// fully explorable against in-memory demo data — controllers consult
/// [isReady] before hitting the network.
abstract final class SupabaseService {
  static bool _ready = false;
  static SupabaseClient? _mockClient;

  @visibleForTesting
  static void setMockClient(SupabaseClient mockClient) {
    _mockClient = mockClient;
    _ready = true;
  }

  @visibleForTesting
  static void clearMockClient() {
    _mockClient = null;
    _ready = false;
  }

  /// True once [init] has successfully configured a live Supabase client.
  static bool get isReady => _ready;

  /// The active client. Only valid when [isReady] is true.
  static SupabaseClient get client => _mockClient ?? Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static Future<void> init() async {
    if (!Env.hasSupabase) {
      _ready = false;
      return;
    }
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _ready = true;
  }

  /// Public URL for an object in the products storage bucket.
  static String? storageUrl(String path) {
    if (!_ready) return null;
    // Named via AppConstants so the bucket lives in one place, which is the
    // reason that constant exists — this call used to hardcode it.
    return client.storage.from(AppConstants.storageBucket).getPublicUrl(path);
  }
}
