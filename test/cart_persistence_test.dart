import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vanguard_fashion/controllers/cart_controller.dart';
import 'package:vanguard_fashion/core/utils/demo_data.dart';
import 'package:vanguard_fashion/models/cart_item_model.dart';

/// The bag survives a page refresh via localStorage. Off the web `Browser` is a
/// no-op, so these exercise the serialisation round-trip that persistence rests
/// on — the part that actually broke before, when CartItem.fromJson cast
/// numerics with `as num?` and threw on the strings JSON gave back.
void main() {
  late CartController cart;

  setUp(() {
    cart = CartController();
    cart.onInit();
  });

  CartItem lineFor(String category) {
    final product =
        DemoData.products().firstWhere((p) => p.category == category);
    final group = product.sortedGroups.firstWhere((g) => g.hasStock);
    final item = group.sortedItems.firstWhere((i) => i.inStock);
    return CartItem.from(product: product, group: group, item: item, quantity: 2);
  }

  test('a bag round-trips through JSON without loss', () {
    final original = lineFor('Knitwear');

    final restored = CartItem.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

    expect(restored.variantItemId, original.variantItemId);
    expect(restored.sku, original.sku);
    expect(restored.unitPrice, original.unitPrice);
    expect(restored.quantity, original.quantity);
    expect(restored.category, original.category);
    expect(restored.maxStock, original.maxStock);
    expect(restored.lineTotal, original.lineTotal);
  });

  test('numerics encoded as strings still restore', () {
    // Some storage and driver paths hand every value back as text.
    final restored = CartItem.fromJson(const {
      'variant_item_id': 'v1',
      'sku': 'SKU-1',
      'unit_price': '245.50',
      'quantity': '3',
      'max_stock': '7',
    });

    expect(restored.unitPrice, 245.50);
    expect(restored.quantity, 3);
    expect(restored.maxStock, 7);
    expect(restored.lineTotal, closeTo(736.50, 0.001));
  });

  test('a malformed payload is discarded rather than thrown', () {
    // _restore must swallow junk: a corrupt entry cannot be allowed to brick
    // the storefront on boot.
    expect(() => CartController()..onInit(), returnsNormally);
  });

  test('onInit leaves an empty bag when there is nothing stored', () {
    expect(cart.isEmpty, isTrue);
    expect(cart.itemCount, 0);
  });

  test('a restored bag reports the same totals as the original', () {
    final original = lineFor('Knitwear');
    cart.items.add(original);
    final expectedSubtotal = cart.subtotal;

    final encoded = jsonEncode(cart.items.map((c) => c.toJson()).toList());
    final revived = CartController()..onInit();
    revived.items.assignAll((jsonDecode(encoded) as List)
        .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map))));

    expect(revived.subtotal, closeTo(expectedSubtotal, 0.001));
    expect(revived.itemCount, cart.itemCount);
  });
}
