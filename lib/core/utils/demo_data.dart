import 'package:collection/collection.dart';

import '../../models/product_model.dart';
import '../../models/promotion_model.dart';
import '../../models/variant_model.dart';

/// In-memory catalog used when Supabase credentials are not configured, so the
/// storefront and admin panels are always fully explorable. Mirrors
/// `supabase/seed.sql`. Demo imagery uses picsum seeds for reliable loading.
abstract final class DemoData {
  static String _img(String seed) => 'https://picsum.photos/seed/$seed/900/1200';

  static List<Product> products() => [
        Product(
          id: '11111111-1111-1111-1111-111111111111',
          slug: 'cashmere-turtleneck',
          title: 'Cashmere Turtleneck',
          description:
              'A whisper-soft grade-A Mongolian cashmere turtleneck with a relaxed, '
              'elongated silhouette. Fully fashioned seams and a ribbed funnel neck.',
          category: 'Knitwear',
          basePrice: 245,
          isFeatured: true,
          groups: [
            VariantGroup(
              id: 'a1-midnight',
              productId: '11111111-1111-1111-1111-111111111111',
              name: 'Midnight Blue',
              colorHex: '#1E2A44',
              groupImages: [_img('vf-cash-midnight-1'), _img('vf-cash-midnight-2')],
              sortOrder: 0,
              items: const [
                VariantItem(id: 'i-cb-s', groupId: 'a1-midnight', sku: 'CASH-TURT-BLU-S', sizeLabel: 'S', stockQuantity: 12),
                VariantItem(id: 'i-cb-m', groupId: 'a1-midnight', sku: 'CASH-TURT-BLU-M', sizeLabel: 'M', stockQuantity: 8),
                VariantItem(id: 'i-cb-l', groupId: 'a1-midnight', sku: 'CASH-TURT-BLU-L', sizeLabel: 'L', stockQuantity: 3),
                VariantItem(id: 'i-cb-xl', groupId: 'a1-midnight', sku: 'CASH-TURT-BLU-XL', sizeLabel: 'XL', stockQuantity: 0, priceOverride: 255),
              ],
            ),
            VariantGroup(
              id: 'a1-crimson',
              productId: '11111111-1111-1111-1111-111111111111',
              name: 'Crimson',
              colorHex: '#8C1C2B',
              groupImages: [_img('vf-cash-crimson-1')],
              sortOrder: 1,
              items: const [
                VariantItem(id: 'i-cc-s', groupId: 'a1-crimson', sku: 'CASH-TURT-CRM-S', sizeLabel: 'S', stockQuantity: 5),
                VariantItem(id: 'i-cc-m', groupId: 'a1-crimson', sku: 'CASH-TURT-CRM-M', sizeLabel: 'M', stockQuantity: 9),
                VariantItem(id: 'i-cc-l', groupId: 'a1-crimson', sku: 'CASH-TURT-CRM-L', sizeLabel: 'L', stockQuantity: 6),
              ],
            ),
            VariantGroup(
              id: 'a1-oatmeal',
              productId: '11111111-1111-1111-1111-111111111111',
              name: 'Oatmeal',
              colorHex: '#D8CDB8',
              groupImages: [_img('vf-cash-oatmeal-1')],
              sortOrder: 2,
              items: const [
                VariantItem(id: 'i-co-m', groupId: 'a1-oatmeal', sku: 'CASH-TURT-OAT-M', sizeLabel: 'M', stockQuantity: 14),
                VariantItem(id: 'i-co-l', groupId: 'a1-oatmeal', sku: 'CASH-TURT-OAT-L', sizeLabel: 'L', stockQuantity: 11),
              ],
            ),
          ],
        ),
        Product(
          id: '22222222-2222-2222-2222-222222222222',
          slug: 'tailored-wool-trouser',
          title: 'Tailored Wool Trouser',
          description:
              'Italian virgin-wool trousers with a mid-rise waist, pressed crease, and '
              'tapered ankle. Sartorial by day, effortless by night.',
          category: 'Trousers',
          basePrice: 189,
          isFeatured: true,
          groups: [
            VariantGroup(
              id: 'a2-charcoal',
              productId: '22222222-2222-2222-2222-222222222222',
              name: 'Charcoal',
              colorHex: '#36373B',
              groupImages: [_img('vf-trou-charcoal-1')],
              sortOrder: 0,
              items: const [
                VariantItem(id: 'i-tc-30', groupId: 'a2-charcoal', sku: 'WOOL-TROU-CHR-30', sizeLabel: '30', stockQuantity: 10),
                VariantItem(id: 'i-tc-32', groupId: 'a2-charcoal', sku: 'WOOL-TROU-CHR-32', sizeLabel: '32', stockQuantity: 7),
                VariantItem(id: 'i-tc-34', groupId: 'a2-charcoal', sku: 'WOOL-TROU-CHR-34', sizeLabel: '34', stockQuantity: 4),
              ],
            ),
            VariantGroup(
              id: 'a2-camel',
              productId: '22222222-2222-2222-2222-222222222222',
              name: 'Camel',
              colorHex: '#C19A6B',
              groupImages: [_img('vf-trou-camel-1')],
              sortOrder: 1,
              items: const [
                VariantItem(id: 'i-tm-32', groupId: 'a2-camel', sku: 'WOOL-TROU-CAM-32', sizeLabel: '32', stockQuantity: 6),
                VariantItem(id: 'i-tm-34', groupId: 'a2-camel', sku: 'WOOL-TROU-CAM-34', sizeLabel: '34', stockQuantity: 2),
              ],
            ),
          ],
        ),
        Product(
          id: '33333333-3333-3333-3333-333333333333',
          slug: 'silk-slip-dress',
          title: 'Bias-Cut Silk Slip Dress',
          description:
              '100% mulberry silk cut on the bias to skim the body. Adjustable straps '
              'and a cowl neckline.',
          category: 'Dresses',
          basePrice: 320,
          isFeatured: true,
          groups: [
            VariantGroup(
              id: 'a3-champagne',
              productId: '33333333-3333-3333-3333-333333333333',
              name: 'Champagne',
              colorHex: '#E7D3B3',
              groupImages: [_img('vf-slip-champagne-1')],
              sortOrder: 0,
              items: const [
                VariantItem(id: 'i-sc-xs', groupId: 'a3-champagne', sku: 'SILK-SLIP-CHA-XS', sizeLabel: 'XS', stockQuantity: 6),
                VariantItem(id: 'i-sc-s', groupId: 'a3-champagne', sku: 'SILK-SLIP-CHA-S', sizeLabel: 'S', stockQuantity: 9),
                VariantItem(id: 'i-sc-m', groupId: 'a3-champagne', sku: 'SILK-SLIP-CHA-M', sizeLabel: 'M', stockQuantity: 5),
              ],
            ),
            VariantGroup(
              id: 'a3-onyx',
              productId: '33333333-3333-3333-3333-333333333333',
              name: 'Onyx',
              colorHex: '#14141A',
              groupImages: [_img('vf-slip-onyx-1')],
              sortOrder: 1,
              items: const [
                VariantItem(id: 'i-so-s', groupId: 'a3-onyx', sku: 'SILK-SLIP-ONX-S', sizeLabel: 'S', stockQuantity: 8),
                VariantItem(id: 'i-so-m', groupId: 'a3-onyx', sku: 'SILK-SLIP-ONX-M', sizeLabel: 'M', stockQuantity: 7),
              ],
            ),
          ],
        ),
        Product(
          id: '44444444-4444-4444-4444-444444444444',
          slug: 'structured-trench',
          title: 'Structured Cotton Trench',
          description:
              'A water-resistant cotton-gabardine trench with storm flaps, a removable '
              'belt, and horn buttons.',
          category: 'Outerwear',
          basePrice: 410,
          groups: [
            VariantGroup(
              id: 'a4-sand',
              productId: '44444444-4444-4444-4444-444444444444',
              name: 'Sand',
              colorHex: '#C9B79C',
              groupImages: [_img('vf-trench-sand-1'), _img('vf-trench-sand-2')],
              sortOrder: 0,
              items: const [
                VariantItem(id: 'i-ts-s', groupId: 'a4-sand', sku: 'TRENCH-SND-S', sizeLabel: 'S', stockQuantity: 4),
                VariantItem(id: 'i-ts-m', groupId: 'a4-sand', sku: 'TRENCH-SND-M', sizeLabel: 'M', stockQuantity: 5),
                VariantItem(id: 'i-ts-l', groupId: 'a4-sand', sku: 'TRENCH-SND-L', sizeLabel: 'L', stockQuantity: 3),
              ],
            ),
          ],
        ),
      ];

