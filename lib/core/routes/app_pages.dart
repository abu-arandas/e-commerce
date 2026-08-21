import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/widgets.dart';

import '../../controllers/auth_controller.dart';
import '../../views/admin/admin_dashboard_view.dart';
import '../../views/admin/admin_orders_view.dart';
import '../../views/admin/product_manager_view.dart';
import '../../views/admin/promotion_builder_view.dart';
import '../../views/storefront/account_view.dart';
import '../../views/storefront/cart_view.dart';
import '../../views/storefront/checkout_view.dart';
import '../../views/storefront/home_view.dart';
import '../../views/storefront/login_view.dart';
import '../../views/storefront/order_confirmation_view.dart';
import '../../views/storefront/product_detail_view.dart';
import '../../views/storefront/shop_view.dart';
import '../../views/storefront/wishlist_view.dart';
import 'app_routes.dart';

/// Redirects non-staff away from admin routes to the sign-in page.
class _StaffGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthController>();
    return auth.isStaff ? null : const RouteSettings(name: AppRoutes.login);
  }
}

abstract final class AppPages {
  static final List<GetPage> routes = [
    // ---- Storefront ----
    GetPage(
        name: AppRoutes.home,
        page: () => const HomeView(),
        transition: Transition.fadeIn),
    GetPage(
        name: AppRoutes.shop,
        page: () => const ShopView(),
        transition: Transition.fadeIn),
    GetPage(
        name: AppRoutes.product,
        page: () => const ProductDetailView(),
        transition: Transition.fadeIn),
    GetPage(
        name: AppRoutes.cart,
        page: () => const CartView(),
        transition: Transition.fadeIn),
    GetPage(
        name: AppRoutes.checkout,
        page: () => const CheckoutView(),
        transition: Transition.fadeIn),
    GetPage(
        name: AppRoutes.orderConfirmation,
        page: () => const OrderConfirmationView()),
    GetPage(
        name: AppRoutes.login,
        page: () => const LoginView(),
        transition: Transition.fadeIn),
    GetPage(
        name: AppRoutes.account,
        page: () => const AccountView(),
        transition: Transition.fadeIn),
    GetPage(
        name: AppRoutes.wishlist,
        page: () => const WishlistView(),
        transition: Transition.fadeIn),

    // ---- Admin (staff-gated) ----
    GetPage(
      name: AppRoutes.adminDashboard,
      page: () => const AdminDashboardView(),
      middlewares: [_StaffGuard()],
    ),
    GetPage(
      name: AppRoutes.adminProducts,
      page: () => const ProductManagerView(),
      middlewares: [_StaffGuard()],
    ),
    GetPage(
      name: AppRoutes.adminPromotions,
      page: () => const PromotionBuilderView(),
      middlewares: [_StaffGuard()],
    ),
    GetPage(
      name: AppRoutes.adminOrders,
      page: () => const AdminOrdersView(),
      middlewares: [_StaffGuard()],
    ),
  ];
}
