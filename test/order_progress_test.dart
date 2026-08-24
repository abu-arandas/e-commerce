import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/models/order_model.dart';
import 'package:vanguard_fashion/views/storefront/order_confirmation_view.dart';

/// The confirmation page's timeline used to hardcode step 0, so a delivered
/// order still read "Order Placed".
void main() {
  group('order progress step', () {
    test('placed covers both pre-fulfilment states', () {
      expect(orderProgressStep(OrderStatus.pending), 0);
      expect(orderProgressStep(OrderStatus.paid), 0);
    });

    test('advances through the fulfilment pipeline', () {
      expect(orderProgressStep(OrderStatus.processing), 1);
      expect(orderProgressStep(OrderStatus.shipped), 2);
      expect(orderProgressStep(OrderStatus.delivered), 3);
    });

    test(
      'an order that left the pipeline shows no progress beyond placement',
      () {
        expect(orderProgressStep(OrderStatus.cancelled), 0);
        expect(orderProgressStep(OrderStatus.refunded), 0);
      },
    );

    test('every status maps to a real step', () {
      for (final s in OrderStatus.values) {
        final step = orderProgressStep(s);
        expect(step, inInclusiveRange(0, 3), reason: '$s');
      }
    });
  });
}
