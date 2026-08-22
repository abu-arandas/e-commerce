import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/wishlist_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/bootstrap5.dart';
import '../shared/product_card.dart';
import '../shared/storefront_scaffold.dart';
import '../shared/ui_kit.dart';

class WishlistView extends StatelessWidget {
  const WishlistView({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlist = Get.find<WishlistController>();

    return StorefrontScaffold(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.md),
        child: FB5Container(
          child: Obx(() {
            final items = wishlist.savedProducts;
            final unavailable = wishlist.unavailableCount.value;

            if (wishlist.isEmpty) {
              return EmptyState(
                icon: Icons.favorite_border,
                title: 'Your wishlist is empty',
                message: 'Save your favorite pieces here to review or purchase later.',
                action: GoldButton(
                  label: 'Explore collection',
                  onPressed: () => Get.toNamed(AppRoutes.shop),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeading(
                  eyebrow: 'Saved pieces',
                  // Counts saved pieces, matching the header badge. Anything
                  // that cannot be shown is accounted for just below rather
                  // than silently dropped from the total.
                  title: 'Wishlist (${wishlist.count})',
                ),
                if (unavailable > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    unavailable == 1
                        ? '1 saved piece is no longer available.'
                        : '$unavailable saved pieces are no longer available.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.slate),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                FB5Row(
                  classNames: 'gx-4 gy-4',
                  children: [
                    for (final product in items)
                      FB5Col(
                        classNames: 'col-12 col-sm-6 col-md-4 col-lg-3',
                        child: ProductCard(product: product),
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
