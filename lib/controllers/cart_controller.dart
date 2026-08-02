
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../core/utils/app_constants.dart';
import '../core/utils/demo_data.dart';
import '../core/utils/env.dart';
import '../core/utils/supabase_service.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/promotion_model.dart';
import '../models/variant_model.dart';

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

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------
  void add({
    required Product product,
    required VariantGroup group,
    required VariantItem item,
    int quantity = 1,
  }) {
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

  double get discount => appliedPromo.value?.valid == true
      ? appliedPromo.value!.discountAmount
      : 0;

  bool get hasFreeShipping =>
      appliedPromo.value?.freeShipping == true ||
      subtotal >= Env.freeShippingThreshold;

  double get baseShipping {
    if (isEmpty) return 0;
    return subtotal >= Env.freeShippingThreshold ? 0 : Env.flatShippingFee;
  }

  double get shipping => hasFreeShipping ? 0 : baseShipping;

  double get grandTotal {
    final total = subtotal - discount + shipping;
    return total < 0 ? 0 : total;
  }

  double get amountToFreeShipping {
    final remaining = Env.freeShippingThreshold - subtotal;
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
      appliedPromo.value = null;
      promoError.value = result.reason ?? 'Promo no longer applies';
    }
  }

  Future<PromoValidation> _validate(String code) async {
    if (SupabaseService.isReady) {
      try {
        final res = await SupabaseService.client.rpc(
          AppConstants.rpcValidatePromotion,
          params: {
            'p_code': code,
            'p_subtotal': subtotal,
            'p_categories': categories,
          },
        );
        return PromoValidation.fromJson(Map<String, dynamic>.from(res as Map));
      } catch (e) {
        return PromoValidation.invalid('Validation failed: $e');
      }
    }
    return DemoData.validatePromo(code, subtotal, categories);
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
          params: {
            'p_items': items.map((e) => e.toOrderLine()).toList(),
            'p_promo_code': appliedCode.value,
            'p_shipping_address': shippingAddress,
            'p_contact_email': contactEmail,
            'p_flat_shipping': baseShipping,
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
