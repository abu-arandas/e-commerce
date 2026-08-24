import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/cart_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/bootstrap5.dart';
import '../../core/utils/formatters.dart';
import 'custom_app_bar.dart';

/// Wraps every storefront page with the responsive app bar, mobile nav drawer,
/// an optional footer, and the xs-only sticky bottom cart bar (PRD §6.2).
class StorefrontScaffold extends StatelessWidget {
  const StorefrontScaffold({
    super.key,
    required this.child,
    this.showFooter = true,
    this.scrollable = true,
  });

  final Widget child;
  final bool showFooter;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = scrollable
        ? SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [child, if (showFooter) const AppFooter()],
            ),
          )
        : child;

    return Scaffold(
      appBar: const VanguardAppBar(),
      drawer: const VanguardNavDrawer(),
      body: content,
      bottomNavigationBar: const _StickyCartBar(),
    );
  }
}

/// xs-only bottom bar summarising the cart with a quick path to checkout.
class _StickyCartBar extends StatelessWidget {
  const _StickyCartBar();

  @override
  Widget build(BuildContext context) {
    if (!context.isMobile) return const SizedBox.shrink();
    final cart = Get.find<CartController>();
    return Obx(() {
      if (cart.isEmpty) return const SizedBox.shrink();
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: const BoxDecoration(
            color: AppColors.ink,
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cart.itemCount} item(s)',
                    style: const TextStyle(
                      color: AppColors.textMutedOnInk,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    Formatters.price(cart.grandTotal),
                    style: const TextStyle(
                      color: AppColors.textOnInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Get.toNamed(AppRoutes.cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.ink,
                ),
                child: const Text('View cart'),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Editorial footer with responsive link columns and a newsletter prompt.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Container(
      color: AppColors.ink,
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.section(MediaQuery.sizeOf(context).width),
        horizontal: AppSpacing.md,
      ),
      child: FB5Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FB5Row(
              classNames: 'gx-4 gy-4',
              children: [
                FB5Col(
                  classNames: 'col-12 col-md-6 col-lg-4',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VANGUARD',
                        style: AppTypography.wordmark(
                          color: AppColors.textOnInk,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Considered design, exceptional materials, and a shopping experience '
                        'that feels as premium as the pieces themselves.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMutedOnInk,
                        ),
                      ),
                    ],
                  ),
                ),
                FB5Col(
                  classNames: 'col-6 col-md-3 col-lg-2',
                  child: _links(context, 'Shop', const [
                    'New in',
                    'Knitwear',
                    'Dresses',
                    'Outerwear',
                  ]),
                ),
                FB5Col(
                  classNames: 'col-6 col-md-3 col-lg-2',
                  child: _links(context, 'Client care', const [
                    'Contact',
                    'Shipping',
                    'Returns',
                    'Size guide',
                  ]),
                ),
                FB5Col(
                  classNames: 'col-12 col-lg-4',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('THE EDIT', style: AppTypography.eyebrow()),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'New arrivals and private sales, first.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMutedOnInk,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Expanded(
                            child: TextField(
                              style: TextStyle(color: AppColors.textOnInk),
                              decoration: InputDecoration(
                                hintText: 'Email address',
                                hintStyle: TextStyle(
                                  color: AppColors.textMutedOnInk,
                                ),
                                filled: true,
                                fillColor: AppColors.inkSoft,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    AppSpacing.rSm,
                                  ),
                                  borderSide: BorderSide(
                                    color: Color(0xFF2A2A30),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ElevatedButton(
                            onPressed: () => Get.snackbar(
                              'Subscribed',
                              'Welcome to The Edit.',
                              snackPosition: SnackPosition.BOTTOM,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.ink,
                            ),
                            child: const Text('Join'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(color: Color(0xFF2A2A30)),
            const SizedBox(height: AppSpacing.md),
            Text(
              '© $year ${AppConstants.appName}. All rights reserved.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMutedOnInk),
            ),
          ],
        ),
      ),
    );
  }

  Widget _links(BuildContext context, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.eyebrow(color: AppColors.textOnInk),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: InkWell(
              onTap: () => Get.toNamed(AppRoutes.shop),
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMutedOnInk,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
