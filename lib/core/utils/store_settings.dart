import 'package:get/get.dart';

import 'app_constants.dart';
import 'env.dart';
import 'json_parse.dart';
import 'supabase_service.dart';

/// Storefront commerce settings (shipping fee and free-shipping threshold).
///
/// These values are **authoritative on the server** — `place_order` computes
/// shipping from the same `store_settings` row rather than trusting anything
/// the client sends. What is held here is a reactive copy used purely for
/// display (order summary, free-shipping progress bar), so the figures the
/// shopper sees match the ones they are charged.
///
/// Before [load] completes — and whenever Supabase is not configured — the
/// compile-time [Env] defaults apply.
abstract final class StoreSettings {
  static final RxDouble flatShippingFee = Env.flatShippingFee.obs;
  static final RxDouble freeShippingThreshold = Env.freeShippingThreshold.obs;

  /// Fetch the live values. Safe to call unconditionally; a failure simply
  /// leaves the [Env] fallbacks in place.
  static Future<void> load() async {
    if (!SupabaseService.isReady) return;
    try {
      final row = await SupabaseService.client
          .from(AppConstants.tblStoreSettings)
          .select()
          .maybeSingle();
      if (row == null) return;
      final map = Map<String, dynamic>.from(row);
      flatShippingFee.value =
          J.toDouble(map['flat_shipping_fee'], Env.flatShippingFee);
      freeShippingThreshold.value =
          J.toDouble(map['free_shipping_threshold'], Env.freeShippingThreshold);
    } catch (_) {
      // Non-fatal: keep the compile-time defaults.
    }
  }
}
