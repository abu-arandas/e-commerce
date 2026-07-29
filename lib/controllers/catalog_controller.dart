import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../core/routes/app_routes.dart';
import '../core/utils/app_constants.dart';
import '../core/utils/browser/browser.dart';
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
  final RxString sort = 'featured'.obs; // featured | price_asc | price_desc | newest

  // ---- Product detail + nested selection ----
  final Rxn<Product> selected = Rxn<Product>();
  final Rxn<VariantGroup> selectedGroup = Rxn<VariantGroup>();
  final Rxn<VariantItem> selectedItem = Rxn<VariantItem>();
  final RxInt quantity = 1.obs;
  final RxInt activeImage = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
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
            .select(AppConstants.productTree)
            .eq('is_active', true)
            .order('created_at');
        products.assignAll(
          (rows as List)
              .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
        );
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 250)); // demo shimmer
        products.assignAll(DemoData.products());
      }
    } catch (e) {
      error.value = 'Could not load products: $e';
      if (products.isEmpty) products.assignAll(DemoData.products());
    } finally {
      isLoading.value = false;
    }
  }

  List<Product> get featured =>
      products.where((p) => p.isFeatured).toList();

  /// Products after category filter, search, and sort are applied.
  List<Product> get visibleProducts {
    var list = products.where((p) => p.isActive).toList();

    final cat = categoryFilter.value;
    if (cat != null && cat.isNotEmpty) {
      list = list.where((p) => p.category == cat).toList();
    }

    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              (p.category?.toLowerCase().contains(q) ?? false) ||
              p.description.toLowerCase().contains(q))
          .toList();
    }

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

  List<String> get availableCategories {
    final set = <String>{};
    for (final p in products) {
      if (p.category != null) set.add(p.category!);
    }
    return set.toList()..sort();
  }

  // ---------------------------------------------------------------------------
  // Product detail + nested variant selection
  // ---------------------------------------------------------------------------

  /// Load a product by slug (from the in-memory list, else fetch it), then seed
  /// the variant selection. [preselectColorSlug] supports deep links
  /// (`?color=midnight-blue`).
  Future<Product?> loadProduct(String slug, {String? preselectColorSlug}) async {
    // Drop the previous product first, otherwise navigating between two product
    // pages renders the old one until the new one resolves.
    if (selected.value?.slug != slug) {
      selected.value = null;
      selectedGroup.value = null;
      selectedItem.value = null;
    }

    Product? product = products.firstWhereOrNull((p) => p.slug == slug);

    if (product == null && SupabaseService.isReady) {
      try {
        final row = await SupabaseService.client
            .from(AppConstants.tblProducts)
            .select(AppConstants.productTree)
            .eq('slug', slug)
            .maybeSingle();
        if (row != null) {
          product = Product.fromJson(Map<String, dynamic>.from(row));
        }
      } catch (_) {/* fall through to demo */}
    }
    product ??= DemoData.products().firstWhereOrNull((p) => p.slug == slug);

    selected.value = product;
    if (product != null) {
      final group = (preselectColorSlug != null
              ? product.groupBySlug(preselectColorSlug)
              : null) ??
          product.sortedGroups.firstOrNull;
      _applyGroup(group);
    }
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

  /// User picked a colour — refresh available sizes/pricing/stock (PRD §3.1)
  /// and reflect the choice in the address bar so the exact colour is
  /// shareable, matching the `?color=` link the page accepts on the way in.
  ///
  /// `replaceState` is used rather than a route push: the selection is not a
  /// separate destination, and pushing would trap the shopper behind one back
  /// press per swatch they tried.
  void selectGroup(VariantGroup group) {
    _applyGroup(group);
    final product = selected.value;
    if (product != null) {
      Browser.replaceUrl(
        AppRoutes.productPath(product.slug, colorSlug: group.slug),
      );
    }
  }

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
  List<VariantItem> get availableSizes => selectedGroup.value?.sortedItems ?? const [];

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
