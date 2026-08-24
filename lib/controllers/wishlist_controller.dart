import 'package:get/get.dart';

import '../core/utils/app_constants.dart';
import '../core/utils/demo_data.dart';
import '../core/utils/supabase_service.dart';
import '../models/product_model.dart';
import 'auth_controller.dart';
import 'catalog_controller.dart';

/// Owns the customer wishlist. The saved ids are the source of truth; the
/// products behind them are resolved separately, because a saved piece may not
/// be in the catalogue listing at all — that query asks only for active rows,
/// so a product taken off sale would otherwise disappear from the wishlist
/// while still being counted in the header badge.
class WishlistController extends GetxController {
  final RxSet<String> wishlistProductIds = <String>{}.obs;
  final RxBool isLoading = false.obs;

  /// Resolved products for [wishlistProductIds], in the order they were saved.
  final RxList<Product> savedProducts = <Product>[].obs;

  /// Saved pieces whose product could not be resolved — retired, or not yet
  /// loaded. Surfaced so the page can account for the difference rather than
  /// quietly showing fewer items than the badge claims.
  final RxInt unavailableCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final auth = Get.find<AuthController>();
    ever(auth.user, (_) => fetchWishlist());
    // Re-resolve when the catalogue changes: a product that arrives later
    // should fill in without the shopper reloading.
    ever(Get.find<CatalogController>().products, (_) => _resolve());
    ever(wishlistProductIds, (_) => _resolve());
    fetchWishlist();
  }

  Future<void> fetchWishlist() async {
    final user = Get.find<AuthController>().user.value;

    // Signing out has to empty the wishlist, not just stop refreshing it.
    // These ids belong to the account that saved them: leaving them behind
    // shows the next person to use this browser the previous shopper's saved
    // pieces, and the `catch` below would keep showing them even after their
    // own fetch failed.
    if (user == null) {
      wishlistProductIds.clear();
      savedProducts.clear();
      unavailableCount.value = 0;
      return;
    }

    if (!SupabaseService.isReady) {
      await _resolve();
      return;
    }

    isLoading.value = true;
    try {
      final rows = await SupabaseService.client
          .from(AppConstants.tblWishlists)
          .select('product_id')
          .eq('user_id', user.id);
      // The account can change while this is in flight -- sign out, or sign in
      // as someone else. Dropping a response that outlived its owner keeps a
      // slow request for the previous user from overwriting the current one.
      if (Get.find<AuthController>().user.value?.id != user.id) return;
      wishlistProductIds.assignAll(
        (rows as List).map((r) => r['product_id'].toString()),
      );
    } catch (_) {
      // Keep whatever is already saved on a network failure.
    } finally {
      isLoading.value = false;
    }
    await _resolve();
  }

  /// Match saved ids to products: the catalogue first, then a direct lookup for
  /// anything it does not carry.
  Future<void> _resolve() async {
    if (wishlistProductIds.isEmpty) {
      savedProducts.clear();
      unavailableCount.value = 0;
      return;
    }

    final byId = <String, Product>{
      for (final p in Get.find<CatalogController>().products)
        if (wishlistProductIds.contains(p.id)) p.id: p,
    };

    final missing = wishlistProductIds
        .where((id) => !byId.containsKey(id))
        .toList();
    if (missing.isNotEmpty) {
      for (final p in await _lookup(missing)) {
        byId[p.id] = p;
      }
    }

    savedProducts.assignAll(
      wishlistProductIds.map((id) => byId[id]).whereType<Product>(),
    );
    unavailableCount.value = wishlistProductIds.length - savedProducts.length;
  }

  /// Fetch products the catalogue listing does not hold — including inactive
  /// ones, which the storefront query filters out.
  Future<List<Product>> _lookup(List<String> ids) async {
    if (!SupabaseService.isReady) {
      return DemoData.products().where((p) => ids.contains(p.id)).toList();
    }
    try {
      final rows = await SupabaseService.client
          .from(AppConstants.tblProducts)
          .select('*, variant_groups(*, variant_items(*))')
          .inFilter('id', ids);
      return (rows as List)
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  bool isSaved(String productId) => wishlistProductIds.contains(productId);

  Future<void> toggle(Product product) async {
    final wasSaved = isSaved(product.id);
    if (wasSaved) {
      wishlistProductIds.remove(product.id);
    } else {
      wishlistProductIds.add(product.id);
    }

    final user = Get.find<AuthController>().user.value;
    if (user == null || !SupabaseService.isReady) return;

    try {
      if (wasSaved) {
        await SupabaseService.client
            .from(AppConstants.tblWishlists)
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', product.id);
      } else {
        await SupabaseService.client.from(AppConstants.tblWishlists).insert({
          'user_id': user.id,
          'product_id': product.id,
        });
      }
    } catch (_) {
      // Put the optimistic change back the way it was.
      if (wasSaved) {
        wishlistProductIds.add(product.id);
      } else {
        wishlistProductIds.remove(product.id);
      }
    }
  }

  /// How many pieces are saved. This is the badge figure, and it counts saved
  /// ids — not resolved products — so it never disagrees with the wishlist.
  int get count => wishlistProductIds.length;
  bool get isEmpty => wishlistProductIds.isEmpty;
}