  static List<Promotion> promotions() {
    final now = DateTime.now();
    return [
      Promotion(
        id: 'promo-fall20',
        code: 'FALL20',
        description: '20% off orders over \$150',
        discountType: DiscountType.percentage,
        discountValue: 20,
        minOrderValue: 150,
        validFrom: now.subtract(const Duration(days: 1)),
        validUntil: now.add(const Duration(days: 60)),
      ),
      Promotion(
        id: 'promo-welcome15',
        code: 'WELCOME15',
        description: '\$15 off your first order',
        discountType: DiscountType.fixedAmount,
        discountValue: 15,
        minOrderValue: 75,
        usageLimit: 1000,
        usageCount: 214,
        validFrom: now.subtract(const Duration(days: 1)),
        validUntil: now.add(const Duration(days: 365)),
      ),
      Promotion(
        id: 'promo-freeship',
        code: 'FREESHIP',
        description: 'Free shipping over \$100',
        discountType: DiscountType.freeShipping,
        discountValue: 0,
        minOrderValue: 100,
        validFrom: now.subtract(const Duration(days: 1)),
        validUntil: now.add(const Duration(days: 30)),
      ),
      Promotion(
        id: 'promo-knit25',
        code: 'KNIT25',
        description: '25% off all knitwear',
        discountType: DiscountType.percentage,
        discountValue: 25,
        includedCategories: const ['Knitwear'],
        validFrom: now.subtract(const Duration(days: 1)),
        validUntil: now.add(const Duration(days: 14)),
      ),
    ];
  }

