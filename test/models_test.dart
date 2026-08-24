import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/core/utils/formatters.dart';
import 'package:vanguard_fashion/core/utils/json_parse.dart';
import 'package:vanguard_fashion/core/utils/uuid.dart';
import 'package:vanguard_fashion/models/cart_item_model.dart';
import 'package:vanguard_fashion/models/order_model.dart';
import 'package:vanguard_fashion/models/product_model.dart';
import 'package:vanguard_fashion/models/promotion_model.dart';
import 'package:vanguard_fashion/models/user_model.dart';
import 'package:vanguard_fashion/models/variant_model.dart';

void main() {
  group('J (defensive JSON coercion)', () {
    test('accepts numerics arriving as strings', () {
      // Postgres/PostgREST may serialise numeric columns either way.
      expect(J.toDouble('12.50'), 12.5);
      expect(J.toDouble(12.5), 12.5);
      expect(J.toInt('7'), 7);
      expect(J.toBool('t'), isTrue);
      expect(J.toBool('true'), isTrue);
      expect(J.toBool('1'), isTrue);
      expect(J.toBool('f'), isFalse);
    });

    test('falls back rather than throwing on junk', () {
      expect(J.toDouble('not a number', 3), 3);
      expect(J.toInt(null, 5), 5);
      expect(J.toDoubleOrNull('nope'), isNull);
      expect(J.strList('not a list'), isEmpty);
      expect(J.dateOrNull('not a date'), isNull);
    });
  });

  group('Uuid', () {
    test('generates well-formed v4 identifiers', () {
      for (var i = 0; i < 50; i++) {
        final id = Uuid.v4();
        expect(Uuid.isValid(id), isTrue, reason: id);
        expect(id[14], '4', reason: 'version nibble');
        expect('89ab'.contains(id[19]), isTrue, reason: 'variant nibble');
      }
    });

    test('generates distinct values', () {
      final ids = {for (var i = 0; i < 500; i++) Uuid.v4()};
      expect(ids.length, 500);
    });

    test('rejects the kind of id that Postgres would refuse', () {
      expect(Uuid.isValid('new-1712345678'), isFalse);
      expect(Uuid.isValid('promo-1712345678'), isFalse);
      expect(Uuid.isValid(null), isFalse);
    });
  });

  group('Product pricing', () {
    final product = Product(
      id: Uuid.v4(),
      slug: 'test',
      title: 'Test',
      basePrice: 100,
      groups: [
        VariantGroup(
          id: Uuid.v4(),
          productId: 'p',
          name: 'Midnight Blue',
          items: const [
            VariantItem(
              id: 'a',
              groupId: 'g',
              sku: 'A',
              sizeLabel: 'S',
              stockQuantity: 2,
            ),
            VariantItem(
              id: 'b',
              groupId: 'g',
              sku: 'B',
              sizeLabel: 'M',
              stockQuantity: 0,
              priceOverride: 130,
            ),
          ],
        ),
      ],
    );

    test('reports the cheapest and dearest variant price', () {
      expect(product.fromPrice, 100);
      expect(product.maxPrice, 130);
      expect(product.hasPriceRange, isTrue);
    });

    test('totals stock across the whole tree', () {
      expect(product.totalStock, 2);
      expect(product.inStock, isTrue);
    });

    test('is out of stock only when every SKU is', () {
      final soldOut = product.copyWith(
        groups: [
          product.groups.first.copyWith(
            items: const [
              VariantItem(
                id: 'a',
                groupId: 'g',
                sku: 'A',
                sizeLabel: 'S',
                stockQuantity: 0,
              ),
            ],
          ),
        ],
      );
      expect(soldOut.inStock, isFalse);
    });
  });

  group('VariantGroup slug', () {
    VariantGroup named(String name) =>
        VariantGroup(id: 'g', productId: 'p', name: name);

    test('is URL-safe for deep links', () {
      expect(named('Midnight Blue').slug, 'midnight-blue');
      expect(named('Off-White').slug, 'off-white');
      expect(named('  Ecru  ').slug, 'ecru');
    });
  });

  group('CartItem serialisation', () {
    test('round-trips through JSON for cart persistence', () {
      final item = CartItem(
        productId: 'p',
        productSlug: 's',
        productTitle: 'T',
        category: 'Knitwear',
        variantGroupId: 'g',
        variantItemId: 'v',
        sku: 'SKU-1',
        colorName: 'Ecru',
        sizeLabel: 'M',
        unitPrice: 245,
        quantity: 2,
        maxStock: 5,
      );

      final restored = CartItem.fromJson(item.toJson());

      expect(restored.variantItemId, 'v');
      expect(restored.unitPrice, 245);
      expect(restored.quantity, 2);
      expect(restored.category, 'Knitwear');
      expect(restored.lineTotal, 490);
    });

    test('survives string-encoded numerics', () {
      final restored = CartItem.fromJson(const {
        'variant_item_id': 'v',
        'unit_price': '245.00',
        'quantity': '2',
        'max_stock': '5',
      });

      expect(restored.unitPrice, 245);
      expect(restored.quantity, 2);
      expect(restored.maxStock, 5);
    });
  });

  group('Order', () {
    test('derives a short human reference', () {
      const order = Order(
        id: 'abcdef12-3456-7890-abcd-ef1234567890',
        status: OrderStatus.pending,
        subtotal: 1,
        discountTotal: 0,
        shippingTotal: 0,
        grandTotal: 1,
      );
      expect(order.reference, '#ABCDEF12');
    });

    test('maps unknown statuses to pending rather than throwing', () {
      expect(OrderStatus.fromDb('nonsense'), OrderStatus.pending);
      expect(OrderStatus.fromDb('shipped'), OrderStatus.shipped);
    });

    test('parses a category off the line', () {
      final line = OrderLine.fromJson(const {
        'id': 'l',
        'product_title': 'T',
        'sku': 'S',
        'unit_price': '10',
        'quantity': '2',
        'line_total': '20',
        'category': 'Dresses',
      });
      expect(line.category, 'Dresses');
      expect(line.lineTotal, 20);
    });
  });

  group('roles', () {
    test('maps database values to permissions', () {
      expect(AppRole.fromDb('catalog_manager').canManageCatalog, isTrue);
      expect(AppRole.fromDb('marketing_manager').canManagePromotions, isTrue);
      expect(AppRole.fromDb('fulfillment').canManageOrders, isTrue);
      expect(AppRole.fromDb('customer').isStaff, isFalse);
      expect(AppRole.fromDb(null).isStaff, isFalse);
    });

    test('an admin can do everything', () {
      const admin = AppRole.admin;
      expect(
        admin.canManageCatalog &&
            admin.canManagePromotions &&
            admin.canManageOrders,
        isTrue,
      );
    });
  });

  group('Formatters', () {
    test('formats currency and trims whole amounts', () {
      expect(Formatters.price(245), '\$245.00');
      expect(Formatters.priceTrim(245), '\$245');
      expect(Formatters.priceTrim(245.5), '\$245.50');
    });

    test('describes stock levels', () {
      expect(Formatters.stockLabel(0), 'Sold out');
      expect(Formatters.stockLabel(3), 'Only 3 left');
      expect(Formatters.stockLabel(3, compact: true), '3 left');
      expect(Formatters.stockLabel(50), 'In stock');
    });
  });

  group('DiscountType', () {
    test('round-trips through its database representation', () {
      for (final t in DiscountType.values) {
        expect(DiscountType.fromDb(t.db), t);
      }
    });

    test('defaults to percentage for unknown values', () {
      expect(DiscountType.fromDb('gibberish'), DiscountType.percentage);
    });
  });
}
