import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vanguard_fashion/controllers/catalog_controller.dart';
import 'package:vanguard_fashion/core/utils/demo_data.dart';

/// Nested variant selection (PRD §3.1): picking a colour must refresh the
/// available sizes, price, and stock for that colour.
void main() {
  late CatalogController catalog;

  setUp(() {
    catalog = CatalogController();
    catalog.products.assignAll(DemoData.products());
  });

  group('loading', () {
    test('seeds the first colour and an in-stock size', () async {
      final product = await catalog.loadProduct('cashmere-turtleneck');

      expect(product, isNotNull);
      expect(catalog.selectedGroup.value, isNotNull);
      expect(catalog.selectedItem.value, isNotNull);
      expect(catalog.selectedItem.value!.inStock, isTrue);
      expect(catalog.canAddToCart, isTrue);
    });

    test('honours a deep-linked colour', () async {
      await catalog.loadProduct(
        'cashmere-turtleneck',
        preselectColorSlug: 'crimson',
      );

      expect(catalog.selectedGroup.value!.name, 'Crimson');
    });

    test('falls back to the first colour for an unknown slug', () async {
      await catalog.loadProduct(
        'cashmere-turtleneck',
        preselectColorSlug: 'not-a-colour',
      );

      expect(catalog.selectedGroup.value!.name, 'Midnight Blue');
    });

    test('switching product replaces the entire selection', () async {
      await catalog.loadProduct('cashmere-turtleneck');
      final previousGroupId = catalog.selectedGroup.value!.id;

      await catalog.loadProduct('silk-slip-dress');

      expect(catalog.selected.value!.slug, 'silk-slip-dress');
      expect(catalog.selectedGroup.value!.id, isNot(previousGroupId));
      // The selected size must belong to the newly selected colour, not to a
      // leftover group from the previous product.
      expect(
        catalog.selectedItem.value!.groupId,
        catalog.selectedGroup.value!.id,
      );
    });

    test(
      'a missing slug clears the previous product rather than leaving it',
      () async {
        await catalog.loadProduct('cashmere-turtleneck');
        expect(catalog.selected.value, isNotNull);

        expect(await catalog.loadProduct('no-such-piece'), isNull);

        // All three must clear together; a stale group/size behind a null product
        // is what made the page render the wrong item.
        expect(catalog.selected.value, isNull);
        expect(catalog.selectedGroup.value, isNull);
        expect(catalog.selectedItem.value, isNull);
      },
    );
  });

  group('colour selection', () {
    test('switching colour swaps in that colour\'s sizes', () async {
      await catalog.loadProduct('cashmere-turtleneck');

      final oatmeal = catalog.selected.value!.groupBySlug('oatmeal')!;
      catalog.selectGroup(oatmeal);

      expect(catalog.availableSizes.map((i) => i.sizeLabel), ['M', 'L']);
      expect(
        catalog.availableSizes.every((i) => i.groupId == oatmeal.id),
        isTrue,
      );
    });

    test('switching colour resets quantity and gallery position', () async {
      await catalog.loadProduct('cashmere-turtleneck');
      catalog.incrementQty();
      catalog.setActiveImage(1);

      catalog.selectGroup(catalog.selected.value!.groupBySlug('crimson')!);

      expect(catalog.quantity.value, 1);
      expect(catalog.activeImage.value, 0);
    });

    test('skips sold-out sizes when auto-selecting', () async {
      await catalog.loadProduct('cashmere-turtleneck');

      // Midnight Blue XL is sold out and must not be the default pick.
      expect(catalog.selectedItem.value!.inStock, isTrue);
    });
  });

  group('derived pricing', () {
    test('uses the size-level price override when present', () async {
      await catalog.loadProduct('cashmere-turtleneck');
      final blue = catalog.selected.value!.groupBySlug('midnight-blue')!;
      catalog.selectGroup(blue);

      final xl = blue.items.firstWhere((i) => i.sizeLabel == 'XL');
      catalog.selectSize(xl);

      expect(xl.priceOverride, 255);
      expect(catalog.currentUnitPrice, 255);
    });

    test('falls back to the product base price', () async {
      await catalog.loadProduct('cashmere-turtleneck');
      final blue = catalog.selected.value!.groupBySlug('midnight-blue')!;
      catalog.selectGroup(blue);
      catalog.selectSize(blue.items.firstWhere((i) => i.sizeLabel == 'M'));

      expect(catalog.currentUnitPrice, 245);
    });

    test('quantity cannot exceed the selected size\'s stock', () async {
      await catalog.loadProduct('cashmere-turtleneck');
      final blue = catalog.selected.value!.groupBySlug('midnight-blue')!;
      catalog.selectGroup(blue);
      final large = blue.items.firstWhere(
        (i) => i.sizeLabel == 'L',
      ); // 3 in stock
      catalog.selectSize(large);

      for (var i = 0; i < 10; i++) {
        catalog.incrementQty();
      }

      expect(catalog.quantity.value, large.stockQuantity);
    });

    test('a sold-out selection cannot be added to the bag', () async {
      await catalog.loadProduct('cashmere-turtleneck');
      final blue = catalog.selected.value!.groupBySlug('midnight-blue')!;
      catalog.selectGroup(blue);
      catalog.selectSize(blue.items.firstWhere((i) => i.sizeLabel == 'XL'));

      expect(catalog.currentStock, 0);
      expect(catalog.canAddToCart, isFalse);
    });
  });

  group('listing', () {
    test('filters by category', () {
      catalog.setCategory('Knitwear');

      expect(catalog.visibleProducts, isNotEmpty);
      expect(
        catalog.visibleProducts.every((p) => p.category == 'Knitwear'),
        isTrue,
      );
    });

    test('searches title, category and description', () {
      catalog.setSearch('cashmere');
      expect(catalog.visibleProducts, isNotEmpty);

      catalog.setSearch('zzzzz-no-match');
      expect(catalog.visibleProducts, isEmpty);
    });

    test('sorts by price ascending and descending', () {
      catalog.setSort('price_asc');
      final ascending = catalog.visibleProducts
          .map((p) => p.fromPrice)
          .toList();
      expect(ascending, orderedEquals(List.of(ascending)..sort()));

      catalog.setSort('price_desc');
      final descending = catalog.visibleProducts
          .map((p) => p.fromPrice)
          .toList();
      expect(descending.first, greaterThanOrEqualTo(descending.last));
    });
  });
}
