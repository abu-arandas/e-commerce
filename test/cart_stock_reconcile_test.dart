import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vanguard_fashion/controllers/cart_controller.dart';
import 'package:vanguard_fashion/controllers/catalog_controller.dart';
import 'package:vanguard_fashion/core/utils/demo_data.dart';
import 'package:vanguard_fashion/models/cart_item_model.dart';
import 'package:vanguard_fashion/models/product_model.dart';

/// A restored bag carries the stock figures from whenever it was saved. If a
/// SKU sold out in another session in between, the line used to survive all the
/// way to checkout and fail there; now it is reconciled against the live
/// catalogue as that catalogue arrives.
void main() {
  late CatalogController catalog;

  /// The demo catalogue with one SKU's stock forced to [stock].
  List<Product> catalogueWith(String variantItemId, int stock) =>
      DemoData.products()
          .map(
            (p) => p.copyWith(
              groups: p.groups
                  .map(
                    (g) => g.copyWith(
                      items: g.items
                          .map(
                            (i) => i.id == variantItemId
                                ? i.copyWith(stockQuantity: stock)
                                : i,
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList();

  CartItem lineFor({int quantity = 2}) {
    final product = DemoData.products().firstWhere((p) => p.category != null);
    final group = product.sortedGroups.firstWhere((g) => g.hasStock);
    final item = group.sortedItems.firstWhere((i) => i.inStock);
    return CartItem.from(
      product: product,
      group: group,
      item: item,
      quantity: quantity,
    );
  }

  setUp(() {
    Get.testMode = true;
    catalog = CatalogController();
    Get.put<CatalogController>(catalog);
  });

  tearDown(Get.reset);

  CartController cartHolding(CartItem line) {
    final cart = CartController();
    Get.put<CartController>(cart);
    cart.onInit();
    cart.items.assignAll([line]);
    return cart;
  }

  test('a quantity above live stock is clamped down to it', () async {
    final line = lineFor(quantity: 5);
    final cart = cartHolding(line);

    catalog.products.assignAll(catalogueWith(line.variantItemId, 2));
    await Future<void>.delayed(Duration.zero);

    expect(cart.items.single.quantity, 2);
    expect(cart.items.single.maxStock, 2);
  });

  test('a line whose SKU sold out entirely is dropped', () async {
    final line = lineFor();
    final cart = cartHolding(line);

    catalog.products.assignAll(catalogueWith(line.variantItemId, 0));
    await Future<void>.delayed(Duration.zero);

    expect(cart.items, isEmpty);
  });

  test('a quantity within stock is left alone', () async {
    final line = lineFor(quantity: 1);
    final cart = cartHolding(line);

    catalog.products.assignAll(catalogueWith(line.variantItemId, 9));
    await Future<void>.delayed(Duration.zero);

    expect(cart.items.single.quantity, 1);
  });

  test(
    'an empty catalogue means "not loaded", not "everything is gone"',
    () async {
      final line = lineFor(quantity: 3);
      final cart = cartHolding(line);

      catalog.products.clear();
      await Future<void>.delayed(Duration.zero);

      expect(cart.items.single.quantity, 3);
    },
  );

  test('the cart still works with no catalogue registered at all', () {
    Get.delete<CatalogController>();
    final cart = CartController();
    // The constructor and onInit must not reach for something optional.
    expect(cart.onInit, returnsNormally);
  });
}
