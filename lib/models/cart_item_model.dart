import '../core/utils/json_parse.dart';
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

  /// Restores a line from persisted JSON. Numerics go through [J] rather than
  /// a cast: a cart round-tripped through localStorage — or a row read back
  /// from Postgres, which serialises numeric columns as strings on some
  /// drivers — brings them back as text, and `as num?` throws on that.
  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: J.str(json['product_id']),
        productSlug: J.str(json['product_slug']),
        productTitle: J.str(json['product_title']),
        category: J.strOrNull(json['category']),
        variantGroupId: J.str(json['variant_group_id']),
        variantItemId: J.str(json['variant_item_id']),
        sku: J.str(json['sku']),
        colorName: J.str(json['color_name']),
        sizeLabel: J.str(json['size_label']),
        unitPrice: J.toDouble(json['unit_price']),
        imageUrl: J.strOrNull(json['image_url']),
        maxStock: J.toInt(json['max_stock'], 99),
        quantity: J.toInt(json['quantity'], 1),
      );
}
