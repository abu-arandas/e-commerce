import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/orders_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/bootstrap5.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/seo/seo_service.dart';
import '../../models/order_model.dart';
import '../shared/storefront_scaffold.dart';
import '../shared/ui_kit.dart';

class AccountView extends StatefulWidget {
  const AccountView({super.key});

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  final AuthController auth = Get.find<AuthController>();
  final OrdersController orders = Get.find<OrdersController>();

  @override
  void initState() {
    super.initState();
    SeoService.update(
      title: 'Your account — Vanguard Fashion',
      description: 'Manage your Vanguard Fashion profile and review past orders.',
      canonicalPath: AppRoutes.account,
    );
    // Deferred so the first frame is not blocked on the network.
    WidgetsBinding.instance.addPostFrameCallback((_) => orders.fetch());
  }

  @override
  Widget build(BuildContext context) {
    return StorefrontScaffold(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xl, horizontal: AppSpacing.md),
        child: FB5Container(
          child: Obx(() {
            final user = auth.user.value;
            if (user == null) {
              return EmptyState(
                icon: Icons.person_outline,
                title: 'You are signed out',
                message: 'Sign in to view your profile and orders.',
                action: GoldButton(
                    label: 'Sign in',
                    onPressed: () => Get.toNamed(AppRoutes.login)),
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
                      child: _ProfileCard(auth: auth, onSignOut: _signOut),
                    ),
                    FB5Col(
                      classNames: 'col-12 col-lg-8',
                      child: _OrderHistory(orders: orders),
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

  Future<void> _signOut() async {
    await auth.signOut();
    Get.offAllNamed(AppRoutes.home);
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.auth, required this.onSignOut});
  final AuthController auth;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final user = auth.user.value!;
    return Container(
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
                    style: const TextStyle(
                        color: AppColors.textOnInk, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(user.email,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.slate)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Chip(label: Text(user.role.label)),
          const SizedBox(height: AppSpacing.md),
          if (auth.isStaff) ...[
            GoldButton(
              label: 'Open admin panel',
              expand: true,
              icon: Icons.dashboard_customize_outlined,
              onPressed: () => Get.toNamed(AppRoutes.adminDashboard),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _OrderHistory extends StatelessWidget {
  const _OrderHistory({required this.orders});
  final OrdersController orders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(AppSpacing.rMd),
        border: Border.all(color: AppColors.line),
      ),
      child: Obx(() {
        if (orders.isLoading.value) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator(color: AppColors.ink)),
          );
        }
        if (orders.orders.isEmpty) {
          return Column(
            children: [
              if (orders.error.value.isNotEmpty)
                ErrorBanner(message: orders.error.value),
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders yet',
                message:
                    'Your order history will appear here once you make a purchase.',
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order history',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (orders.error.value.isNotEmpty)
              ErrorBanner(message: orders.error.value),
            for (final order in orders.orders) _OrderRow(order: order),
          ],
        );
      }),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.reference,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    order.createdAt != null
                        ? Formatters.dateTime(order.createdAt!)
                        : '—',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.slate),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(order.status.label,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            Text(Formatters.price(order.grandTotal),
                style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        children: [
          for (final line in order.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.productTitle} · ${line.variantSummary} · ×${line.quantity}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(Formatters.price(line.lineTotal),
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          if (order.trackingNumber != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Tracking: ${order.trackingNumber}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.slate)),
              ),
            ),
          const Divider(),
        ],
      ),
    );
  }
}
