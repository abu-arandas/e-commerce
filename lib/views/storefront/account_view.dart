import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/bootstrap5.dart';
import '../shared/storefront_scaffold.dart';
import '../shared/ui_kit.dart';

class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

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
                            if (auth.isStaff)
                              GoldButton(
                                label: 'Open admin panel',
                                expand: true,
                                icon: Icons.dashboard_customize_outlined,
                                onPressed: () => Get.toNamed(AppRoutes.adminDashboard),
                              ),
                            const SizedBox(height: AppSpacing.xs),
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
                        child: const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No orders yet',
                          message: 'Your order history will appear here once you make a purchase.',
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
