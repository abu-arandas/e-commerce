import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/cart_controller.dart';
import 'package:vanguard_fashion/models/cart_item_model.dart';
import 'package:vanguard_fashion/models/promotion_model.dart';
import 'package:vanguard_fashion/core/utils/env.dart';

void main() {
  group('CartController Totals Tests', () {
    late CartController cartController;

    setUp(() {
      cartController = CartController();
    });

    CartItem createCartItem({
      required String id,
      String? category,
      double unitPrice = 10.0,
      int quantity = 1,
    }) {
      return CartItem(
        productId: 'prod_$id',
        productSlug: 'slug_$id',
        productTitle: 'Title $id',
        category: category,
        variantGroupId: 'group_$id',
        variantItemId: 'item_$id',
        sku: 'SKU_$id',
        colorName: 'Color $id',
        sizeLabel: 'Size $id',
        unitPrice: unitPrice,
        quantity: quantity,
      );
    }

    test('itemCount correctly sums up quantities', () {
      expect(cartController.itemCount, 0);
      cartController.items.add(createCartItem(id: '1', quantity: 2));
      cartController.items.add(createCartItem(id: '2', quantity: 3));
      expect(cartController.itemCount, 5);
    });

    test('isEmpty is true when items is empty, false otherwise', () {
      expect(cartController.isEmpty, isTrue);
      cartController.items.add(createCartItem(id: '1'));
      expect(cartController.isEmpty, isFalse);
    });

    test('subtotal correctly calculates sum of lineTotal', () {
      expect(cartController.subtotal, 0.0);
      cartController.items.add(createCartItem(id: '1', unitPrice: 10.0, quantity: 2)); // 20.0
      cartController.items.add(createCartItem(id: '2', unitPrice: 15.0, quantity: 1)); // 15.0
      expect(cartController.subtotal, 35.0);
    });

    test('categories correctly extracts distinct categories', () {
      expect(cartController.categories, isEmpty);
      cartController.items.add(createCartItem(id: '1', category: 'Shirts'));
      cartController.items.add(createCartItem(id: '2', category: 'Pants'));
      cartController.items.add(createCartItem(id: '3', category: 'Shirts'));
      cartController.items.add(createCartItem(id: '4', category: null)); // Should be ignored
      expect(cartController.categories, unorderedEquals(['Shirts', 'Pants']));
    });

    test('discount reflects applied promo discount Amount, 0 if invalid or none', () {
      expect(cartController.discount, 0.0);

      cartController.appliedPromo.value = PromoValidation(valid: true, discountAmount: 15.0);
      expect(cartController.discount, 15.0);

      cartController.appliedPromo.value = PromoValidation.invalid('Expired');
      expect(cartController.discount, 0.0);
    });

    test('hasFreeShipping resolves true based on subtotal or promo', () {
      expect(cartController.hasFreeShipping, isFalse); // Empty cart, subtotal 0

      // Promo gives free shipping
      cartController.appliedPromo.value = PromoValidation(valid: true, freeShipping: true);
      expect(cartController.hasFreeShipping, isTrue);

      cartController.appliedPromo.value = null;

      // Subtotal reaches threshold
      cartController.items.add(createCartItem(id: '1', unitPrice: Env.freeShippingThreshold, quantity: 1));
      expect(cartController.hasFreeShipping, isTrue);
    });

    test('baseShipping calculates correctly', () {
      expect(cartController.baseShipping, 0.0); // Empty cart

      cartController.items.add(createCartItem(id: '1', unitPrice: 50.0));
      expect(cartController.baseShipping, Env.flatShippingFee); // Subtotal < threshold

      cartController.items.add(createCartItem(id: '2', unitPrice: Env.freeShippingThreshold));
      expect(cartController.baseShipping, 0.0); // Subtotal >= threshold
    });

    test('shipping applies 0 when hasFreeShipping is true, else baseShipping', () {
      // Setup subtotal < threshold
      cartController.items.add(createCartItem(id: '1', unitPrice: 50.0));
      expect(cartController.shipping, Env.flatShippingFee);

      // Apply free shipping promo
      cartController.appliedPromo.value = PromoValidation(valid: true, freeShipping: true);
      expect(cartController.shipping, 0.0);
    });

    test('grandTotal calculates subtotal - discount + shipping and avoids negative', () {
      // Setup subtotal 50, shipping is Env.flatShippingFee
      cartController.items.add(createCartItem(id: '1', unitPrice: 50.0));
      expect(cartController.grandTotal, 50.0 + Env.flatShippingFee);

      // Apply discount
      cartController.appliedPromo.value = PromoValidation(valid: true, discountAmount: 10.0);
      expect(cartController.grandTotal, 40.0 + Env.flatShippingFee);

      // Apply huge discount
      cartController.appliedPromo.value = PromoValidation(valid: true, discountAmount: 100.0);
      expect(cartController.grandTotal, 0.0);
    });

    test('amountToFreeShipping calculates remaining amount to threshold', () {
      expect(cartController.amountToFreeShipping, Env.freeShippingThreshold);

      cartController.items.add(createCartItem(id: '1', unitPrice: Env.freeShippingThreshold - 20));
      expect(cartController.amountToFreeShipping, 20.0);

      cartController.items.add(createCartItem(id: '2', unitPrice: 30.0));
      expect(cartController.amountToFreeShipping, 0.0);
    });
  });
}
