import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vanguard_fashion/controllers/cart_controller.dart';
import 'package:vanguard_fashion/core/utils/supabase_service.dart';
import 'package:vanguard_fashion/models/product_model.dart';
import 'package:vanguard_fashion/models/variant_model.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakePostgrestFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final Object? _value;
  final bool _shouldThrow;

  FakePostgrestFilterBuilder.value(this._value) : _shouldThrow = false;
  FakePostgrestFilterBuilder.error(this._value) : _shouldThrow = true;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
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
      return Future<T>.error(_value as Object).timeout(timeLimit, onTimeout: onTimeout);
    }
    return Future<T>.value(_value as T).timeout(timeLimit, onTimeout: onTimeout);
  }
}

void main() {
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

      controller.add(product: testProduct, group: testGroup, item: testItem, quantity: 1);

      final mockResponse = {
        'order_id': 'order123',
        'subtotal': 100.0,
        'discount_total': 0.0,
        'shipping_total': 0.0,
        'grand_total': 100.0,
      };

      when(() => mockSupabaseClient.rpc(
        any(),
        params: any(named: 'params'),
      )).thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>.value(mockResponse));

      // Act
      final order = await controller.placeOrder(contactEmail: 'test@example.com');

      // Assert
      expect(order, isNotNull);
      expect(order!.id, 'order123');
      expect(order.subtotal, 100.0);
      expect(controller.items.isEmpty, isTrue); // Cart cleared
      expect(controller.isPlacingOrder.value, isFalse);
    });

    test('exception path handles Supabase errors and keeps cart items', () async {
      // Arrange
      SupabaseService.setMockClient(mockSupabaseClient);

      controller.add(product: testProduct, group: testGroup, item: testItem, quantity: 1);

      when(() => mockSupabaseClient.rpc(
        any(),
        params: any(named: 'params'),
      )).thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>.error(Exception('Supabase RPC failure')));

      // Act
      final order = await controller.placeOrder(
        contactEmail: 'test@example.com',
      );

      // Assert
      expect(order, isNull);
      expect(controller.promoError.value, contains('Supabase RPC failure'));
      expect(controller.isPlacingOrder.value, isFalse);
      expect(controller.items.isNotEmpty, isTrue); // Cart shouldn't be cleared on error
    });

    test('demo fallback path creates a demo order when Supabase is not ready', () async {
      // Arrange
      // Do NOT setMockClient, so SupabaseService.isReady is false

      controller.add(product: testProduct, group: testGroup, item: testItem, quantity: 1);

      // Act
      final order = await controller.placeOrder(contactEmail: 'demo@example.com');

      // Assert
      expect(order, isNotNull);
      expect(order!.contactEmail, 'demo@example.com');
      expect(controller.items.isEmpty, isTrue); // Cart cleared
      expect(controller.isPlacingOrder.value, isFalse);
    });
  });
}
