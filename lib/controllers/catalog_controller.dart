import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../core/utils/app_constants.dart';
import '../core/utils/demo_data.dart';
import '../core/utils/supabase_service.dart';
import '../models/product_model.dart';
import '../models/variant_model.dart';

/// Owns the catalog: product listing, filtering/search, and — critically — the
/// nested variant selection state for the product detail page (PRD §3.1
/// "Nested Variant Selection").
class CatalogController extends GetxController {
  // ---- Listing state ----
  final RxList<Product> products = <Product>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  final RxnString categoryFilter = RxnString();
  final RxString searchQuery = ''.obs;
  final RxString sort =
      'featured'.obs; // featured | price_asc | price_desc | newest
  final RxList<String> _cachedCategories = <String>[].obs;

  // ---- Product detail + nested selection ----
  final Rxn<Product> selected = Rxn<Product>();
  final Rxn<VariantGroup> selectedGroup = Rxn<VariantGroup>();
  final Rxn<VariantItem> selectedItem = Rxn<VariantItem>();
  final RxInt quantity = 1.obs;
  final RxInt activeImage = 0.obs;

  @override
  void onInit() {
    super.onInit();
    // Recompute categories whenever products change
    ever(products, (_) => _updateAvailableCategories());
    fetchProducts();
  }

  void _updateAvailableCategories() {
    final set = <String>{};
    for (final p in products) {
      if (p.category != null) set.add(p.category!);
    }
    _cachedCategories.assignAll(set.toList()..sort());
  }

  // ---------------------------------------------------------------------------
  // Listing
  // ---------------------------------------------------------------------------
  Future<void> fetchProducts() async {
    isLoading.value = true;
    error.value = '';
    try {
      if (SupabaseService.isReady) {
        final rows = await SupabaseService.client
            .from(AppConstants.tblProducts)
            .select('*, variant_groups(*, variant_items(*))')
            .eq('is_active', true)
            .order('created_at');
        products.assignAll(
          (rows as List)
              .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
        );
      } else {
        await Future<void>.delayed(
            const Duration(milliseconds: 250)); // demo shimmer
        products.assignAll(DemoData.products());
      }
    } catch (e) {
      error.value = 'Could not load products: $e';
      if (products.isEmpty) products.assignAll(DemoData.products());
    } finally {
      isLoading.value = false;
    }
  }

  List<Product> get featured => products.where((p) => p.isFeatured).toList();

  /// Products after category filter, search, and sort are applied.
  List<Product> get visibleProducts {
    final cat = categoryFilter.value;
    final q = searchQuery.value.trim().toLowerCase();

    // Single-pass filter: chained .where().toList() allocated an intermediate
    // list per stage, on a getter that reruns on every keystroke.
    final list = products.where((p) {
      if (!p.isActive) return false;
      if (cat != null && cat.isNotEmpty && p.category != cat) return false;
      if (q.isNotEmpty) {
        if (!p.title.toLowerCase().contains(q) &&
            !(p.category?.toLowerCase().contains(q) ?? false) &&
            !p.description.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (sort.value) {
      case 'price_asc':
        list.sort((a, b) => a.fromPrice.compareTo(b.fromPrice));
        break;
      case 'price_desc':
        list.sort((a, b) => b.fromPrice.compareTo(a.fromPrice));
        break;
      case 'newest':
        list.sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        break;
      case 'featured':
      default:
        list.sort((a, b) {
          if (a.isFeatured == b.isFeatured) return 0;
          return a.isFeatured ? -1 : 1;
        });
    }
    return list;
  }

  void setCategory(String? category) => categoryFilter.value = category;
  void setSearch(String value) => searchQuery.value = value;
  void setSort(String value) => sort.value = value;

  List<String> get availableCategories => _cachedCategories.toList();

  // ---------------------------------------------------------------------------
  // Product detail + nested variant selection
  // ---------------------------------------------------------------------------

  /// Load a product by slug (from the in-memory list, else fetch it), then seed
  /// the variant selection. [preselectColorSlug] supports deep links
  /// (`?color=midnight-blue`).
  Future<Product?> loadProduct(String slug,
      {String? preselectColorSlug}) async {
    Product? product = products.firstWhereOrNull((p) => p.slug == slug);

    if (product == null && SupabaseService.isReady) {
      try {
        final row = await SupabaseService.client
            .from(AppConstants.tblProducts)
            .select('*, variant_groups(*, variant_items(*))')
            .eq('slug', slug)
            .maybeSingle();
        if (row != null) {
          product = Product.fromJson(Map<String, dynamic>.from(row));
        }
      } catch (_) {/* fall through to demo */}
    }
    product ??= DemoData.products().firstWhereOrNull((p) => p.slug == slug);

    selected.value = product;
    if (product == null) {
      // Clear the whole selection together. A stale group or size left behind a
      // null product is what made the page render the previous item's variants.
      _applyGroup(null);
      return null;
    }

    final group = (preselectColorSlug != null
            ? product.groupBySlug(preselectColorSlug)
            : null) ??
        product.sortedGroups.firstOrNull;
    _applyGroup(group);
    return product;
  }

  void _applyGroup(VariantGroup? group) {
    selectedGroup.value = group;
    activeImage.value = 0;
    quantity.value = 1;
    // Auto-select the first in-stock size, else the first size, else none.
    final items = group?.sortedItems ?? const <VariantItem>[];
    selectedItem.value =
        items.firstWhereOrNull((i) => i.inStock) ?? items.firstOrNull;
  }

  /// User picked a colour — refresh available sizes/pricing/stock (PRD §3.1).
  void selectGroup(VariantGroup group) => _applyGroup(group);

  /// User picked a size within the current colour.
  void selectSize(VariantItem item) {
    selectedItem.value = item;
    if (quantity.value > item.stockQuantity && item.stockQuantity > 0) {
      quantity.value = item.stockQuantity;
    }
  }

  void setActiveImage(int index) => activeImage.value = index;

  void incrementQty() {
    final max = selectedItem.value?.stockQuantity ?? 1;
    if (quantity.value < max) quantity.value++;
  }

  void decrementQty() {
    if (quantity.value > 1) quantity.value--;
  }

  // Derived selection state consumed by the detail view.
  List<VariantItem> get availableSizes =>
      selectedGroup.value?.sortedItems ?? const [];

  List<String> get activeImages {
    final imgs = selectedGroup.value?.groupImages ?? const <String>[];
    if (imgs.isNotEmpty) return imgs;
    final hero = selected.value?.heroImage;
    return hero != null ? [hero] : const [];
  }

  double get currentUnitPrice {
    final p = selected.value;
    if (p == null) return 0;
    final item = selectedItem.value;
    return item != null ? item.effectivePrice(p.basePrice) : p.fromPrice;
  }

  int get currentStock => selectedItem.value?.stockQuantity ?? 0;
  bool get canAddToCart => selectedItem.value != null && currentStock > 0;
}
