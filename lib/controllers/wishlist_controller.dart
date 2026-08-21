import 'package:get/get.dart';
import '../core/utils/app_constants.dart';
import '../core/utils/supabase_service.dart';
import '../models/product_model.dart';
import 'auth_controller.dart';
import 'catalog_controller.dart';

/// Owns the customer wishlist state. Integrates with Supabase `wishlists` table
/// when logged in & connected, with instant reactive fallback state.
class WishlistController extends GetxController {
  final RxSet<String> wishlistProductIds = <String>{}.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Re-sync when user session changes
    final auth = Get.find<AuthController>();
    ever(auth.user, (_) => fetchWishlist());
    fetchWishlist();
  }

  Future<void> fetchWishlist() async {
    final auth = Get.find<AuthController>();
    final user = auth.user.value;
    if (user == null || !SupabaseService.isReady) {
      return;
    }
    isLoading.value = true;
    try {
      final rows = await SupabaseService.client
          .from(AppConstants.tblWishlists)
          .select('product_id')
          .eq('user_id', user.id);
      final ids = (rows as List).map((r) => r['product_id'] as String).toSet();
      wishlistProductIds.assignAll(ids);
    } catch (_) {
      // keep current state on network failure
    } finally {
      isLoading.value = false;
    }
  }

  bool isSaved(String productId) => wishlistProductIds.contains(productId);

  Future<void> toggle(Product product) async {
    final isCurrentlySaved = isSaved(product.id);
    if (isCurrentlySaved) {
      wishlistProductIds.remove(product.id);
    } else {
      wishlistProductIds.add(product.id);
    }

    final auth = Get.find<AuthController>();
    final user = auth.user.value;
    if (user != null && SupabaseService.isReady) {
      try {
        if (isCurrentlySaved) {
          await SupabaseService.client
              .from(AppConstants.tblWishlists)
              .delete()
              .eq('user_id', user.id)
              .eq('product_id', product.id);
        } else {
          await SupabaseService.client
              .from(AppConstants.tblWishlists)
              .insert({'user_id': user.id, 'product_id': product.id});
        }
      } catch (_) {
        // Revert on remote error
        if (isCurrentlySaved) {
          wishlistProductIds.add(product.id);
        } else {
          wishlistProductIds.remove(product.id);
        }
      }
    }
  }

  List<Product> get savedProducts {
    final catalog = Get.find<CatalogController>();
    return catalog.products
        .where((p) => wishlistProductIds.contains(p.id))
        .toList();
  }

  int get count => wishlistProductIds.length;
  bool get isEmpty => wishlistProductIds.isEmpty;
}
