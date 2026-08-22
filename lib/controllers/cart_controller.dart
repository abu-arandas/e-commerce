import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../core/utils/app_constants.dart';
import '../core/utils/browser/browser.dart';
import '../core/utils/demo_data.dart';
import '../core/utils/store_settings.dart';
import '../core/utils/supabase_service.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/promotion_model.dart';
import '../models/variant_model.dart';
import 'catalog_controller.dart';

/// Shopping cart + promotions engine (PRD §3.1 "Dynamic Promotions"). Totals are
/// fully reactive; an applied promo code is re-validated on every cart change so
/// percentage discounts and minimum-order rules stay correct.
class CartController extends GetxController {
  final RxList<CartItem> items = <CartItem>[].obs;

  final RxnString appliedCode = RxnString();
  final Rxn<PromoValidation> appliedPromo = Rxn<PromoValidation>();
  final RxString promoError = ''.obs;
  final RxBool isApplyingPromo = false.obs;
  final RxBool isPlacingOrder = false.obs;

  /// localStorage key holding the serialised bag.
  static const String _storageKey = 'vf_cart_v1';

  @override
  void onInit() {
    super.onInit();
    _restore();
    // Persist on every change rather than at each call site, so no mutation can
    // forget to. `ever` fires on add/remove/refresh alike.
    ever(items, (_) => _persist());
    // A bag restored from a previous visit carries the stock figures from
    // whenever it was saved. Reconcile against the catalogue as it arrives, so
    // a line that sold out in the meantime is corrected here rather than
    // surviving all the way to a rejected checkout.
    //
    // Optional on purpose: the cart is useful on its own and must stay
    // constructable without the catalogue registered. Where there is no
    // catalogue there is nothing to reconcile against, and the server still
    // refuses to oversell at checkout.
    if (Get.isRegistered<CatalogController>()) {
      final catalog = Get.find<CatalogController>();
      ever(catalog.products, (_) => _reconcileStock());
      if (catalog.products.isNotEmpty) _reconcileStock();
    }
  }

  /// Clamp restored quantities to what is actually in stock, and drop lines
  /// whose SKU has sold out entirely. A SKU the catalogue does not carry is
  /// left alone -- absence there means "not loaded", not "gone".
  void _reconcileStock() {
    if (items.isEmpty || !Get.isRegistered<CatalogController>()) return;

    final stock = <String, int>{
      for (final p in Get.find<CatalogController>().products)
        for (final g in p.groups)
          for (final v in g.items) v.id: v.stockQuantity,
    };
    if (stock.isEmpty) return;

    var changed = false;
    final kept = <CartItem>[];
    for (final line in items) {
      final available = stock[line.variantItemId];
      if (available == null) {
        kept.add(line);
        continue;
      }
      if (available <= 0) {
        changed = true; // sold out entirely
        continue;
      }
      if (line.quantity > available || line.maxStock != available) {
        changed = true;
        kept.add(line.withStock(available));
      } else {
        kept.add(line);
      }
    }
    if (changed) items.assignAll(kept);
  }

