import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/admin_controller.dart';
import 'package:vanguard_fashion/models/order_model.dart';

void main() {
  group('AdminController Revenue and Order Analytics', () {
    late AdminController controller;

    setUp(() {
      controller = AdminController();
    });

    test('pendingOrders counts only pending and paid orders', () {
      controller.orders.value = const [
        Order(id: '1', status: OrderStatus.pending, subtotal: 10, discountTotal: 0, shippingTotal: 0, grandTotal: 10),
        Order(id: '2', status: OrderStatus.paid, subtotal: 10, discountTotal: 0, shippingTotal: 0, grandTotal: 10),
        Order(id: '3', status: OrderStatus.processing, subtotal: 10, discountTotal: 0, shippingTotal: 0, grandTotal: 10),
        Order(id: '4', status: OrderStatus.shipped, subtotal: 10, discountTotal: 0, shippingTotal: 0, grandTotal: 10),
        Order(id: '5', status: OrderStatus.delivered, subtotal: 10, discountTotal: 0, shippingTotal: 0, grandTotal: 10),
        Order(id: '6', status: OrderStatus.cancelled, subtotal: 10, discountTotal: 0, shippingTotal: 0, grandTotal: 10),
        Order(id: '7', status: OrderStatus.refunded, subtotal: 10, discountTotal: 0, shippingTotal: 0, grandTotal: 10),
      ];

      expect(controller.pendingOrders, 2);
    });

    test('grossRevenue excludes cancelled and refunded orders', () {
      controller.orders.value = const [
        Order(id: '1', status: OrderStatus.delivered, subtotal: 100, discountTotal: 0, shippingTotal: 0, grandTotal: 100),
        Order(id: '2', status: OrderStatus.processing, subtotal: 50, discountTotal: 0, shippingTotal: 0, grandTotal: 50),
        Order(id: '3', status: OrderStatus.cancelled, subtotal: 200, discountTotal: 0, shippingTotal: 0, grandTotal: 200),
        Order(id: '4', status: OrderStatus.refunded, subtotal: 150, discountTotal: 0, shippingTotal: 0, grandTotal: 150),
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
        Order(id: '1', status: OrderStatus.delivered, subtotal: 100, discountTotal: 0, shippingTotal: 0, grandTotal: 100),
        Order(id: '2', status: OrderStatus.processing, subtotal: 50, discountTotal: 0, shippingTotal: 0, grandTotal: 50),
        Order(id: '3', status: OrderStatus.shipped, subtotal: 30, discountTotal: 0, shippingTotal: 0, grandTotal: 30),
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
