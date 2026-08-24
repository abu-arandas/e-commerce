import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vanguard_fashion/controllers/auth_controller.dart';
import 'package:vanguard_fashion/controllers/catalog_controller.dart';
import 'package:vanguard_fashion/controllers/wishlist_controller.dart';
import 'package:vanguard_fashion/core/utils/demo_data.dart';
import 'package:vanguard_fashion/models/product_model.dart';
import 'package:vanguard_fashion/models/user_model.dart';

/// The saved ids are the source of truth. savedProducts used to be a filter
/// over the catalogue listing, which asks only for active rows — so taking a
/// piece off sale dropped it from the wishlist page while the header badge
/// still counted it.
void main() {
  late CatalogController catalog;
  late WishlistController wishlist;

  setUp(() async {
    Get.testMode = true;
    Get.put<AuthController>(AuthController());
    catalog = CatalogController();
    catalog.products.assignAll(DemoData.products());
    Get.put<CatalogController>(catalog);
    wishlist = WishlistController();
    Get.put<WishlistController>(wishlist);
    wishlist.onInit();
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(Get.reset);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('saving a piece resolves it to a product', () async {
    final product = catalog.products.first;
    await wishlist.toggle(product);
    await settle();

    expect(wishlist.count, 1);
    expect(wishlist.savedProducts.single.id, product.id);
    expect(wishlist.unavailableCount.value, 0);
  });

  test('the badge and the page agree when a piece leaves the catalogue', () async {
    final product = catalog.products.first;
    await wishlist.toggle(product);
    await settle();

    // The storefront listing drops it — deactivated, or simply not on this page.
    catalog.products.removeWhere((p) => p.id == product.id);
    await settle();

    // It is still saved, and still counted...
    expect(wishlist.count, 1);
    // ...and still resolvable, because demo lookup finds it outside the listing.
    expect(
      wishlist.savedProducts.length + wishlist.unavailableCount.value,
      wishlist.count,
      reason: 'shown + unavailable must always equal saved',
    );
  });

  test(
    'a saved id with no product anywhere is reported, not dropped silently',
    () async {
      wishlist.wishlistProductIds.add('00000000-0000-4000-8000-000000000000');
      await settle();

      expect(wishlist.count, 1);
      expect(wishlist.savedProducts, isEmpty);
      expect(
        wishlist.unavailableCount.value,
        1,
        reason: 'the difference is surfaced rather than hidden',
      );
    },
  );

  test('shown plus unavailable always equals the badge count', () async {
    for (final p in catalog.products.take(3)) {
      await wishlist.toggle(p);
    }
    wishlist.wishlistProductIds.add('11111111-2222-4333-8444-555555555555');
    await settle();

    expect(
      wishlist.savedProducts.length + wishlist.unavailableCount.value,
      wishlist.count,
    );
  });

  test('unsaving removes it from both the count and the page', () async {
    final product = catalog.products.first;
    await wishlist.toggle(product);
    await settle();
    expect(wishlist.count, 1);

    await wishlist.toggle(product);
    await settle();

    expect(wishlist.count, 0);
    expect(wishlist.savedProducts, isEmpty);
    expect(wishlist.isEmpty, isTrue);
  });

  test('isSaved tracks the saved set', () async {
    final Product product = catalog.products.first;
    expect(wishlist.isSaved(product.id), isFalse);

    await wishlist.toggle(product);
    expect(wishlist.isSaved(product.id), isTrue);
  });

  group('signing out', () {
    // The saved ids belong to the account that saved them. Leaving them behind
    // showed the next person to use this browser the previous shopper's
    // wishlist -- and fetchWishlist's `catch` would keep showing it even after
    // their own fetch failed.
    test(
      'empties the wishlist rather than just stopping the refresh',
      () async {
        final auth = Get.find<AuthController>();
        auth.user.value = const AppUser(
          id: 'shopper-1',
          email: 'a@example.test',
        );
        await settle();

        await wishlist.toggle(catalog.products.first);
        await settle();
        expect(wishlist.count, 1);
        expect(wishlist.savedProducts, isNotEmpty);

        auth.user.value = null;
        await settle();

        expect(
          wishlist.count,
          0,
          reason: 'the badge must not survive sign-out',
        );
        expect(wishlist.savedProducts, isEmpty);
        expect(wishlist.unavailableCount.value, 0);
      },
    );

    test(
      'the next account does not inherit the previous one\'s saves',
      () async {
        final auth = Get.find<AuthController>();
        auth.user.value = const AppUser(
          id: 'shopper-1',
          email: 'a@example.test',
        );
        await settle();
        await wishlist.toggle(catalog.products.first);
        await settle();
        expect(wishlist.count, 1);

        auth.user.value = null;
        await settle();
        auth.user.value = const AppUser(
          id: 'shopper-2',
          email: 'b@example.test',
        );
        await settle();

        expect(wishlist.count, 0);
        expect(wishlist.savedProducts, isEmpty);
      },
    );
  });
}
