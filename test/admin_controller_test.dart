import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/controllers/admin_controller.dart';
import 'package:vanguard_fashion/models/product_model.dart';
import 'package:vanguard_fashion/models/variant_model.dart';

void main() {
  test('totalSkus calculation works and updates with cached value', () async {
    final controller = AdminController();

    // Create mock products with variants
    final items1 = List.generate(2, (i) => VariantItem(id: '$i', groupId: 'g1', sku: 's1-$i', sizeLabel: 'M', stockQuantity: 10, sortOrder: i));
    final groups1 = [VariantGroup(id: 'g1', productId: 'p1', name: 'Color', sortOrder: 0, items: items1)];
    final product1 = Product(id: 'p1', slug: 'slug-1', title: 'Product 1', basePrice: 10, isActive: true, groups: groups1);

    final items2 = List.generate(3, (i) => VariantItem(id: '$i', groupId: 'g2', sku: 's2-$i', sizeLabel: 'L', stockQuantity: 5, sortOrder: i));
    final groups2 = [VariantGroup(id: 'g2', productId: 'p2', name: 'Size', sortOrder: 0, items: items2)];
    final product2 = Product(id: 'p2', slug: 'slug-2', title: 'Product 2', basePrice: 20, isActive: true, groups: groups2);

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
}
