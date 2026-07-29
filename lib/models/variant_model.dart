import '../core/utils/app_constants.dart';
import '../core/utils/json_parse.dart';

/// Level 2 (PRD §5.3) — the deepest node and the actual purchasable unit.
/// Carries the unique SKU, size, optional price override, and stock.
class VariantItem {
  const VariantItem({
    required this.id,
    required this.groupId,
    required this.sku,
    required this.sizeLabel,
    required this.stockQuantity,
    this.priceOverride,
    this.lowStockThreshold = AppConstants.lowStockThreshold,
    this.sortOrder = 0,
  });

  final String id;
  final String groupId;
  final String sku;
  final String sizeLabel;
  final double? priceOverride;
  final int stockQuantity;
  final int lowStockThreshold;
  final int sortOrder;

  bool get inStock => stockQuantity > 0;
  bool get isLowStock => stockQuantity > 0 && stockQuantity <= lowStockThreshold;

  /// Effective unit price given the parent product's [basePrice].
  double effectivePrice(double basePrice) => priceOverride ?? basePrice;

  factory VariantItem.fromJson(Map<String, dynamic> json) => VariantItem(
        id: J.str(json['id']),
        groupId: J.str(json['group_id']),
        sku: J.str(json['sku']),
        sizeLabel: J.str(json['size_label']),
        priceOverride: J.toDoubleOrNull(json['price_override']),
        stockQuantity: J.toInt(json['stock_quantity']),
        lowStockThreshold:
            J.toInt(json['low_stock_threshold'], AppConstants.lowStockThreshold),
        sortOrder: J.toInt(json['sort_order']),
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'group_id': groupId,
        'sku': sku,
        'size_label': sizeLabel,
        'price_override': priceOverride,
        'stock_quantity': stockQuantity,
        'low_stock_threshold': lowStockThreshold,
        'sort_order': sortOrder,
      };

  VariantItem copyWith({int? stockQuantity, double? priceOverride, String? sizeLabel, String? sku}) =>
      VariantItem(
        id: id,
        groupId: groupId,
        sku: sku ?? this.sku,
        sizeLabel: sizeLabel ?? this.sizeLabel,
        priceOverride: priceOverride ?? this.priceOverride,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        lowStockThreshold: lowStockThreshold,
        sortOrder: sortOrder,
      );
}

/// Level 1 (PRD §5.2) — a colour group holding colour-specific imagery and the
/// set of size variants beneath it.
class VariantGroup {
  const VariantGroup({
    required this.id,
    required this.productId,
    required this.name,
    this.colorHex,
    this.groupImages = const [],
    this.items = const [],
    this.sortOrder = 0,
  });

  final String id;
  final String productId;
  final String name;
  final String? colorHex;
  final List<String> groupImages;
  final List<VariantItem> items;
  final int sortOrder;

  /// URL-safe slug for deep-linking a colour (`?color=midnight-blue`).
  String get slug => name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  String? get primaryImage => groupImages.isNotEmpty ? groupImages.first : null;

  bool get hasStock => items.any((i) => i.inStock);
  int get totalStock => items.fold(0, (sum, i) => sum + i.stockQuantity);

  List<VariantItem> get sortedItems =>
      [...items]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  factory VariantGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['variant_items'] as List?) ?? const [];
    return VariantGroup(
      id: J.str(json['id']),
      productId: J.str(json['product_id']),
      name: J.str(json['name']),
      colorHex: J.strOrNull(json['color_hex']),
      groupImages: J.strList(json['group_images']),
      items: rawItems
          .map((e) => VariantItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      sortOrder: J.toInt(json['sort_order']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'product_id': productId,
        'name': name,
        'color_hex': colorHex,
        'group_images': groupImages,
        'sort_order': sortOrder,
      };

  /// This group plus its size variants, for the `save_product` RPC.
  Map<String, dynamic> toRpcJson() => {
        ...toJson(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  VariantGroup copyWith({
    String? name,
    String? colorHex,
    List<String>? groupImages,
    List<VariantItem>? items,
  }) =>
      VariantGroup(
        id: id,
        productId: productId,
        name: name ?? this.name,
        colorHex: colorHex ?? this.colorHex,
        groupImages: groupImages ?? this.groupImages,
        items: items ?? this.items,
        sortOrder: sortOrder,
      );
}
