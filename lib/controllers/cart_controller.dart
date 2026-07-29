import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../core/utils/app_constants.dart';
import '../core/utils/browser/browser.dart';
import '../core/utils/demo_data.dart';
import '../core/utils/json_parse.dart';
import '../core/utils/store_settings.dart';
import '../core/utils/supabase_service.dart';
import '../core/utils/uuid.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/promotion_model.dart';
import '../models/variant_model.dart';

/// Shopping cart + promotions engine (PRD §3.1 "Dynamic Promotions"). Totals are
/// fully reactive; an applied promo code is re-validated on every cart change so
/// percentage discounts and minimum-order rules stay correct.
///
/// The cart survives a page refresh via `localStorage` — a browser reload is a
/// routine event on web and must not empty the bag.
class CartController extends GetxController {
  CartController({this.onOrderPlaced});

  /// Invoked with each successfully placed order, so order history can record
  /// it without the cart having to know about that controller.
  final void Function(Order order)? onOrderPlaced;

  static const String _storageKey = 'vanguard.cart.v1';

  final RxList<CartItem> items = <CartItem>[].obs;

  final RxnString appliedCode = RxnString();
  final Rxn<PromoValidation> appliedPromo = Rxn<PromoValidation>();
  final RxString promoError = ''.obs;
  final RxBool isApplyingPromo = false.obs;
  final RxBool isPlacingOrder = false.obs;

  /// Set when [placeOrder] fails, so checkout can explain what went wrong.
  final RxString checkoutError = ''.obs;

  /// Monotonic token used to discard promo validations that have been overtaken
  /// by a newer one — rapid quantity clicks would otherwise let a stale
  /// response win and leave an incorrect discount on screen.
  int _promoRequest = 0;

  @override
  void onInit() {
    super.onInit();
    _restore();
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
    if (item.stockQuantity <= 0) return;
    final existing = items.firstWhereOrNull((c) => c.key == item.id);
    if (existing != null) {
      existing.quantity = (existing.quantity + quantity).clamp(1, item.stockQuantity);
      items.refresh();
    } else {
      items.add(CartItem.from(
        product: product,
        group: group,
        item: item,
        quantity: quantity.clamp(1, item.stockQuantity),
      ));
    }
    _afterChange();
  }

  void removeItem(String key) {
    items.removeWhere((c) => c.key == key);
    _afterChange();
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
    _afterChange();
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
    _persist();
  }

  void _afterChange() {
    if (items.isEmpty) {
      clearPromo();
    } else {
      unawaited(_refreshPromo());
    }
    _persist();
  }

  // ---------------------------------------------------------------------------
  // Totals
  // ---------------------------------------------------------------------------
  int get itemCount => items.fold(0, (sum, c) => sum + c.quantity);
  bool get isEmpty => items.isEmpty;

  double get subtotal => items.fold(0.0, (sum, c) => sum + c.lineTotal);

  /// Per-line categories and totals, as the promotions engine needs them.
  List<PromoLine> get promoLines => items
      .map((c) => PromoLine(category: c.category, lineTotal: c.lineTotal))
      .toList();

