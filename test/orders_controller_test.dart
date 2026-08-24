import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/orders_controller.dart';
import 'package:vanguard_fashion/models/order_model.dart';

/// OrdersController backs the account page's order history. It replaced
/// AdminController there, which was the back-office view of every order in the
/// store — so the behaviour here is what keeps one shopper from seeing another's
/// orders. It had no tests at all.
void main() {
  late OrdersController orders;

  Order order(String id, {OrderStatus status = OrderStatus.pending}) => Order(
    id: id,
    status: status,
    subtotal: 100,
    discountTotal: 0,
    shippingTotal: 0,
    grandTotal: 100,
    createdAt: DateTime.now(),
  );

  setUp(() => orders = OrdersController());

  test('starts empty', () {
    expect(orders.orders, isEmpty);
    expect(orders.isLoading.value, isFalse);
    expect(orders.error.value, isEmpty);
  });

  test('a recorded order appears immediately, newest first', () {
    orders.record(order('first'));
    orders.record(order('second'));

    expect(
      orders.orders.first.id,
      'second',
      reason: 'the newest order leads the list',
    );
    expect(orders.orders.length, 2);
  });

  test('clear drops everything', () {
    orders.record(order('a'));
    orders.error.value = 'stale message';

    orders.clear();

    expect(orders.orders, isEmpty);
    expect(orders.error.value, isEmpty);
  });

  test(
    'history does not survive a clear, so it cannot leak to the next account',
    () async {
      orders.record(order('previous-account'));
      orders.clear();

      // Demo mode replays session orders on fetch; after clear there are none.
      await orders.fetch();

      expect(
        orders.orders,
        isEmpty,
        reason:
            "a cleared session must not replay the previous account's orders",
      );
    },
  );

  test('demo fetch replays what was recorded this session', () async {
    orders.record(order('x'));
    orders.record(order('y'));

    await orders.fetch();

    expect(orders.orders.map((o) => o.id), containsAll(['x', 'y']));
  });
}
