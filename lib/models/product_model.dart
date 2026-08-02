import '../core/utils/json_parse.dart';
import 'variant_model.dart';

/// The parent product container (PRD §5.1). Holds the colour [groups], each of
/// which holds its size-level [VariantItem]s.
class Product {
  Product({
    required this.id,
    required this.slug,
    required this.title,
    required this.basePrice,
    this.description = '',
    this.category,
    this.isActive = true,
    this.isFeatured = false,
    this.groups = const [],
    this.createdAt,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String? category;
  final double basePrice;
  final bool isActive;
  final bool isFeatured;
  final List<VariantGroup> groups;
  final DateTime? createdAt;

  // Cache fields for performance optimization
  double? _cachedFromPrice;
  double? _cachedMaxPrice;

  // ---- Derived pricing / stock ----

  List<VariantGroup> get sortedGroups =>
      [...groups]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Iterable<VariantItem> get allItems => groups.expand((g) => g.items);

  bool get hasVariants => groups.isNotEmpty;
  bool get inStock => allItems.any((i) => i.inStock) || (!hasVariants && isActive);
  int get totalStock => allItems.fold(0, (sum, i) => sum + i.stockQuantity);

  /// Lowest effective price across all variants (for "from $X" display).
  double get fromPrice {
    if (_cachedFromPrice != null) return _cachedFromPrice!;
    double? minPrice;
    for (final group in groups) {
      for (final item in group.items) {
        final price = item.effectivePrice(basePrice);
        if (minPrice == null || price < minPrice) {
          minPrice = price;
        }
      }
    }
    return _cachedFromPrice = (minPrice ?? basePrice);
  }

  double get maxPrice {
    if (_cachedMaxPrice != null) return _cachedMaxPrice!;
    double? maximumPrice;
    for (final group in groups) {
      for (final item in group.items) {
        final price = item.effectivePrice(basePrice);
        if (maximumPrice == null || price > maximumPrice) {
          maximumPrice = price;
        }
      }
    }
    return _cachedMaxPrice = (maximumPrice ?? basePrice);
  }

  bool get hasPriceRange => (maxPrice - fromPrice).abs() > 0.001;

  /// Primary hero image: first image of the first group, if any.
  String? get heroImage {
    for (final g in sortedGroups) {
      if (g.primaryImage != null) return g.primaryImage;
    }
    return null;
  }

  VariantGroup? groupBySlug(String slug) {
    for (final g in groups) {
      if (g.slug == slug) return g;
    }
    return null;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawGroups = (json['variant_groups'] as List?) ?? const [];
    return Product(
      id: J.str(json['id']),
      slug: J.str(json['slug']),
      title: J.str(json['title']),
      description: J.str(json['description']),
      category: J.strOrNull(json['category']),
      basePrice: J.toDouble(json['base_price']),
      isActive: J.toBool(json['is_active'], true),
      isFeatured: J.toBool(json['is_featured']),
      createdAt: J.dateOrNull(json['created_at']),
      groups: rawGroups
          .map((e) => VariantGroup.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'slug': slug,
        'title': title,
        'description': description,
        'category': category,
        'base_price': basePrice,
        'is_active': isActive,
        'is_featured': isFeatured,
      };

  Product copyWith({
    String? title,
    String? description,
    String? category,
    double? basePrice,
    bool? isActive,
    bool? isFeatured,
    List<VariantGroup>? groups,
  }) =>
      Product(
        id: id,
        slug: slug,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        basePrice: basePrice ?? this.basePrice,
        isActive: isActive ?? this.isActive,
        isFeatured: isFeatured ?? this.isFeatured,
        groups: groups ?? this.groups,
        createdAt: createdAt,
      );
}
