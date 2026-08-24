import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vanguard_fashion/controllers/cart_controller.dart';
import 'package:vanguard_fashion/core/utils/demo_data.dart';
import 'package:vanguard_fashion/core/utils/env.dart';
import 'package:vanguard_fashion/core/utils/supabase_service.dart';
import 'package:vanguard_fashion/models/cart_item_model.dart';
import 'package:vanguard_fashion/models/product_model.dart';
import 'package:vanguard_fashion/models/promotion_model.dart';
import 'package:vanguard_fashion/models/variant_model.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final Object? _value;
  final bool _shouldThrow;

  FakePostgrestFilterBuilder.value(this._value) : _shouldThrow = false;
  FakePostgrestFilterBuilder.error(this._value) : _shouldThrow = true;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    if (_shouldThrow) {
      return Future<T>.error(_value as Object).then(onValue, onError: onError);
    }
    return Future<T>.value(_value as T).then(onValue, onError: onError);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    if (_shouldThrow) {
      return Future<T>.error(_value as Object).catchError(onError, test: test);
    }
    return Future<T>.value(_value as T).catchError(onError, test: test);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    if (_shouldThrow) {
      return Future<T>.error(_value as Object).whenComplete(action);
    }
    return Future<T>.value(_value as T).whenComplete(action);
  }

  @override
  Stream<T> asStream() {
    if (_shouldThrow) {
      return Stream<T>.error(_value as Object);
    }
    return Stream<T>.value(_value as T);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    if (_shouldThrow) {
      return Future<T>.error(
        _value as Object,
      ).timeout(timeLimit, onTimeout: onTimeout);
    }
    return Future<T>.value(
      _value as T,
    ).timeout(timeLimit, onTimeout: onTimeout);
  }
}