  /// Reload a bag left behind by a previous visit. Anything malformed is
  /// discarded rather than thrown -- a corrupt entry must not brick the store.
  void _restore() {
    final raw = Browser.read(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      items.assignAll(decoded
          .whereType<Map>()
          .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e))));
    } catch (_) {
      Browser.remove(_storageKey);
    }
  }

  void _persist() {
    if (items.isEmpty) {
      Browser.remove(_storageKey);
      return;
    }
    try {
      Browser.write(_storageKey, jsonEncode(items.map((c) => c.toJson()).toList()));
    } catch (_) {
      // Storage full or blocked; the bag still works for this session.
    }
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------
  void add({
    required Product product,
    required VariantGroup group,
    required VariantItem item,
    int quantity = 1,
  }) {
    // Nothing to reserve: a sold-out SKU is not addable. Guarding here also
    // avoids clamp(1, 0), which throws rather than clamping.
    if (item.stockQuantity <= 0) return;

    final existing = items.firstWhereOrNull((c) => c.key == item.id);
    if (existing != null) {
      existing.quantity =
          (existing.quantity + quantity).clamp(1, item.stockQuantity);
      items.refresh();
    } else {
      items.add(CartItem.from(
        product: product,
        group: group,
        item: item,
        quantity: quantity.clamp(1, item.stockQuantity),
      ));
    }
    _refreshPromo();
  }

  void removeItem(String key) {
    items.removeWhere((c) => c.key == key);
    if (items.isEmpty) clearPromo();
    _refreshPromo();
  }

  void updateQuantity(String key, int quantity) {
    final line = items.firstWhereOrNull((c) => c.key == key);
    if (line == null) return;
    if (quantity <= 0) {
      removeItem(key);
      return;
    }
    line.quantity = quantity.clamp(1, line.maxStock);
    items.refresh();
    _refreshPromo();
  }

  void increment(String key) {
    final line = items.firstWhereOrNull((c) => c.key == key);
    if (line != null) updateQuantity(key, line.quantity + 1);
  }

  void decrement(String key) {
    final line = items.firstWhereOrNull((c) => c.key == key);
    if (line != null) updateQuantity(key, line.quantity - 1);
  }

  void clear() {
    items.clear();
    clearPromo();
  }

  // ---------------------------------------------------------------------------
  // Totals
  // ---------------------------------------------------------------------------
  int get itemCount => items.fold(0, (sum, c) => sum + c.quantity);
  bool get isEmpty => items.isEmpty;

  double get subtotal => items.fold(0.0, (sum, c) => sum + c.lineTotal);

  List<String> get categories =>
      items.map((c) => c.category).whereType<String>().toSet().toList();

  /// The basket as the promotions engine sees it: one entry per line, carrying
  /// the category the discount targeting is judged on and what that line is
  /// worth. A category-targeted code discounts only its own lines, so a single
  /// subtotal is not enough information.
  List<PromoLine> get promoLines => items
      .map((c) => PromoLine(category: c.category, lineTotal: c.lineTotal))
      .toList();

  double get discount => appliedPromo.value?.valid == true
      ? appliedPromo.value!.discountAmount
      : 0;

  bool get hasFreeShipping =>
      appliedPromo.value?.freeShipping == true ||
      subtotal >= StoreSettings.freeShippingThreshold.value;

  double get baseShipping {
    if (isEmpty) return 0;
    return subtotal >= StoreSettings.freeShippingThreshold.value
        ? 0
        : StoreSettings.flatShippingFee.value;
  }

  double get shipping => hasFreeShipping ? 0 : baseShipping;

  double get grandTotal {
    final total = subtotal - discount + shipping;
    return total < 0 ? 0 : total;
  }

  double get amountToFreeShipping {
    final remaining = StoreSettings.freeShippingThreshold.value - subtotal;
    return remaining > 0 ? remaining : 0;
  }

  // ---------------------------------------------------------------------------
  // Promotions
  // ---------------------------------------------------------------------------
  Future<bool> applyPromo(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      promoError.value = 'Enter a promo code';
      return false;
    }
    isApplyingPromo.value = true;
    promoError.value = '';
    try {
      final result = await _validate(trimmed);
      if (result.valid) {
        appliedCode.value = trimmed.toUpperCase();
        appliedPromo.value = result;
        return true;
      } else {
        appliedCode.value = null;
        appliedPromo.value = null;
        promoError.value = result.reason ?? 'Promo code could not be applied';
        return false;
      }
    } finally {
      isApplyingPromo.value = false;
    }
  }

  void clearPromo() {
    appliedCode.value = null;
    appliedPromo.value = null;
    promoError.value = '';
  }

  /// Re-validate a still-applied code after the cart changes; silently drop it
  /// if it no longer qualifies (e.g. subtotal fell below the minimum).
  Future<void> _refreshPromo() async {
    final code = appliedCode.value;
    if (code == null || isEmpty) return;
    final result = await _validate(code);
    if (result.valid) {
      appliedPromo.value = result;
    } else {
      // Clear the code as well. A lingering code is still sent to place_order,
      // which rejects an invalid promotion and fails the whole checkout.
      appliedCode.value = null;
      appliedPromo.value = null;
      promoError.value = result.reason ?? 'Promo no longer applies';
    }
  }

  Future<PromoValidation> _validate(String code) async {
    if (SupabaseService.isReady) {
      try {
        // validate_promotion(text, jsonb) — the basket goes over line by line
        // so the server can discount only the categories a promotion targets.
        final res = await SupabaseService.client.rpc(
          AppConstants.rpcValidatePromotion,
          params: {
            'p_code': code,
            'p_lines': promoLines.map((l) => l.toJson()).toList(),
          },
        );
        return PromoValidation.fromJson(Map<String, dynamic>.from(res as Map));
      } catch (e) {
        return PromoValidation.invalid('Validation failed: $e');
      }
    }
    return DemoData.validatePromo(code, promoLines);
  }

  // ---------------------------------------------------------------------------
  // Checkout
  // ---------------------------------------------------------------------------
  Future<Order?> placeOrder({
    Map<String, dynamic>? shippingAddress,
    String? contactEmail,
  }) async {
    if (isEmpty) return null;
    isPlacingOrder.value = true;
    try {
      if (SupabaseService.isReady) {
        final res = await SupabaseService.client.rpc(
          AppConstants.rpcPlaceOrder,
          // place_order(jsonb, text, jsonb, text). The shipping charge is not
          // passed: the server reads it from store_settings, so a caller
          // cannot ship itself for free.
          params: {
            'p_items': items.map((e) => e.toOrderLine()).toList(),
            'p_promo_code': appliedCode.value,
            'p_shipping_address': shippingAddress,
            'p_contact_email': contactEmail,
          },
        );
        final map = Map<String, dynamic>.from(res as Map);
        final order = _orderFromResult(map, contactEmail);
        clear();
        return order;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final order = _demoOrder(contactEmail);
        clear();
        return order;
      }
    } catch (e) {
      promoError.value = 'Order failed: $e';
      if (kDebugMode) debugPrint('placeOrder error: $e');
      return null;
    } finally {
      isPlacingOrder.value = false;
    }
  }

  Order _orderFromResult(Map<String, dynamic> map, String? email) => Order(
        id: map['order_id']?.toString() ?? _pseudoId(),
        status: OrderStatus.pending,
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? subtotal,
        discountTotal: (map['discount_total'] as num?)?.toDouble() ?? discount,
        shippingTotal: (map['shipping_total'] as num?)?.toDouble() ?? shipping,
        grandTotal: (map['grand_total'] as num?)?.toDouble() ?? grandTotal,
        promoCode: appliedCode.value,
        contactEmail: email,
        createdAt: DateTime.now(),
        lines: _snapshotLines(),
      );

  Order _demoOrder(String? email) => Order(
        id: _pseudoId(),
        status: OrderStatus.pending,
        subtotal: subtotal,
        discountTotal: discount,
        shippingTotal: shipping,
        grandTotal: grandTotal,
        promoCode: appliedCode.value,
        contactEmail: email,
        createdAt: DateTime.now(),
        lines: _snapshotLines(),
      );

  List<OrderLine> _snapshotLines() => items
      .map((c) => OrderLine(
            id: c.variantItemId,
            productTitle: c.productTitle,
            variantName: c.colorName,
            sizeLabel: c.sizeLabel,
            sku: c.sku,
            category: c.category,
            unitPrice: c.unitPrice,
            quantity: c.quantity,
            lineTotal: c.lineTotal,
          ))
      .toList();

  String _pseudoId() {
    final ts = DateTime.now()
        .microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    return '$ts-demo-0000-0000-000000000000';
  }
}
