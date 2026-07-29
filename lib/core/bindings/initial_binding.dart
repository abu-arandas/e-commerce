import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/catalog_controller.dart';
import '../../controllers/orders_controller.dart';

/// Registers the app's controllers up front. Storefront controllers are eager
/// (they drive the first paint); the [AdminController] is lazy (`fenix`) so its
/// analytics/CMS logic is only instantiated when the admin panel is opened —
/// mirroring the PRD §6.1 goal of keeping heavy admin logic off the initial
/// storefront path.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    final orders = Get.put<OrdersController>(OrdersController(), permanent: true);
    Get.put<AuthController>(
      AuthController(onSignedOut: orders.clear),
      permanent: true,
    );
    Get.put<CartController>(
      CartController(onOrderPlaced: orders.record),
      permanent: true,
    );
    Get.put<CatalogController>(CatalogController(), permanent: true);
    Get.lazyPut<AdminController>(() => AdminController(), fenix: true);
  }
}
