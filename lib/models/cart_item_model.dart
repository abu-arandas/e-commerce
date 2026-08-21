import 'product_model.dart';
import 'variant_model.dart';

/// A line in the cart. Snapshots enough denormalised data (title, colour, size,
/// image, unit price) that the cart renders without re-fetching, while keeping
/// the [variantItemId] needed to place the order and decrement the exact SKU.
class CartItem {
  CartItem({
    required this.productId,
    required this.productSlug,
    required this.productTitle,
    required this.category,
    required this.variantGroupId,
    required this.variantItemId,
    required this.sku,
    required this.colorName,
    required this.sizeLabel,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
    this.maxStock = 99,
  });

  final String productId;
  final String productSlug;
  final String productTitle;
  final String? category;
  final String variantGroupId;
  final String variantItemId;
  final String sku;
  final String colorName;
  final String sizeLabel;
  final double unitPrice;
  final String? imageUrl;
  final int maxStock;

  int quantity;

  double get lineTotal => unitPrice * quantity;

  /// Stable identity for a cart line — the same SKU stacks rather than duplicates.
  String get key => variantItemId;

  /// Build a line from a resolved product/group/item selection.
  factory CartItem.from({
    required Product product,
    required VariantGroup group,
    required VariantItem item,
    int quantity = 1,
  }) =>
      CartItem(
        productId: product.id,
        productSlug: product.slug,
        productTitle: product.title,
        category: product.category,
        variantGroupId: group.id,
        variantItemId: item.id,
        sku: item.sku,
        colorName: group.name,
        sizeLabel: item.sizeLabel,
        unitPrice: item.effectivePrice(product.basePrice),
        imageUrl: group.primaryImage ?? product.heroImage,
        maxStock: item.stockQuantity,
        quantity: quantity,
      );

  Map<String, dynamic> toOrderLine() => {
        'variant_item_id': variantItemId,
        'quantity': quantity,
      };

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_slug': productSlug,
        'product_title': productTitle,
        'category': category,
        'variant_group_id': variantGroupId,
        'variant_item_id': variantItemId,
        'sku': sku,
        'color_name': colorName,
        'size_label': sizeLabel,
        'unit_price': unitPrice,
        'image_url': imageUrl,
        'max_stock': maxStock,
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: json['product_id']?.toString() ?? '',
        productSlug: json['product_slug']?.toString() ?? '',
        productTitle: json['product_title']?.toString() ?? '',
        category: json['category']?.toString(),
        variantGroupId: json['variant_group_id']?.toString() ?? '',
        variantItemId: json['variant_item_id']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        colorName: json['color_name']?.toString() ?? '',
        sizeLabel: json['size_label']?.toString() ?? '',
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
        imageUrl: json['image_url']?.toString(),
        maxStock: (json['max_stock'] as num?)?.toInt() ?? 99,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );
}
