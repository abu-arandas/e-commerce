import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/cart_controller.dart';
import 'package:vanguard_fashion/core/utils/demo_data.dart';

void main() {
  group('CartController - Promo Validation', () {
    late CartController cart;

    setUp(() {
      cart = CartController();
    });

    test('initial state', () {
      expect(cart.isEmpty, isTrue);
      expect(cart.appliedCode.value, isNull);
      expect(cart.appliedPromo.value, isNull);
    });

    test('applyPromo with empty code', () async {
      final success = await cart.applyPromo('   ');
      expect(success, isFalse);
      expect(cart.promoError.value, 'Enter a promo code');
      expect(cart.appliedCode.value, isNull);
    });

    test('applyPromo with invalid code', () async {
      final success = await cart.applyPromo('INVALID123');
      expect(success, isFalse);
      expect(cart.promoError.value, 'Code not found');
      expect(cart.appliedCode.value, isNull);
    });

    test('applyPromo with minimum order not met', () async {
      // The FALL20 promo requires $150 minimum order (DemoData.promotions)
      final success = await cart.applyPromo('FALL20');
      expect(success, isFalse);
      expect(cart.promoError.value, contains('Requires a minimum order'));
      expect(cart.appliedCode.value, isNull);
    });

    test('applyPromo with valid conditions applies discount', () async {
      final product = DemoData.products().first;
      final group = product.groups.first;
      final item = group.items.first;

      // Ensure price > $150 to meet FALL20 minimum
      cart.add(product: product, group: group, item: item, quantity: 1);
      if (cart.subtotal < 150) {
        cart.add(product: product, group: group, item: item, quantity: 10);
      }

      final success = await cart.applyPromo('FALL20');
      expect(success, isTrue);
      expect(cart.promoError.value, isEmpty);
      expect(cart.appliedCode.value, 'FALL20');
      expect(cart.appliedPromo.value, isNotNull);
      expect(cart.appliedPromo.value!.discountAmount, greaterThan(0));
      expect(cart.discount, cart.appliedPromo.value!.discountAmount);
    });

    test('clearPromo resets promo state', () async {
      final product = DemoData.products().first;
      cart.add(
          product: product,
          group: product.groups.first,
          item: product.groups.first.items.first,
          quantity: 5);

      await cart.applyPromo('FALL20');
      expect(cart.appliedCode.value, 'FALL20');

      cart.clearPromo();
      expect(cart.appliedCode.value, isNull);
      expect(cart.appliedPromo.value, isNull);
      expect(cart.promoError.value, isEmpty);
      expect(cart.discount, 0.0);
    });

    test('cart changes invalidate promo if conditions no longer apply',
        () async {
      final product = DemoData.products().first;
      final group = product.groups.first;
      final item = group.items.first;
      final key = item.id;

      cart.add(product: product, group: group, item: item, quantity: 5);

      // Fall20 minimum is $150
      final success = await cart.applyPromo('FALL20');
      expect(success, isTrue);
      expect(cart.appliedCode.value, 'FALL20');

      // Reduce quantity so subtotal drops below minimum order
      cart.updateQuantity(key, 0); // Remove all items

      // Needs to wait for the internal `_refreshPromo` Future to complete
      await Future.delayed(Duration.zero);

      expect(cart.appliedCode.value, isNull);
      expect(cart.appliedPromo.value, isNull);
    });
  });
}
