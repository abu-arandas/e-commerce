import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vanguard_fashion/controllers/cart_controller.dart';
import 'package:vanguard_fashion/models/product_model.dart';
import 'package:vanguard_fashion/models/variant_model.dart';

void main() {
  group('CartController updateQuantity', () {
    late CartController cartController;
    late Product dummyProduct;
    late VariantGroup dummyGroup;
    late VariantItem dummyItem;

    setUp(() {
      Get.testMode = true;
      cartController = CartController();

      dummyProduct = const Product(
        id: 'p1',
        slug: 'p1',
        title: 'Test Product',
        basePrice: 100,
      );

      dummyGroup = const VariantGroup(id: 'g1', productId: 'p1', name: 'Black');

      dummyItem = const VariantItem(
        id: 'i1',
        groupId: 'g1',
        sku: 'SKU1',
        sizeLabel: 'M',
        stockQuantity: 5,
      );
    });

    test('updates quantity properly within bounds', () {
      cartController.add(
        product: dummyProduct,
        group: dummyGroup,
        item: dummyItem,
        quantity: 1,
      );

      expect(cartController.items.first.quantity, 1);

      cartController.updateQuantity('i1', 3);

      expect(cartController.items.first.quantity, 3);
      expect(cartController.items.length, 1);
    });

    test('removes item when quantity is 0', () {
      cartController.add(
        product: dummyProduct,
        group: dummyGroup,
        item: dummyItem,
        quantity: 2,
      );

      cartController.updateQuantity('i1', 0);

      expect(cartController.items.isEmpty, isTrue);
    });

    test('removes item when quantity is negative', () {
      cartController.add(
        product: dummyProduct,
        group: dummyGroup,
        item: dummyItem,
        quantity: 2,
      );

      cartController.updateQuantity('i1', -1);

      expect(cartController.items.isEmpty, isTrue);
    });

    test('clamps quantity to maxStock when updating to larger amount', () {
      cartController.add(
        product: dummyProduct,
        group: dummyGroup,
        item: dummyItem,
        quantity: 2,
      );

      // Stock is 5
      cartController.updateQuantity('i1', 10);

      expect(cartController.items.first.quantity, 5);
      expect(cartController.items.length, 1);
    });

    test('does nothing if item is not found', () {
      cartController.add(
        product: dummyProduct,
        group: dummyGroup,
        item: dummyItem,
        quantity: 2,
      );

      cartController.updateQuantity('non-existent-key', 5);

      expect(cartController.items.length, 1);
      expect(cartController.items.first.quantity, 2);
    });
  });
}
