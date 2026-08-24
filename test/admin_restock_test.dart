import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/admin_controller.dart';
import 'package:vanguard_fashion/models/order_model.dart';

/// Cancelling or refunding an order has to put its units back on the shelf.
/// Nothing called restock_order() before, so stock stayed decremented forever.
///
/// The RPC itself only fires against a live backend; what is asserted here is
/// the decision of *when* to fire it, which is where the bug was.
void main() {
  group('which transitions return stock', () {
    test('leaving the pipeline restocks', () {
      expect(
        AdminController.restocksOn(OrderStatus.pending, OrderStatus.cancelled),
        isTrue,
      );
      expect(
        AdminController.restocksOn(OrderStatus.paid, OrderStatus.refunded),
        isTrue,
      );
      expect(
        AdminController.restocksOn(OrderStatus.shipped, OrderStatus.cancelled),
        isTrue,
      );
    });

    test('ordinary fulfilment progress does not', () {
      expect(
        AdminController.restocksOn(OrderStatus.pending, OrderStatus.paid),
        isFalse,
      );
      expect(
        AdminController.restocksOn(OrderStatus.paid, OrderStatus.processing),
        isFalse,
      );
      expect(
        AdminController.restocksOn(OrderStatus.processing, OrderStatus.shipped),
        isFalse,
      );
      expect(
        AdminController.restocksOn(OrderStatus.shipped, OrderStatus.delivered),
        isFalse,
      );
    });

    test('an order already out of the pipeline does not restock twice', () {
      // cancelled -> refunded is a real transition in the fulfilment grid, and
      // it must not credit the stock a second time.
      expect(
        AdminController.restocksOn(OrderStatus.cancelled, OrderStatus.refunded),
        isFalse,
      );
      expect(
        AdminController.restocksOn(OrderStatus.refunded, OrderStatus.cancelled),
        isFalse,
      );
      expect(
        AdminController.restocksOn(
          OrderStatus.cancelled,
          OrderStatus.cancelled,
        ),
        isFalse,
      );
    });

    test('reinstating an order does not restock', () {
      expect(
        AdminController.restocksOn(
          OrderStatus.cancelled,
          OrderStatus.processing,
        ),
        isFalse,
      );
    });
  });

  group('which statuses should hold stock back', () {
    // The caller gates on this rather than on the transition. Gating on the
    // transition meant a restock that failed on cancel was never attempted
    // again: cancelled -> refunded is not a transition *into* a restocking
    // status, so the units stayed missing with no way to recover them.
    //
    // Safe to act on repeatedly because restock_order() claims the restock
    // (restocked_at) before crediting, so only the first call of any sequence
    // moves stock. restocksOn is retained because it names the transition.
    test('an order out of the pipeline should have its units back', () {
      expect(AdminController.restocksInto(OrderStatus.cancelled), isTrue);
      expect(AdminController.restocksInto(OrderStatus.refunded), isTrue);
    });

    test('an order still in the pipeline should not', () {
      expect(AdminController.restocksInto(OrderStatus.pending), isFalse);
      expect(AdminController.restocksInto(OrderStatus.paid), isFalse);
      expect(AdminController.restocksInto(OrderStatus.processing), isFalse);
      expect(AdminController.restocksInto(OrderStatus.shipped), isFalse);
      expect(AdminController.restocksInto(OrderStatus.delivered), isFalse);
    });

    test(
      'cancelled -> refunded retries, where restocksOn would have skipped',
      () {
        // The exact gap: the transition test says no, the status test says yes,
        // and idempotency makes the second answer the safe one.
        expect(
          AdminController.restocksOn(
            OrderStatus.cancelled,
            OrderStatus.refunded,
          ),
          isFalse,
        );
        expect(AdminController.restocksInto(OrderStatus.refunded), isTrue);
      },
    );
  });
}
