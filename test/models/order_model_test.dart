import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/models/order_model.dart';

void main() {
  group('OrderStatus', () {
    test('fromDb parses valid status strings correctly', () {
      expect(OrderStatus.fromDb('pending'), OrderStatus.pending);
      expect(OrderStatus.fromDb('paid'), OrderStatus.paid);
      expect(OrderStatus.fromDb('processing'), OrderStatus.processing);
      expect(OrderStatus.fromDb('shipped'), OrderStatus.shipped);
      expect(OrderStatus.fromDb('delivered'), OrderStatus.delivered);
      expect(OrderStatus.fromDb('cancelled'), OrderStatus.cancelled);
      expect(OrderStatus.fromDb('refunded'), OrderStatus.refunded);
    });

    test('fromDb returns pending for invalid or null strings', () {
      expect(OrderStatus.fromDb('unknown'), OrderStatus.pending);
      expect(OrderStatus.fromDb(''), OrderStatus.pending);
      expect(OrderStatus.fromDb(null), OrderStatus.pending);
    });

    test('label returns correct human-readable string', () {
      expect(OrderStatus.pending.label, 'Pending');
      expect(OrderStatus.shipped.label, 'Shipped');
    });
  });

  group('OrderLine', () {
    test('fromJson parses a valid JSON payload successfully', () {
      final json = {
        'id': 'line123',
        'product_title': 'Classic Tee',
        'variant_name': 'Blue',
        'size_label': 'L',
        'sku': 'TSHIRT-BLU-L',
        'unit_price': 25.50,
        'quantity': 2,
        'line_total': 51.00,
      };

      final line = OrderLine.fromJson(json);

      expect(line.id, 'line123');
      expect(line.productTitle, 'Classic Tee');
      expect(line.variantName, 'Blue');
      expect(line.sizeLabel, 'L');
      expect(line.sku, 'TSHIRT-BLU-L');
      expect(line.unitPrice, 25.50);
      expect(line.quantity, 2);
      expect(line.lineTotal, 51.00);
    });

    test('variantSummary handles missing or null variants and sizes', () {
      final line1 = OrderLine(
        id: '1', productTitle: 'A', sku: 'A', unitPrice: 10, quantity: 1, lineTotal: 10,
        variantName: 'Red', sizeLabel: 'M',
      );
      expect(line1.variantSummary, 'Red · M');

      final line2 = OrderLine(
        id: '2', productTitle: 'B', sku: 'B', unitPrice: 10, quantity: 1, lineTotal: 10,
        variantName: 'Red', sizeLabel: null,
      );
      expect(line2.variantSummary, 'Red');

      final line3 = OrderLine(
        id: '3', productTitle: 'C', sku: 'C', unitPrice: 10, quantity: 1, lineTotal: 10,
        variantName: null, sizeLabel: 'M',
      );
      expect(line3.variantSummary, 'M');

      final line4 = OrderLine(
        id: '4', productTitle: 'D', sku: 'D', unitPrice: 10, quantity: 1, lineTotal: 10,
        variantName: null, sizeLabel: null,
      );
      expect(line4.variantSummary, '');
    });
  });

  group('Order', () {
    test('fromJson parses a valid JSON payload successfully', () {
      final json = {
        'id': 'ord-456',
        'user_id': 'user-123',
        'status': 'shipped',
        'subtotal': 100.0,
        'discount_total': 10.0,
        'shipping_total': 5.0,
        'grand_total': 95.0,
        'promo_code': 'SUMMER10',
        'contact_email': 'test@example.com',
        'tracking_number': 'TRK987654321',
        'created_at': '2023-10-27T10:00:00Z',
        'order_items': [
          {
            'id': 'line1',
            'product_title': 'Shoes',
            'sku': 'SH-1',
            'unit_price': 50.0,
            'quantity': 2,
            'line_total': 100.0,
          }
        ],
      };

      final order = Order.fromJson(json);

      expect(order.id, 'ord-456');
      expect(order.userId, 'user-123');
      expect(order.status, OrderStatus.shipped);
      expect(order.subtotal, 100.0);
      expect(order.discountTotal, 10.0);
      expect(order.shippingTotal, 5.0);
      expect(order.grandTotal, 95.0);
      expect(order.promoCode, 'SUMMER10');
      expect(order.contactEmail, 'test@example.com');
      expect(order.trackingNumber, 'TRK987654321');
      expect(order.createdAt?.toIso8601String(), '2023-10-27T10:00:00.000Z');
      expect(order.lines.length, 1);
      expect(order.lines.first.productTitle, 'Shoes');
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = {
        'id': 'ord-789',
        'status': 'processing',
        'subtotal': 50.0,
        'discount_total': 0.0,
        'shipping_total': 0.0,
        'grand_total': 50.0,
      };

      final order = Order.fromJson(json);

      expect(order.id, 'ord-789');
      expect(order.status, OrderStatus.processing);
      expect(order.userId, isNull);
      expect(order.promoCode, isNull);
      expect(order.createdAt, isNull);
      expect(order.lines, isEmpty);
    });

    test('itemCount sums quantities correctly', () {
      final order = Order(
        id: '1', status: OrderStatus.pending, subtotal: 0, discountTotal: 0, shippingTotal: 0, grandTotal: 0,
        lines: [
          const OrderLine(id: 'l1', productTitle: 'A', sku: 'A', unitPrice: 10, quantity: 2, lineTotal: 20),
          const OrderLine(id: 'l2', productTitle: 'B', sku: 'B', unitPrice: 15, quantity: 3, lineTotal: 45),
        ],
      );
      expect(order.itemCount, 5);
    });

    test('reference returns correct short string based on UUID', () {
      final order1 = Order(id: '1234567890abcdef', status: OrderStatus.pending, subtotal: 0, discountTotal: 0, shippingTotal: 0, grandTotal: 0);
      expect(order1.reference, '#12345678');

      final order2 = Order(id: 'short', status: OrderStatus.pending, subtotal: 0, discountTotal: 0, shippingTotal: 0, grandTotal: 0);
      expect(order2.reference, '#short');
    });
  });
}
