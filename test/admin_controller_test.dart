import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/admin_controller.dart';
import 'package:vanguard_fashion/models/order_model.dart';
import 'package:vanguard_fashion/models/product_model.dart';
import 'package:vanguard_fashion/models/variant_model.dart';

void main() {
  test('totalSkus calculation works and updates with cached value', () async {
    final controller = AdminController();

    // Create mock products with variants
    final items1 = List.generate(
      2,
      (i) => VariantItem(
        id: '$i',
        groupId: 'g1',
        sku: 's1-$i',
        sizeLabel: 'M',
        stockQuantity: 10,
        sortOrder: i,
      ),
    );
    final groups1 = [
      VariantGroup(
        id: 'g1',
        productId: 'p1',
        name: 'Color',
        sortOrder: 0,
        items: items1,
      ),
    ];
    final product1 = Product(
      id: 'p1',
      slug: 'slug-1',
      title: 'Product 1',
      basePrice: 10,
      isActive: true,
      groups: groups1,
    );

    final items2 = List.generate(
      3,
      (i) => VariantItem(
        id: '$i',
        groupId: 'g2',
        sku: 's2-$i',
        sizeLabel: 'L',
        stockQuantity: 5,
        sortOrder: i,
      ),
    );
    final groups2 = [
      VariantGroup(
        id: 'g2',
        productId: 'p2',
        name: 'Size',
        sortOrder: 0,
        items: items2,
      ),
    ];
    final product2 = Product(
      id: 'p2',
      slug: 'slug-2',
      title: 'Product 2',
      basePrice: 20,
      isActive: true,
      groups: groups2,
    );

    controller.onInit();
    await controller.refreshAll();

    // Clear demo data
    controller.products.clear();

    // Initially empty
    expect(controller.totalSkus, 0);

    // Add first product (2 SKUs)
    controller.products.add(product1);
    expect(controller.totalSkus, 2);

    // Add second product (3 SKUs) -> total 5
    controller.products.add(product2);
    expect(controller.totalSkus, 5);

    // Remove first product -> total 3
    controller.products.removeAt(0);
    expect(controller.totalSkus, 3);
  });

  group('AdminController Revenue and Order Analytics', () {
    late AdminController controller;

    setUp(() {
      controller = AdminController();
    });

    test('pendingOrders counts only pending and paid orders', () {
      controller.orders.value = const [
        Order(
          id: '1',
          status: OrderStatus.pending,
          subtotal: 10,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 10,
        ),
        Order(
          id: '2',
          status: OrderStatus.paid,
          subtotal: 10,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 10,
        ),
        Order(
          id: '3',
          status: OrderStatus.processing,
          subtotal: 10,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 10,
        ),
        Order(
          id: '4',
          status: OrderStatus.shipped,
          subtotal: 10,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 10,
        ),
        Order(
          id: '5',
          status: OrderStatus.delivered,
          subtotal: 10,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 10,
        ),
        Order(
          id: '6',
          status: OrderStatus.cancelled,
          subtotal: 10,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 10,
        ),
        Order(
          id: '7',
          status: OrderStatus.refunded,
          subtotal: 10,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 10,
        ),
      ];

      expect(controller.pendingOrders, 2);
    });

    test('grossRevenue excludes cancelled and refunded orders', () {
      controller.orders.value = const [
        Order(
          id: '1',
          status: OrderStatus.delivered,
          subtotal: 100,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 100,
        ),
        Order(
          id: '2',
          status: OrderStatus.processing,
          subtotal: 50,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 50,
        ),
        Order(
          id: '3',
          status: OrderStatus.cancelled,
          subtotal: 200,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 200,
        ),
        Order(
          id: '4',
          status: OrderStatus.refunded,
          subtotal: 150,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 150,
        ),
      ];

      // 100 + 50 = 150
      expect(controller.grossRevenue, 150.0);
    });

    test('grossRevenue calculates correctly with no orders', () {
      controller.orders.value = [];
      expect(controller.grossRevenue, 0.0);
    });

    test('averageOrderValue calculates correctly', () {
      controller.orders.value = const [
        Order(
          id: '1',
          status: OrderStatus.delivered,
          subtotal: 100,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 100,
        ),
        Order(
          id: '2',
          status: OrderStatus.processing,
          subtotal: 50,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 50,
        ),
        Order(
          id: '3',
          status: OrderStatus.shipped,
          subtotal: 30,
          discountTotal: 0,
          shippingTotal: 0,
          grandTotal: 30,
        ),
      ];

      // grossRevenue = 100 + 50 + 30 = 180
      // 180 / 3 = 60
      expect(controller.averageOrderValue, 60.0);
    });

    test('averageOrderValue handles zero orders safely', () {
      controller.orders.value = [];

      expect(controller.averageOrderValue, 0.0);
    });
  });
}