  /// Local mirror of the SQL `validate_promotion` function for demo mode.
  static PromoValidation validatePromo(String code, double subtotal, List<String> categories) {
    final promo = promotions().where((p) => p.code.toUpperCase() == code.toUpperCase()).firstOrNull;
    if (promo == null) return PromoValidation.invalid('Code not found');
    if (!promo.isActive) return PromoValidation.invalid('Promotion inactive');
    if (promo.isScheduled) return PromoValidation.invalid('Promotion not yet active');
    if (promo.isExpired) return PromoValidation.invalid('Promotion expired');
    if (promo.usageExhausted) return PromoValidation.invalid('Usage limit reached');
    if (subtotal < promo.minOrderValue) {
      return PromoValidation.invalid('Requires a minimum order of \$${promo.minOrderValue.toStringAsFixed(0)}');
    }
    if (promo.includedCategories.isNotEmpty &&
        !categories.any(promo.includedCategories.contains)) {
      return PromoValidation.invalid('No eligible items in cart');
    }
    if (promo.excludedCategories.isNotEmpty &&
        categories.any(promo.excludedCategories.contains)) {
      return PromoValidation.invalid('Cart contains excluded items');
    }

    double discount = 0;
    bool freeShip = false;
    switch (promo.discountType) {
      case DiscountType.percentage:
        discount = (subtotal * promo.discountValue / 100);
        discount = double.parse(discount.toStringAsFixed(2));
        break;
      case DiscountType.fixedAmount:
        discount = promo.discountValue < subtotal ? promo.discountValue : subtotal;
        break;
      case DiscountType.freeShipping:
        freeShip = true;
        break;
    }
    return PromoValidation(
      valid: true,
      promotionId: promo.id,
      code: promo.code,
      discountType: promo.discountType,
      discountAmount: discount,
      freeShipping: freeShip,
      description: promo.description,
    );
  }
}
