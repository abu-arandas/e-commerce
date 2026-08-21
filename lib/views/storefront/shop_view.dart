import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/catalog_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/bootstrap5.dart';
import '../../core/utils/seo/seo_service.dart';
import '../shared/product_grid.dart';
import '../shared/storefront_scaffold.dart';
import '../shared/ui_kit.dart';

/// Catalogue listing with category filtering, search, and sort. Column counts
/// adapt per breakpoint via [ProductGrid].
class ShopView extends StatefulWidget {
  const ShopView({super.key});

  @override
  State<ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends State<ShopView> {
  final CatalogController catalog = Get.find<CatalogController>();

  @override
  void initState() {
    super.initState();
    // Honour a deep-linked category (?category=Knitwear).
    final category = Get.parameters['category'];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      catalog.setCategory(category);
    });
    SeoService.update(
      title: category != null
          ? '$category — Vanguard Fashion'
          : 'Shop — Vanguard Fashion',
      description: 'Browse the Vanguard Fashion collection.',
      canonicalPath: '/shop',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StorefrontScaffold(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: AppSpacing.section(MediaQuery.sizeOf(context).width) * 0.5,
          horizontal: AppSpacing.md,
        ),
        child: FB5Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() {
                final cat = catalog.categoryFilter.value;
                return SectionHeading(
                  eyebrow: 'Collection',
                  title: cat ?? 'All pieces',
                );
              }),
              const SizedBox(height: AppSpacing.lg),
              _FilterBar(catalog: catalog),
              const SizedBox(height: AppSpacing.lg),
              Obx(() {
                if (catalog.isLoading.value) return const ProductGridSkeleton();
                final list = catalog.visibleProducts;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${list.length} piece(s)',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.slate)),
                    const SizedBox(height: AppSpacing.md),
                    ProductGrid(products: list),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.catalog});
  final CatalogController catalog;

  @override
  Widget build(BuildContext context) {
    return FB5Row(
      classNames: 'gx-3 gy-3',
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FB5Col(
          classNames: 'col-12 col-lg-6',
          child: TextField(
            onChanged: catalog.setSearch,
            decoration: const InputDecoration(
              hintText: 'Search pieces…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        FB5Col(
          classNames: 'col-8 col-lg-4',
          child: Obx(() {
            final cats = catalog.availableCategories;
            final value = catalog.categoryFilter.value;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('All', value == null, () => catalog.setCategory(null)),
                  for (final c in cats)
                    _chip(c, value == c, () => catalog.setCategory(c)),
                ],
              ),
            );
          }),
        ),
        FB5Col(
          classNames: 'col-4 col-lg-2',
          child: Obx(() => DropdownButtonFormField<String>(
                initialValue: catalog.sort.value,
                isExpanded: true,
                decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: const [
                  DropdownMenuItem(value: 'featured', child: Text('Featured')),
                  DropdownMenuItem(value: 'price_asc', child: Text('Price ↑')),
                  DropdownMenuItem(value: 'price_desc', child: Text('Price ↓')),
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                ],
                onChanged: (v) => catalog.setSort(v ?? 'featured'),
              )),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.ink,
          labelStyle:
              TextStyle(color: selected ? AppColors.textOnInk : AppColors.ink),
        ),
      );
}
