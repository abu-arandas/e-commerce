import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/admin_controller.dart';
import 'package:vanguard_fashion/models/order_model.dart';
import 'package:vanguard_fashion/models/product_model.dart';

/// Guards the complexity of the dashboard aggregates rather than their wall
/// time, so it does not flake on a loaded machine.
///
/// `totalSkus` and `revenueByCategory` are both cached. If either regresses to
/// recomputing on every read, the work grows with the catalogue on every Obx
/// rebuild — which is what made the dashboard crawl before they were memoised.
void main() {
  test('repeated aggregate reads do no work proportional to the catalogue', () {
    final c = AdminController();
    c.onInit();
    c.products.clear();
    c.orders.clear();

    for (var i = 0; i < 500; i++) {
      c.products.add(
        Product(
          id: 'p$i',
          slug: 'slug-$i',
          title: 'Product $i',
          category: 'Category ${i % 5}',
          basePrice: 10,
        ),
      );
    }
    for (var i = 0; i < 500; i++) {
      c.orders.add(
        Order(
          id: 'o$i',
          status: OrderStatus.paid,
          subtotal: 50,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 50,
          lines: [
            for (var j = 0; j < 5; j++)
              OrderLine(
                id: 'l$i-$j',
                productTitle: 'Product ${(i + j) % 500}',
                sku: 'SKU',
                unitPrice: 10,
                quantity: 1,
                lineTotal: 10,
              ),
          ],
        ),
      );
    }

    final firstRevenue = c.revenueByCategory;
    final firstSkus = c.totalSkus;

    // 200 further reads must all be served from cache: same map instance every
    // time, and a stable SKU count.
    for (var i = 0; i < 200; i++) {
      expect(identical(c.revenueByCategory, firstRevenue), isTrue);
      expect(c.totalSkus, firstSkus);
    }
  });
}
