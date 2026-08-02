import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/admin_controller.dart';
import 'package:vanguard_fashion/models/product_model.dart';
import 'package:vanguard_fashion/models/variant_model.dart';

void main() {
  group('AdminController - lowStock logic', () {
    late AdminController controller;

    setUp(() {
      controller = AdminController();
    });

    test('returns empty list when no products', () {
      expect(controller.lowStock, isEmpty);
    });

    test('returns empty list when all stock is above threshold', () {
      controller.products.add(
        const Product(
          id: 'p1',
          slug: 'p1',
          title: 'Product 1',
          basePrice: 10,
          groups: [
            VariantGroup(
              id: 'g1',
              productId: 'p1',
              name: 'Red',
              items: [
                VariantItem(
                  id: 'i1',
                  groupId: 'g1',
                  sku: 'P1-R-M',
                  sizeLabel: 'M',
                  stockQuantity: 10,
                  lowStockThreshold: 5,
                ),
              ],
            ),
          ],
        ),
      );

      expect(controller.lowStock, isEmpty);
    });

    test('identifies stock equal to threshold', () {
      controller.products.add(
        const Product(
          id: 'p1',
          slug: 'p1',
          title: 'Product 1',
          basePrice: 10,
          groups: [
            VariantGroup(
              id: 'g1',
              productId: 'p1',
              name: 'Red',
              items: [
                VariantItem(
                  id: 'i1',
                  groupId: 'g1',
                  sku: 'P1-R-M',
                  sizeLabel: 'M',
                  stockQuantity: 5,
                  lowStockThreshold: 5,
                ),
              ],
            ),
          ],
        ),
      );

      final lowStock = controller.lowStock;
      expect(lowStock, hasLength(1));
      expect(lowStock.first.sku, 'P1-R-M');
      expect(lowStock.first.stock, 5);
      expect(lowStock.first.threshold, 5);
      expect(lowStock.first.isOut, isFalse);
    });

    test('identifies stock below threshold and out of stock', () {
      controller.products.add(
        const Product(
          id: 'p1',
          slug: 'p1',
          title: 'Product 1',
          basePrice: 10,
          groups: [
            VariantGroup(
              id: 'g1',
              productId: 'p1',
              name: 'Red',
              items: [
                VariantItem(
                  id: 'i1',
                  groupId: 'g1',
                  sku: 'P1-R-M',
                  sizeLabel: 'M',
                  stockQuantity: 0,
                  lowStockThreshold: 5,
                ),
                VariantItem(
                  id: 'i2',
                  groupId: 'g1',
                  sku: 'P1-R-L',
                  sizeLabel: 'L',
                  stockQuantity: 3,
                  lowStockThreshold: 5,
                ),
              ],
            ),
          ],
        ),
      );

      final lowStock = controller.lowStock;
      expect(lowStock, hasLength(2));

      // Sorted by stock ascending
      expect(lowStock[0].sku, 'P1-R-M');
      expect(lowStock[0].stock, 0);
      expect(lowStock[0].isOut, isTrue);

      expect(lowStock[1].sku, 'P1-R-L');
      expect(lowStock[1].stock, 3);
      expect(lowStock[1].isOut, isFalse);
    });

    test('maps fields correctly from product, group, and item', () {
      controller.products.add(
        const Product(
          id: 'p1',
          slug: 'p1',
          title: 'Awesome Shirt',
          basePrice: 10,
          groups: [
            VariantGroup(
              id: 'g1',
              productId: 'p1',
              name: 'Ocean Blue',
              items: [
                VariantItem(
                  id: 'i1',
                  groupId: 'g1',
                  sku: 'SHIRT-OB-XL',
                  sizeLabel: 'XL',
                  stockQuantity: 2,
                  lowStockThreshold: 10,
                ),
              ],
            ),
          ],
        ),
      );

      final entry = controller.lowStock.first;
      expect(entry.productTitle, 'Awesome Shirt');
      expect(entry.colorName, 'Ocean Blue');
      expect(entry.sizeLabel, 'XL');
      expect(entry.sku, 'SHIRT-OB-XL');
      expect(entry.stock, 2);
      expect(entry.threshold, 10);
    });
  });
}
