import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/admin_controller.dart';

/// deleteProduct/deletePromotion used to return void and throw on a remote
/// failure. The only caller invoked them fire-and-forget, so the throw became
/// an unhandled async error: the dialog closed, nothing was said, and the row
/// was still there after a refresh. They report the outcome now.
void main() {
  late AdminController admin;

  setUp(() {
    admin = AdminController();
    admin.onInit();
    admin.error.value = '';
  });

  test('deleting a product reports success and removes it', () async {
    final target = admin.products.first;
    final before = admin.products.length;

    final removed = await admin.deleteProduct(target.id);

    expect(removed, isTrue);
    expect(admin.products.length, before - 1);
    expect(admin.products.any((p) => p.id == target.id), isFalse);
    expect(admin.error.value, isEmpty);
  });

  test('deleting a promotion reports success and removes it', () async {
    final target = admin.promotions.first;
    final before = admin.promotions.length;

    final removed = await admin.deletePromotion(target.id);

    expect(removed, isTrue);
    expect(admin.promotions.length, before - 1);
    expect(admin.error.value, isEmpty);
  });

  test('deleting an unknown id is a no-op rather than an error', () async {
    final before = admin.products.length;

    final removed = await admin.deleteProduct('no-such-product');

    expect(removed, isTrue);
    expect(admin.products.length, before);
  });

  test('the SKU cache follows a deletion', () async {
    final target = admin.products.firstWhere((p) => p.allItems.isNotEmpty);
    final skusBefore = admin.totalSkus;

    await admin.deleteProduct(target.id);

    expect(
      admin.totalSkus,
      skusBefore - target.allItems.length,
      reason: 'the cached count must drop with the product',
    );
  });

  test('low-stock alerts drop the deleted product too', () async {
    final target = admin.products.firstWhere(
      (p) => p.allItems.any((i) => i.stockQuantity <= i.lowStockThreshold),
    );

    await admin.deleteProduct(target.id);

    expect(admin.lowStock.any((e) => e.productTitle == target.title), isFalse);
  });
}
