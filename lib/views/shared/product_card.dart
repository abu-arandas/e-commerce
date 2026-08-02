import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../models/product_model.dart';
import 'ui_kit.dart';

/// A catalog product tile: full-bleed image, colour swatches, title, and price.
/// Hovering lifts the card and reveals a subtle "View" affordance (desktop web).
class ProductCard extends StatefulWidget {
  const ProductCard({super.key, required this.product});
  final Product product;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.productPath(p.slug)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.all(AppSpacing.rMd),
            boxShadow: _hover ? AppShadows.lifted : AppShadows.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AnimatedScale(
                    scale: _hover ? 1.04 : 1.0,
                    duration: const Duration(milliseconds: 260),
                    child: VfImage(url: p.heroImage, aspectRatio: 3 / 4),
                  ),
                  if (!p.inStock)
                    Positioned(
                      left: AppSpacing.sm,
                      top: AppSpacing.sm,
                      child: _tag('Sold out', AppColors.ink),
                    )
                  else if (p.isFeatured)
                    Positioned(
                      left: AppSpacing.sm,
                      top: AppSpacing.sm,
                      child: _tag('Featured', AppColors.gold, dark: true),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.category != null)
                      Text(p.category!.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.slate)),
                    const SizedBox(height: 2),
                    Text(p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text(
                          p.hasPriceRange
                              ? 'From ${Formatters.priceTrim(p.fromPrice)}'
                              : Formatters.priceTrim(p.fromPrice),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppColors.ink),
                        ),
                        const Spacer(),
                        _swatches(p),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swatches(Product p) {
    final groups = p.sortedGroups.take(4).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: VfSwatch(hex: g.colorHex, size: 16),
          ),
        if (p.groups.length > 4)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('+${p.groups.length - 4}',
                style: const TextStyle(fontSize: 11, color: AppColors.slate)),
          ),
      ],
    );
  }

  Widget _tag(String label, Color color, {bool dark = false}) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
            color: color, borderRadius: const BorderRadius.all(AppSpacing.rSm)),
        child: Text(label,
            style: TextStyle(
                color: dark ? AppColors.ink : AppColors.textOnInk,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}
