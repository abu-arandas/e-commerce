import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/admin_controller.dart';
import 'package:vanguard_fashion/models/order_model.dart';
import 'package:vanguard_fashion/models/product_model.dart';

/// `revenueByCategory` walks every line of every order, and the dashboard reads
/// it from inside an Obx, so it reruns on each rebuild. It is memoised, with
/// `ever()` workers clearing the cache when products or orders change.
///
/// These assert the memoisation is real and that it invalidates — a stale cache
/// would quietly report yesterday's revenue.
void main() {
  AdminController build({int products = 200, int orders = 200}) {
    final c = AdminController();
    c.onInit();
    c.products.clear();
    c.orders.clear();
    for (var i = 0; i < products; i++) {
      c.products.add(Product(
        id: 'p$i',
        slug: 'slug-$i',
        title: 'Product $i',
        category: 'Category ${i % 5}',
        basePrice: 10,
      ));
    }
    for (var i = 0; i < orders; i++) {
      c.orders.add(Order(
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
              productTitle: 'Product ${(i + j) % products}',
              sku: 'SKU',
              unitPrice: 10,
              quantity: 1,
              lineTotal: 10,
            ),
        ],
      ));
    }
    return c;
  }

  test('repeated reads return the memoised map, not a fresh computation', () {
    final c = build();

    final first = c.revenueByCategory;
    final second = c.revenueByCategory;

    // Identity, not equality: a recomputation would return a new map.
    expect(identical(first, second), isTrue);
  });

  test('adding an order invalidates the cache and changes the total', () {
    final c = build();
    final before = Map<String, double>.from(c.revenueByCategory);

    c.orders.add(const Order(
      id: 'extra',
      status: OrderStatus.paid,
      subtotal: 10,
      discountTotal: 0,
      shippingTotal: 0,
      grandTotal: 10,
      lines: [
        OrderLine(
          id: 'lx',
          productTitle: 'Product 0',
          sku: 'SKU',
          unitPrice: 10,
          quantity: 1,
          lineTotal: 10,
        ),
      ],
    ));

    final after = c.revenueByCategory;
    expect(identical(before, after), isFalse, reason: 'cache must be dropped');
    expect(after['Category 0'], greaterThan(before['Category 0'] ?? 0));
  });

  test('changing the catalogue invalidates it too', () {
    final c = build();
    final before = c.revenueByCategory;

    c.products.add(const Product(
        id: 'new', slug: 'new', title: 'Product 0', basePrice: 1));

    expect(identical(before, c.revenueByCategory), isFalse);
  });

  test('revenue is attributed to the right categories', () {
    final c = build(products: 5, orders: 0);
    c.orders.add(const Order(
      id: 'o',
      status: OrderStatus.paid,
      subtotal: 30,
      discountTotal: 0,
      shippingTotal: 0,
      grandTotal: 30,
      lines: [
        OrderLine(id: 'a', productTitle: 'Product 0', sku: 'S', unitPrice: 10, quantity: 1, lineTotal: 10),
        OrderLine(id: 'b', productTitle: 'Product 1', sku: 'S', unitPrice: 20, quantity: 1, lineTotal: 20),
      ],
    ));

    final revenue = c.revenueByCategory;
    expect(revenue['Category 0'], 10);
    expect(revenue['Category 1'], 20);
  });
}
