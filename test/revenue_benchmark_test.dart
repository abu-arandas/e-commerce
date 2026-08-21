import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vanguard_fashion/controllers/admin_controller.dart';
import 'package:vanguard_fashion/models/order_model.dart';
import 'package:vanguard_fashion/models/product_model.dart';

void main() {
  test('revenueByCategory benchmark', () {
    final controller = AdminController();

    // Create dummy products
    for (var i = 0; i < 1000; i++) {
      controller.products.add(Product(
        id: 'p$i',
        slug: 'slug-$i',
        title: 'Product $i',
        description: 'Description $i',
        category: 'Category ${i % 10}',
        isActive: true,
        isFeatured: false,
        basePrice: 10.0,
        groups: const [],
      ));
    }

    // Create dummy orders
    for (var i = 0; i < 5000; i++) {
      final lines = <OrderLine>[];
      for (var j = 0; j < 5; j++) {
        lines.add(OrderLine(
          id: 'l$i-$j',
          productTitle: 'Product ${(i + j) % 1000}',
          variantName: 'Var',
          sizeLabel: 'M',
          sku: 'SKU',
          unitPrice: 10,
          quantity: 1,
          lineTotal: 10,
        ));
      }
      controller.orders.add(Order(
        id: 'o$i',
        userId: 'u$i',
        status: OrderStatus.paid,
        subtotal: 50,
        discountTotal: 0,
        shippingTotal: 0,
        grandTotal: 50,
        lines: lines,
        createdAt: DateTime.now(),
      ));
    }

    // Benchmark
    final watch = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      final _ = controller.revenueByCategory;
    }
    watch.stop();
    print('Time taken for 100 accesses: ${watch.elapsedMilliseconds}ms');
  });
}