void main() {
  group('CartController Totals Tests', () {
    late CartController cartController;

    setUp(() {
      cartController = CartController();
    });

    CartItem createCartItem({
      required String id,
      String? category,
      double unitPrice = 10.0,
      int quantity = 1,
    }) {
      return CartItem(
        productId: 'prod_$id',
        productSlug: 'slug_$id',
        productTitle: 'Title $id',
        category: category,
        variantGroupId: 'group_$id',
        variantItemId: 'item_$id',
        sku: 'SKU_$id',
        colorName: 'Color $id',
        sizeLabel: 'Size $id',
        unitPrice: unitPrice,
        quantity: quantity,
      );
    }

    test('itemCount correctly sums up quantities', () {
      expect(cartController.itemCount, 0);
      cartController.items.add(createCartItem(id: '1', quantity: 2));
      cartController.items.add(createCartItem(id: '2', quantity: 3));
      expect(cartController.itemCount, 5);
    });

    test('isEmpty is true when items is empty, false otherwise', () {
      expect(cartController.isEmpty, isTrue);
      cartController.items.add(createCartItem(id: '1'));
      expect(cartController.isEmpty, isFalse);
    });

    test('subtotal correctly calculates sum of lineTotal', () {
      expect(cartController.subtotal, 0.0);
      cartController.items.add(
        createCartItem(id: '1', unitPrice: 10.0, quantity: 2),
      ); // 20.0
      cartController.items.add(
        createCartItem(id: '2', unitPrice: 15.0, quantity: 1),
      ); // 15.0
      expect(cartController.subtotal, 35.0);
    });

    test('categories correctly extracts distinct categories', () {
      expect(cartController.categories, isEmpty);
      cartController.items.add(createCartItem(id: '1', category: 'Shirts'));
      cartController.items.add(createCartItem(id: '2', category: 'Pants'));
      cartController.items.add(createCartItem(id: '3', category: 'Shirts'));
      cartController.items.add(
        createCartItem(id: '4', category: null),
      ); // Should be ignored
      expect(cartController.categories, unorderedEquals(['Shirts', 'Pants']));
    });

    test(
      'discount reflects applied promo discount Amount, 0 if invalid or none',
      () {
        expect(cartController.discount, 0.0);

        cartController.appliedPromo.value = const PromoValidation(
          valid: true,
          discountAmount: 15.0,
        );
        expect(cartController.discount, 15.0);

        cartController.appliedPromo.value = PromoValidation.invalid('Expired');
        expect(cartController.discount, 0.0);
      },
    );

    test('hasFreeShipping resolves true based on subtotal or promo', () {
      expect(cartController.hasFreeShipping, isFalse); // Empty cart, subtotal 0

      // Promo gives free shipping
      cartController.appliedPromo.value = const PromoValidation(
        valid: true,
        freeShipping: true,
      );
      expect(cartController.hasFreeShipping, isTrue);

      cartController.appliedPromo.value = null;

      // Subtotal reaches threshold
      cartController.items.add(
        createCartItem(
          id: '1',
          unitPrice: Env.freeShippingThreshold,
          quantity: 1,
        ),
      );
      expect(cartController.hasFreeShipping, isTrue);
    });

    test('baseShipping calculates correctly', () {
      expect(cartController.baseShipping, 0.0); // Empty cart

      cartController.items.add(createCartItem(id: '1', unitPrice: 50.0));
      expect(
        cartController.baseShipping,
        Env.flatShippingFee,
      ); // Subtotal < threshold

      cartController.items.add(
        createCartItem(id: '2', unitPrice: Env.freeShippingThreshold),
      );
      expect(cartController.baseShipping, 0.0); // Subtotal >= threshold
    });

    test(
      'shipping applies 0 when hasFreeShipping is true, else baseShipping',
      () {
        // Setup subtotal < threshold
        cartController.items.add(createCartItem(id: '1', unitPrice: 50.0));
        expect(cartController.shipping, Env.flatShippingFee);

        // Apply free shipping promo
        cartController.appliedPromo.value = const PromoValidation(
          valid: true,
          freeShipping: true,
        );
        expect(cartController.shipping, 0.0);
      },
    );

    test(
      'grandTotal calculates subtotal - discount + shipping and avoids negative',
      () {
        // Setup subtotal 50, shipping is Env.flatShippingFee
        cartController.items.add(createCartItem(id: '1', unitPrice: 50.0));
        expect(cartController.grandTotal, 50.0 + Env.flatShippingFee);

        // Apply discount
        cartController.appliedPromo.value = const PromoValidation(
          valid: true,
          discountAmount: 10.0,
        );
        expect(cartController.grandTotal, 40.0 + Env.flatShippingFee);

        // Apply huge discount
        cartController.appliedPromo.value = const PromoValidation(
          valid: true,
          discountAmount: 100.0,
        );
        expect(cartController.grandTotal, 0.0);
      },
    );

    test('amountToFreeShipping calculates remaining amount to threshold', () {
      expect(cartController.amountToFreeShipping, Env.freeShippingThreshold);

      cartController.items.add(
        createCartItem(id: '1', unitPrice: Env.freeShippingThreshold - 20),
      );
      expect(cartController.amountToFreeShipping, 20.0);

      cartController.items.add(createCartItem(id: '2', unitPrice: 30.0));
      expect(cartController.amountToFreeShipping, 0.0);
    });
  });

  group('CartController - Promo Validation', () {
    late CartController cart;

    setUp(() {
      cart = CartController();
    });

    test('initial state', () {
      expect(cart.isEmpty, isTrue);
      expect(cart.appliedCode.value, isNull);
      expect(cart.appliedPromo.value, isNull);
    });

    test('applyPromo with empty code', () async {
      final success = await cart.applyPromo('   ');
      expect(success, isFalse);
      expect(cart.promoError.value, 'Enter a promo code');
      expect(cart.appliedCode.value, isNull);
    });

    test('applyPromo with invalid code', () async {
      final success = await cart.applyPromo('INVALID123');
      expect(success, isFalse);
      expect(cart.promoError.value, 'Code not found');
      expect(cart.appliedCode.value, isNull);
    });

    test('applyPromo with minimum order not met', () async {
      // The FALL20 promo requires $150 minimum order (DemoData.promotions)
      final success = await cart.applyPromo('FALL20');
      expect(success, isFalse);
      expect(cart.promoError.value, contains('Requires a minimum order'));
      expect(cart.appliedCode.value, isNull);
    });

    test('applyPromo with valid conditions applies discount', () async {
      final product = DemoData.products().first;
      final group = product.groups.first;
      final item = group.items.first;

      // Ensure price > $150 to meet FALL20 minimum
      cart.add(product: product, group: group, item: item, quantity: 1);
      if (cart.subtotal < 150) {
        cart.add(product: product, group: group, item: item, quantity: 10);
      }

      final success = await cart.applyPromo('FALL20');
      expect(success, isTrue);
      expect(cart.promoError.value, isEmpty);
      expect(cart.appliedCode.value, 'FALL20');
      expect(cart.appliedPromo.value, isNotNull);
      expect(cart.appliedPromo.value!.discountAmount, greaterThan(0));
      expect(cart.discount, cart.appliedPromo.value!.discountAmount);
    });

    test('clearPromo resets promo state', () async {
      final product = DemoData.products().first;
      cart.add(
        product: product,
        group: product.groups.first,
        item: product.groups.first.items.first,
        quantity: 5,
      );

      await cart.applyPromo('FALL20');
      expect(cart.appliedCode.value, 'FALL20');

      cart.clearPromo();
      expect(cart.appliedCode.value, isNull);
      expect(cart.appliedPromo.value, isNull);
      expect(cart.promoError.value, isEmpty);
      expect(cart.discount, 0.0);
    });

    test(
      'cart changes invalidate promo if conditions no longer apply',
      () async {
        final product = DemoData.products().first;
        final group = product.groups.first;
        final item = group.items.first;
        final key = item.id;

        cart.add(product: product, group: group, item: item, quantity: 5);

        // Fall20 minimum is $150
        final success = await cart.applyPromo('FALL20');
        expect(success, isTrue);
        expect(cart.appliedCode.value, 'FALL20');

        // Reduce quantity so subtotal drops below minimum order
        cart.updateQuantity(key, 0); // Remove all items

        // Needs to wait for the internal `_refreshPromo` Future to complete
        await Future.delayed(Duration.zero);

        expect(cart.appliedCode.value, isNull);
        expect(cart.appliedPromo.value, isNull);
      },
    );
  });

  late CartController controller;
  late MockSupabaseClient mockSupabaseClient;

  late Product testProduct;
  late VariantGroup testGroup;
  late VariantItem testItem;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    controller = CartController();
    mockSupabaseClient = MockSupabaseClient();

    testProduct = const Product(
      id: '1',
      slug: 'test-product',
      title: 'Test Product',
      category: 'Test',
      basePrice: 100.0,
      description: 'A test product description',
    );

    testGroup = const VariantGroup(
      id: 'g1',
      productId: '1',
      name: 'Black',
      colorHex: '#000000',
      items: [],
    );

    testItem = const VariantItem(
      id: 'i1',
      groupId: 'g1',
      sku: 'TEST-BLK-M',
      sizeLabel: 'M',
      stockQuantity: 10,
    );
  });

  tearDown(() {
    SupabaseService.clearMockClient();
  });

  group('CartController placeOrder()', () {
    test('returns null when cart is empty', () async {
      // Act
      final order = await controller.placeOrder();

      // Assert
      expect(order, isNull);
      expect(controller.isPlacingOrder.value, isFalse);
    });

    test('happy path returns Order and clears cart', () async {
      // Arrange
      SupabaseService.setMockClient(mockSupabaseClient);

      controller.add(
        product: testProduct,
        group: testGroup,
        item: testItem,
        quantity: 1,
      );

      final mockResponse = {
        'order_id': 'order123',
        'subtotal': 100.0,
        'discount_total': 0.0,
        'shipping_total': 0.0,
        'grand_total': 100.0,
      };

      when(
        () => mockSupabaseClient.rpc(any(), params: any(named: 'params')),
      ).thenAnswer(
        (_) => FakePostgrestFilterBuilder<dynamic>.value(mockResponse),
      );

      // Act
      final order = await controller.placeOrder(
        contactEmail: 'test@example.com',
      );

      // Assert
      expect(order, isNotNull);
      expect(order!.id, 'order123');
      expect(order.subtotal, 100.0);
      expect(controller.items.isEmpty, isTrue); // Cart cleared
      expect(controller.isPlacingOrder.value, isFalse);
    });

    test(
      'accepts string-encoded totals from a committed order response',
      () async {
        SupabaseService.setMockClient(mockSupabaseClient);
        controller.add(
          product: testProduct,
          group: testGroup,
          item: testItem,
          quantity: 1,
        );

        final mockResponse = {
          'order_id': 'order-string-totals',
          'subtotal': '100.00',
          'discount_total': '5.50',
          'shipping_total': '12.00',
          'grand_total': '106.50',
        };

        when(
          () => mockSupabaseClient.rpc(any(), params: any(named: 'params')),
        ).thenAnswer(
          (_) => FakePostgrestFilterBuilder<dynamic>.value(mockResponse),
        );

        final order = await controller.placeOrder(
          contactEmail: 'test@example.com',
        );

        expect(order, isNotNull);
        expect(order!.id, 'order-string-totals');
        expect(order.subtotal, 100.0);
        expect(order.discountTotal, 5.5);
        expect(order.shippingTotal, 12.0);
        expect(order.grandTotal, 106.5);
        expect(controller.items, isEmpty);
        expect(controller.promoError.value, isEmpty);
      },
    );

    test(
      'exception path handles Supabase errors and keeps cart items',
      () async {
        // Arrange
        SupabaseService.setMockClient(mockSupabaseClient);

        controller.add(
          product: testProduct,
          group: testGroup,
          item: testItem,
          quantity: 1,
        );

        when(
          () => mockSupabaseClient.rpc(any(), params: any(named: 'params')),
        ).thenAnswer(
          (_) => FakePostgrestFilterBuilder<dynamic>.error(
            Exception('Supabase RPC failure'),
          ),
        );

        // Act
        final order = await controller.placeOrder(
          contactEmail: 'test@example.com',
        );

        // Assert
        expect(order, isNull);
        expect(controller.promoError.value, contains('Supabase RPC failure'));
        expect(controller.isPlacingOrder.value, isFalse);
        expect(
          controller.items.isNotEmpty,
          isTrue,
        ); // Cart shouldn't be cleared on error
      },
    );

    test(
      'demo fallback path creates a demo order when Supabase is not ready',
      () async {
        // Arrange
        // Do NOT setMockClient, so SupabaseService.isReady is false

        controller.add(
          product: testProduct,
          group: testGroup,
          item: testItem,
          quantity: 1,
        );

        // Act
        final order = await controller.placeOrder(
          contactEmail: 'demo@example.com',
        );

        // Assert
        expect(order, isNotNull);
        expect(order!.contactEmail, 'demo@example.com');
        expect(controller.items.isEmpty, isTrue); // Cart cleared
        expect(controller.isPlacingOrder.value, isFalse);
      },
    );
  });
}