  double get discount =>
      appliedPromo.value?.valid == true ? appliedPromo.value!.discountAmount : 0;

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
    final seq = ++_promoRequest;
    try {
      final result = await _validate(trimmed);
      if (seq != _promoRequest) return result.valid;
      if (result.valid) {
        appliedCode.value = trimmed.toUpperCase();
        appliedPromo.value = result;
        return true;
      }
      appliedCode.value = null;
      appliedPromo.value = null;
      promoError.value = result.reason ?? 'Promo code could not be applied';
      return false;
    } finally {
      if (seq == _promoRequest) isApplyingPromo.value = false;
      _persist();
    }
  }

  void clearPromo() {
    _promoRequest++; // cancel any in-flight validation
    appliedCode.value = null;
    appliedPromo.value = null;
    promoError.value = '';
    _persist();
  }

  /// Re-validate a still-applied code after the cart changes, dropping it if it
  /// no longer qualifies (e.g. the subtotal fell below the minimum).
  ///
  /// Both the code and the computed discount are cleared together: leaving the
  /// code set would send it to `place_order`, which rejects invalid promotions
  /// outright and would fail the whole checkout.
  Future<void> _refreshPromo() async {
    final code = appliedCode.value;
    if (code == null || isEmpty) return;
    final seq = ++_promoRequest;
    final result = await _validate(code);
    if (seq != _promoRequest) return; // superseded by a newer change
    if (result.valid) {
      appliedPromo.value = result;
      promoError.value = '';
    } else {
      appliedCode.value = null;
      appliedPromo.value = null;
      promoError.value = result.reason ?? 'Promo no longer applies';
    }
    _persist();
  }

  Future<PromoValidation> _validate(String code) async {
    if (SupabaseService.isReady) {
      try {
        final res = await SupabaseService.client.rpc(
          AppConstants.rpcValidatePromotion,
          params: {
            'p_code': code,
            'p_lines': promoLines.map((e) => e.toJson()).toList(),
          },
        );
        return PromoValidation.fromJson(Map<String, dynamic>.from(res as Map));
      } catch (e) {
        if (kDebugMode) debugPrint('validate_promotion error: $e');
        return PromoValidation.invalid('Could not validate that code right now');
      }
    }
    return DemoData.validatePromo(code, promoLines);
  }

  // ---------------------------------------------------------------------------
  // Checkout
  // ---------------------------------------------------------------------------

  /// Places the order. Returns the created [Order], or null with
  /// [checkoutError] set on failure.
  Future<Order?> placeOrder({
    Map<String, dynamic>? shippingAddress,
    String? contactEmail,
  }) async {
    if (isEmpty) return null;
    isPlacingOrder.value = true;
    checkoutError.value = '';
    try {
      if (SupabaseService.isReady) {
        // Note: shipping is deliberately NOT sent — `place_order` recomputes it
        // (and every unit price) server-side from `store_settings`.
        final res = await SupabaseService.client.rpc(
          AppConstants.rpcPlaceOrder,
          params: {
            'p_items': items.map((e) => e.toOrderLine()).toList(),
            'p_promo_code': appliedCode.value,
            'p_shipping_address': shippingAddress,
            'p_contact_email': contactEmail,
          },
        );
        final order = _orderFromResult(
          Map<String, dynamic>.from(res as Map),
          contactEmail,
        );
        clear();
        onOrderPlaced?.call(order);
        return order;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final order = _demoOrder(contactEmail);
        clear();
        onOrderPlaced?.call(order);
        return order;
      }
    } catch (e) {
      checkoutError.value = _friendlyCheckoutError(e);
      if (kDebugMode) debugPrint('placeOrder error: $e');
      return null;
    } finally {
      isPlacingOrder.value = false;
    }
  }

  /// Surfaces the useful part of a Postgres `raise exception` message (e.g.
  /// "Insufficient stock for SKU …") without leaking the raw error envelope.
  String _friendlyCheckoutError(Object error) {
    final text = error.toString();
    for (final marker in const [
      'Insufficient stock',
      'Promotion rejected',
      'no longer exists',
      'Cannot place an empty order',
    ]) {
      final idx = text.indexOf(marker);
      if (idx >= 0) {
        final end = text.indexOf(RegExp(r'[,}]'), idx);
        return end > idx ? text.substring(idx, end) : text.substring(idx);
      }
    }
    return 'We could not complete your order. Please try again.';
  }

  Order _orderFromResult(Map<String, dynamic> map, String? email) => Order(
        id: J.str(map['order_id'], Uuid.v4()),
        status: OrderStatus.fromDb(J.strOrNull(map['status'])),
        subtotal: J.toDouble(map['subtotal'], subtotal),
        discountTotal: J.toDouble(map['discount_total'], discount),
        shippingTotal: J.toDouble(map['shipping_total'], shipping),
        grandTotal: J.toDouble(map['grand_total'], grandTotal),
        promoCode: appliedCode.value,
        contactEmail: email,
        createdAt: DateTime.now(),
        lines: _snapshotLines(),
      );

  Order _demoOrder(String? email) => Order(
        id: Uuid.v4(),
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
            unitPrice: c.unitPrice,
            quantity: c.quantity,
            lineTotal: c.lineTotal,
            category: c.category,
          ))
      .toList();

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------
  void _persist() {
    if (items.isEmpty) {
      Browser.remove(_storageKey);
      return;
    }
    try {
      Browser.write(
        _storageKey,
        jsonEncode({
          'items': items.map((e) => e.toJson()).toList(),
          'promo_code': appliedCode.value,
        }),
      );
    } catch (_) {
      // Persistence is best-effort and must never break a cart mutation.
    }
  }

  void _restore() {
    final raw = Browser.read(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final rawItems = decoded['items'];
      if (rawItems is! List) return;

      items.assignAll(rawItems
          .whereType<Map>()
          .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.variantItemId.isNotEmpty && e.quantity > 0));

      final code = J.strOrNull(decoded['promo_code']);
      if (code != null && code.isNotEmpty && items.isNotEmpty) {
        appliedCode.value = code;
        // Re-validate rather than trusting a persisted discount: prices, stock
        // and promo windows may all have moved on since the tab was closed.
        unawaited(_refreshPromo());
      }
    } catch (_) {
      Browser.remove(_storageKey);
    }
  }
}
