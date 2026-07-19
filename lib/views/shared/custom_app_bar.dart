import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/bootstrap5.dart';

/// Responsive top navigation (PRD §6.2): a hamburger below `md`, transitioning to
/// inline links at `md` and up. Sticky, hairline-bordered, with a live cart badge.
class VanguardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VanguardAppBar({super.key});

  static const double _height = 68;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    final auth = Get.find<AuthController>();

    return Material(
      color: AppColors.surface,
      elevation: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: SizedBox(
          height: _height,
          child: FB5Container.fluid(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            alignment: Alignment.center,
            child: Row(
              children: [
                // Leading: hamburger on mobile only.
                if (context.isMobile)
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    tooltip: 'Menu',
                  ),
                _Wordmark(onTap: () => _go(AppRoutes.home)),
                const Spacer(),
                if (!context.isMobile) ...[
                  _NavLink('Shop', () => _go(AppRoutes.shop)),
                  _NavLink('Knitwear', () => _goShop('Knitwear')),
                  _NavLink('Dresses', () => _goShop('Dresses')),
                  _NavLink('Outerwear', () => _goShop('Outerwear')),
                  const SizedBox(width: AppSpacing.sm),
                ],
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search',
                  onPressed: () => _go(AppRoutes.shop),
                ),
                Obx(() {
                  final staff = auth.isStaff;
                  return staff
                      ? IconButton(
                          icon: const Icon(Icons.dashboard_customize_outlined),
                          tooltip: 'Admin',
                          onPressed: () => _go(AppRoutes.adminDashboard),
                        )
                      : const SizedBox.shrink();
                }),
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  tooltip: 'Account',
                  onPressed: () =>
                      _go(auth.isLoggedIn ? AppRoutes.account : AppRoutes.login),
                ),
                _CartButton(cart: cart),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _go(String route) => Get.toNamed(route);
  void _goShop(String category) => Get.toNamed('${AppRoutes.shop}?category=$category');
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('VANGUARD', style: AppTypography.wordmark(size: context.isMobile ? 20 : 24)),
            const SizedBox(width: 6),
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: AppColors.ink),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.cart});
  final CartController cart;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = cart.itemCount;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined),
            tooltip: 'Cart',
            onPressed: () => Get.toNamed(AppRoutes.cart),
          ),
          if (count > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$count',
                    style: const TextStyle(color: AppColors.ink, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      );
    });
  }
}

/// Slide-in navigation for mobile viewports.
class VanguardNavDrawer extends StatelessWidget {
  const VanguardNavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text('VANGUARD', style: AppTypography.wordmark()),
            ),
            const Divider(),
            _tile(context, Icons.home_outlined, 'Home', AppRoutes.home),
            _tile(context, Icons.grid_view_outlined, 'Shop all', AppRoutes.shop),
            _tile(context, Icons.checkroom_outlined, 'Knitwear', '${AppRoutes.shop}?category=Knitwear'),
            _tile(context, Icons.dry_cleaning_outlined, 'Dresses', '${AppRoutes.shop}?category=Dresses'),
            _tile(context, Icons.ac_unit_outlined, 'Outerwear', '${AppRoutes.shop}?category=Outerwear'),
            const Divider(),
            _tile(context, Icons.shopping_bag_outlined, 'Cart', AppRoutes.cart),
            Obx(() => _tile(
                  context,
                  Icons.person_outline,
                  auth.isLoggedIn ? 'Account' : 'Sign in',
                  auth.isLoggedIn ? AppRoutes.account : AppRoutes.login,
                )),
            Obx(() => auth.isStaff
                ? _tile(context, Icons.dashboard_customize_outlined, 'Admin panel', AppRoutes.adminDashboard)
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String route) => ListTile(
        leading: Icon(icon, color: AppColors.ink),
        title: Text(label, style: Theme.of(context).textTheme.titleMedium),
        onTap: () {
          Navigator.of(context).pop();
          Get.toNamed(route);
        },
      );
}
