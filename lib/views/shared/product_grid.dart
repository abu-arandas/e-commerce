import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/bootstrap5.dart';
import '../../models/product_model.dart';
import 'product_card.dart';

/// Responsive product grid following the PRD §6.2 column counts:
/// xs/sm → 1 col, md → 2 col, lg → 3 col, xl/xxl → 4 col.
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(
          child: Text('No pieces match your filters.',
              style: TextStyle(color: AppColors.slate)),
        ),
      );
    }
    return FB5Row(
      classNames: 'gx-4 gy-4',
      children: [
        for (final p in products)
          FB5Col(
            classNames: 'col-12 col-md-6 col-lg-4 col-xl-3',
            child: ProductCard(product: p),
          ),
      ],
    );
  }
}

/// A skeleton grid shown while products load.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.count = 8});
  final int count;

  @override
  Widget build(BuildContext context) {
    return FB5Row(
      classNames: 'gx-4 gy-4',
      children: [
        for (var i = 0; i < count; i++)
          FB5Col(
            classNames: 'col-12 col-md-6 col-lg-4 col-xl-3',
            child: AspectRatio(
              aspectRatio: 3 / 4.4,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.all(AppSpacing.rMd),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
