import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/catalog_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/bootstrap5.dart';
import '../../core/utils/seo/seo_service.dart';
import '../shared/product_grid.dart';
import '../shared/storefront_scaffold.dart';
import '../shared/ui_kit.dart';

/// The storefront landing page: full-bleed hero, category strip, and a featured
/// edit grid (PRD §3.1 "Premium Visuals").
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    SeoService.update(
      title: 'Vanguard Fashion — Premium Designer Apparel',
      description:
          'Considered design and exceptional materials. Shop cashmere, silk, and tailored '
          'outerwear with a seamless, responsive experience.',
      canonicalPath: '/',
    );

    final catalog = Get.find<CatalogController>();

    return StorefrontScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AnnouncementBar(),
          const _Hero(),
          _sectionWrap(
            context,
            child: const _CategoryStrip(),
          ),
          _sectionWrap(
            context,
            background: AppColors.surfaceAlt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: SectionHeading(
                    eyebrow: 'The Edit',
                    title: 'Featured this season',
                    align: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Obx(() {
                  if (catalog.isLoading.value) {
                    return const ProductGridSkeleton(count: 4);
                  }
                  final featured = catalog.featured;
                  final list = featured.isEmpty
                      ? catalog.visibleProducts.take(4).toList()
                      : featured;
                  return ProductGrid(products: list);
                }),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: OutlinedButton(
                    onPressed: () => Get.toNamed(AppRoutes.shop),
                    child: const Text('Shop all pieces'),
                  ),
                ),
              ],
            ),
          ),
          _sectionWrap(context, child: const _EditorialBand()),
        ],
      ),
    );
  }

  Widget _sectionWrap(BuildContext context,
      {required Widget child, Color? background}) {
    final v = AppSpacing.section(MediaQuery.sizeOf(context).width);
    return Container(
      color: background,
      padding: EdgeInsets.symmetric(vertical: v, horizontal: AppSpacing.md),
      child: FB5Container(child: child),
    );
  }
}

class _AnnouncementBar extends StatelessWidget {
  const _AnnouncementBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.ink,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        'Complimentary shipping over \$150  ·  Use code FALL20 for 20% off',
        textAlign: TextAlign.center,
        style: AppTypography.eyebrow(color: AppColors.goldSoft)
            .copyWith(letterSpacing: 1.6),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final height = isMobile ? 520.0 : 640.0;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const VfImage(
              url: 'https://picsum.photos/seed/vf-hero-editorial/1800/1200'),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xCC0E0E10), Color(0x330E0E10)],
              ),
            ),
          ),
          Align(
            alignment: isMobile ? Alignment.bottomLeft : Alignment.centerLeft,
            child: FB5Container(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AUTUMN / WINTER',
                          style:
                              AppTypography.eyebrow(color: AppColors.goldSoft)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Quiet luxury,\nengineered to last.',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(
                                color: AppColors.textOnInk,
                                fontSize: isMobile ? 44 : 64),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'A tightly-edited collection of cashmere, silk, and tailored '
                        'outerwear — cut for the modern wardrobe.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AppColors.textMutedOnInk),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          GoldButton(
                            label: 'Shop the collection',
                            gold: true,
                            onPressed: () => Get.toNamed(AppRoutes.shop),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip();

  static const _cats = [
    ('Knitwear', 'vf-cat-knit'),
    ('Trousers', 'vf-cat-trouser'),
    ('Dresses', 'vf-cat-dress'),
    ('Outerwear', 'vf-cat-outer'),
  ];

  @override
  Widget build(BuildContext context) {
    return FB5Row(
      classNames: 'gx-4 gy-4',
      children: [
        for (final (name, seed) in _cats)
          FB5Col(
            classNames: 'col-6 col-lg-3',
            child: InkWell(
              onTap: () => Get.toNamed('${AppRoutes.shop}?category=$name'),
              borderRadius: const BorderRadius.all(AppSpacing.rMd),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(AppSpacing.rMd),
                child: Stack(
                  children: [
                    VfImage(
                        url: 'https://picsum.photos/seed/$seed/600/700',
                        aspectRatio: 4 / 5),
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.bottomLeft,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xAA0E0E10)],
                          ),
                        ),
                        child: Text(name,
                            style: AppTypography.wordmark(
                                color: AppColors.textOnInk, size: 20)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EditorialBand extends StatelessWidget {
  const _EditorialBand();

  @override
  Widget build(BuildContext context) {
    return FB5Row(
      classNames: 'gx-5 gy-4',
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const FB5Col(
          classNames: 'col-12 col-lg-6',
          child: ClipRRect(
            borderRadius: BorderRadius.all(AppSpacing.rMd),
            child: VfImage(
                url: 'https://picsum.photos/seed/vf-editorial-craft/1000/800',
                aspectRatio: 5 / 4),
          ),
        ),
        FB5Col(
          classNames: 'col-12 col-lg-6',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                  eyebrow: 'Our craft', title: 'Made to be kept'),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Every piece is developed with heritage mills and finished by hand. We favour '
                'natural fibres, considered construction, and colours that endure beyond a single season.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () => Get.toNamed(AppRoutes.shop),
                child: const Text('Explore the collection'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
