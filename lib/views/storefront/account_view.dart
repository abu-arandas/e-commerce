import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/orders_controller.dart';
import '../../controllers/wishlist_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/bootstrap5.dart';
import '../../core/utils/formatters.dart';
import '../shared/storefront_scaffold.dart';
import '../shared/ui_kit.dart';

class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final wishlist = Get.find<WishlistController>();

    return StorefrontScaffold(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.md),
        child: FB5Container(
          child: Obx(() {
            final user = auth.user.value;
            if (user == null) {
              return EmptyState(
                icon: Icons.person_outline,
                title: 'You are signed out',
                message: 'Sign in to view your profile and orders.',
                action: GoldButton(label: 'Sign in', onPressed: () => Get.toNamed(AppRoutes.login)),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(eyebrow: 'Your account', title: 'Profile'),
                const SizedBox(height: AppSpacing.lg),
                FB5Row(
                  classNames: 'gx-4 gy-4',
                  children: [
                    FB5Col(
                      classNames: 'col-12 col-lg-4',
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: const BorderRadius.all(AppSpacing.rMd),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: AppColors.ink,
                                      child: Text(user.initials,
                                          style: const TextStyle(color: AppColors.textOnInk, fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(user.displayName, style: Theme.of(context).textTheme.titleLarge),
                                          Text(user.email,
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Chip(label: Text(user.role.label)),
                                const SizedBox(height: AppSpacing.md),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.favorite_outline, color: AppColors.ink),
                                  title: const Text('Saved Wishlist'),
                                  subtitle: Text('${wishlist.count} items'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Get.toNamed(AppRoutes.wishlist),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                if (auth.isStaff) ...[
                                  GoldButton(
                                    label: 'Open admin panel',
                                    expand: true,
                                    icon: Icons.dashboard_customize_outlined,
                                    onPressed: () => Get.toNamed(AppRoutes.adminDashboard),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                ],
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await auth.signOut();
                                    Get.offNamed(AppRoutes.home);
                                  },
                                  icon: const Icon(Icons.logout, size: 18),
                                  label: const Text('Sign out'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    FB5Col(
                      classNames: 'col-12 col-lg-8',
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: const BorderRadius.all(AppSpacing.rMd),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order History', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: AppSpacing.md),
                            const _OrderHistoryList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _OrderHistoryList extends StatefulWidget {
  const _OrderHistoryList();

  @override
  State<_OrderHistoryList> createState() => _OrderHistoryListState();
}

class _OrderHistoryListState extends State<_OrderHistoryList> {
  final OrdersController orders = Get.find<OrdersController>();

  @override
  void initState() {
    super.initState();
    // The shopper's own orders, scoped by RLS to the signed-in user. This used
    // to read AdminController.orders, which is the back-office view of *every*
    // order in the store.
    WidgetsBinding.instance.addPostFrameCallback((_) => orders.fetch());
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (orders.isLoading.value && orders.orders.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator(color: AppColors.ink)),
        );
      }
      final list = orders.orders;
      if (list.isEmpty) {
        return const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No orders yet',
          message: 'Your order history will appear here once you make a purchase.',
        );
      }

      return Column(
        children: [
          for (final o in list)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ExpansionTile(
                title: Row(
                  children: [
                    Text('Order ${o.reference}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: AppSpacing.sm),
                    _statusBadge(o.status.label),
                  ],
                ),
                subtitle: Text(
                  '${Formatters.date(o.createdAt ?? DateTime.now())} · ${o.lines.length} item(s)',
                  style: const TextStyle(color: AppColors.slate, fontSize: 12),
                ),
                trailing: Text(
                  Formatters.price(o.grandTotal),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in o.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('${line.productTitle} (${line.variantSummary}) x${line.quantity}'),
                                ),
                                Text(Formatters.price(line.lineTotal)),
                              ],
                            ),
                          ),
                        const Divider(),
                        if (o.trackingNumber != null)
                          Text('Tracking: ${o.trackingNumber}',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.goldDeep)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _statusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
    );
  }
}
