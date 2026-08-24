import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/cart_controller.dart';
import 'package:vanguard_fashion/core/utils/demo_data.dart';
import 'package:vanguard_fashion/core/utils/env.dart';
import 'package:vanguard_fashion/core/utils/store_settings.dart';
import 'package:vanguard_fashion/models/product_model.dart';

/// Lets pending promo re-validation (fired unawaited on every cart change)
/// settle before assertions.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late CartController cart;
  late Product knitwear;
  late Product trousers;

  setUp(() {
    cart = CartController();
    final products = DemoData.products();
    knitwear = products.firstWhere((p) => p.category == 'Knitwear');
    trousers = products.firstWhere((p) => p.category == 'Trousers');
    StoreSettings.flatShippingFee.value = Env.flatShippingFee;
    StoreSettings.freeShippingThreshold.value = Env.freeShippingThreshold;
  });

  void addFirstInStock(Product product, {int quantity = 1}) {
    final group = product.sortedGroups.firstWhere((g) => g.hasStock);
    final item = group.sortedItems.firstWhere((i) => i.inStock);
    cart.add(product: product, group: group, item: item, quantity: quantity);
  }

  group('line management', () {
    test('adding the same SKU twice stacks rather than duplicating', () {
      addFirstInStock(knitwear);
      addFirstInStock(knitwear);

      expect(cart.items.length, 1);
      expect(cart.itemCount, 2);
    });

    test('quantity is clamped to available stock', () {
      final group = knitwear.sortedGroups.firstWhere((g) => g.hasStock);
      final item = group.sortedItems.firstWhere((i) => i.inStock);

      cart.add(
        product: knitwear,
        group: group,
        item: item,
        quantity: item.stockQuantity + 50,
      );

      expect(cart.items.single.quantity, item.stockQuantity);
    });

    test('a sold-out variant cannot be added', () {
      final group = knitwear.sortedGroups.firstWhere(
        (g) => g.items.any((i) => !i.inStock),
      );
      final soldOut = group.items.firstWhere((i) => !i.inStock);

      cart.add(product: knitwear, group: group, item: soldOut);

      expect(cart.isEmpty, isTrue);
    });

    test('decrementing to zero removes the line', () {
      addFirstInStock(knitwear);
      cart.decrement(cart.items.single.key);

      expect(cart.isEmpty, isTrue);
    });
  });

  group('totals', () {
    test('subtotal is the sum of line totals', () {
      addFirstInStock(knitwear, quantity: 2);
      final unit = cart.items.single.unitPrice;

      expect(cart.subtotal, closeTo(unit * 2, 0.001));
    });

    test('shipping is free at or above the threshold', () {
      addFirstInStock(knitwear); // 245, over the 150 default

      expect(cart.subtotal, greaterThanOrEqualTo(150));
      expect(cart.shipping, 0);
      expect(cart.grandTotal, closeTo(cart.subtotal, 0.001));
    });

    test('the flat fee applies below the threshold', () {
      StoreSettings.freeShippingThreshold.value = 5000;
      addFirstInStock(knitwear);

      expect(cart.shipping, StoreSettings.flatShippingFee.value);
      expect(
        cart.grandTotal,
        closeTo(cart.subtotal + StoreSettings.flatShippingFee.value, 0.001),
      );
    });

    test('an empty bag is charged nothing', () {
      expect(cart.subtotal, 0);
      expect(cart.shipping, 0);
      expect(cart.grandTotal, 0);
    });
  });

  group('promotions', () {
    test('a category-targeted code discounts only its own lines', () async {
      addFirstInStock(knitwear); // 245 Knitwear
      addFirstInStock(trousers); // 189 Trousers
      await settle();

      final applied = await cart.applyPromo('KNIT25');

      expect(applied, isTrue);
      expect(cart.discount, closeTo(61.25, 0.001));
      expect(cart.grandTotal, closeTo(cart.subtotal - 61.25, 0.001));
    });

    test('a free-shipping code zeroes shipping below the threshold', () async {
      StoreSettings.freeShippingThreshold.value = 5000;
      addFirstInStock(knitwear);
      await settle();

      await cart.applyPromo('FREESHIP');

      expect(cart.hasFreeShipping, isTrue);
      expect(cart.shipping, 0);
    });

    test('an invalid code is reported and not applied', () async {
      addFirstInStock(knitwear);
      await settle();

      final applied = await cart.applyPromo('DEFINITELY-NOT-A-CODE');

      expect(applied, isFalse);
      expect(cart.appliedCode.value, isNull);
      expect(cart.discount, 0);
      expect(cart.promoError.value, isNotEmpty);
    });

    test('an empty code is rejected without a lookup', () async {
      expect(await cart.applyPromo('   '), isFalse);
      expect(cart.promoError.value, 'Enter a promo code');
    });

    test(
      'a code that stops qualifying is dropped entirely, code included',
      () async {
        // FALL20 needs a 150 minimum. Qualify, then fall below it.
        addFirstInStock(knitwear);
        await settle();
        expect(await cart.applyPromo('FALL20'), isTrue);

        cart.removeItem(cart.items.single.key);
        await settle();

        // Both must clear: a lingering code would be sent to `place_order`,
        // which rejects invalid promotions and fails the whole checkout.
        expect(cart.discount, 0);
        expect(cart.appliedCode.value, isNull);
      },
    );

    test('clearing the bag clears the promotion', () async {
      addFirstInStock(knitwear);
      await settle();
      await cart.applyPromo('FALL20');

      cart.clear();

      expect(cart.appliedCode.value, isNull);
      expect(cart.discount, 0);
    });
  });

  group('checkout payload', () {
    test('order lines carry only the SKU and quantity', () {
      addFirstInStock(knitwear, quantity: 2);

      final line = cart.items.single.toOrderLine();

      // Price is deliberately absent — the server recomputes it.
      expect(line.keys, containsAll(<String>['variant_item_id', 'quantity']));
      expect(line.length, 2);
      expect(line['quantity'], 2);
    });

    test('promo lines carry per-line categories and totals', () {
      addFirstInStock(knitwear);
      addFirstInStock(trousers);

      final lines = cart.promoLines;

      expect(lines.length, 2);
      expect(
        lines.map((l) => l.category),
        containsAll(['Knitwear', 'Trousers']),
      );
      expect(
        lines.fold<double>(0, (s, l) => s + l.lineTotal),
        closeTo(cart.subtotal, 0.001),
      );
    });

    test('a demo order snapshots the bag and empties it', () async {
      addFirstInStock(knitwear, quantity: 2);
      await settle();

      final order = await cart.placeOrder(contactEmail: 'shopper@example.com');

      expect(order, isNotNull);
      expect(order!.lines.single.quantity, 2);
      expect(order.lines.single.category, 'Knitwear');
      expect(order.grandTotal, greaterThan(0));
      expect(cart.isEmpty, isTrue, reason: 'the bag is emptied after checkout');
    });
  });
}
