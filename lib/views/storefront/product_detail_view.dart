import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/cart_controller.dart';
import '../../controllers/catalog_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/bootstrap5.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/seo/seo_service.dart';
import '../../core/utils/store_settings.dart';
import '../shared/storefront_scaffold.dart';
import '../shared/ui_kit.dart';
import '../shared/variant_selector.dart';

/// Product detail (PRD §6.2 lg): split-screen — images `col-lg-7`, details
/// `col-lg-5`. Below `lg` the columns stack. Nested variant selection updates
/// price and stock live.
class ProductDetailView extends StatefulWidget {
  const ProductDetailView({super.key});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  final CatalogController catalog = Get.find<CatalogController>();
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    final slug = Get.parameters['slug'] ?? '';
    final color = Get.parameters['color'];
    _load(slug, color);
  }

  Future<void> _load(String slug, String? color) async {
    final product = await catalog.loadProduct(slug, preselectColorSlug: color);
    if (!mounted) return;
    if (product == null) {
      setState(() => _notFound = true);
    } else {
      SeoService.update(
        title: '${product.title} — Vanguard Fashion',
        description: product.description,
        canonicalPath: AppRoutes.productPath(product.slug),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StorefrontScaffold(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.md),
        child: FB5Container(
          child: Obx(() {
            final product = catalog.selected.value;
            if (_notFound) {
              return EmptyState(
                icon: Icons.search_off,
                title: 'Piece not found',
                message: 'This item may have sold out or been retired.',
                action: OutlinedButton(
                  onPressed: () => Get.toNamed(AppRoutes.shop),
                  child: const Text('Back to shop'),
                ),
              );
            }
            if (product == null) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xxxl),
                child: Center(child: CircularProgressIndicator(color: AppColors.ink)),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Breadcrumb(product: product.title),
                const SizedBox(height: AppSpacing.md),
                FB5Row(
                  classNames: 'gx-5 gy-4',
                  children: [
                    FB5Col(classNames: 'col-12 col-lg-7', child: _Gallery(catalog: catalog)),
                    FB5Col(classNames: 'col-12 col-lg-5', child: _Details(catalog: catalog)),
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

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.product});
  final String product;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(onTap: () => Get.toNamed(AppRoutes.home), child: Text('Home', style: style)),
        Text('  /  ', style: style),
        InkWell(onTap: () => Get.toNamed(AppRoutes.shop), child: Text('Shop', style: style)),
        Text('  /  ', style: style),
        Text(product, style: style?.copyWith(color: AppColors.ink)),
      ],
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.catalog});
  final CatalogController catalog;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final images = catalog.activeImages;
      final active = catalog.activeImage.value.clamp(0, images.isEmpty ? 0 : images.length - 1);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(AppSpacing.rMd),
            child: VfImage(
              url: images.isEmpty ? null : images[active],
              aspectRatio: 4 / 5,
            ),
          ),
          if (images.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => catalog.setActiveImage(i),
                  child: Container(
                    width: 70,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(AppSpacing.rSm),
                      border: Border.all(
                        color: i == active ? AppColors.ink : AppColors.line,
                        width: i == active ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: VfImage(url: images[i]),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.catalog});
  final CatalogController catalog;

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();

    return Obx(() {
      final product = catalog.selected.value;
      if (product == null) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.category != null)
            Text(product.category!.toUpperCase(),
                style: AppTypography.eyebrow(color: AppColors.slate)),
          const SizedBox(height: AppSpacing.xs),
          Text(product.title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.price(catalog.currentUnitPrice),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.ink)),
              if (product.hasPriceRange && catalog.selectedItem.value == null) ...[
                const SizedBox(width: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('starting', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate)),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(product.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xl),

          // Nested Color → Size selector.
          VariantSelector(controller: catalog),
          const SizedBox(height: AppSpacing.xl),

          // Quantity + add to cart.
          Row(
            children: [
              Obx(() => QuantityStepper(
                    value: catalog.quantity.value,
                    max: catalog.currentStock == 0 ? 1 : catalog.currentStock,
                    onDecrement: catalog.decrementQty,
                    onIncrement: catalog.incrementQty,
                  )),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Obx(() => GoldButton(
                      label: catalog.canAddToCart ? 'Add to bag' : 'Select a size',
                      icon: Icons.shopping_bag_outlined,
                      onPressed: catalog.canAddToCart
                          ? () => _addToCart(context, cart, catalog)
                          : null,
                    )),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _AssuranceRow(),
          const SizedBox(height: AppSpacing.lg),
          _Accordion(product.description),
        ],
      );
    });
  }

  void _addToCart(BuildContext context, CartController cart, CatalogController catalog) {
    final product = catalog.selected.value!;
    final group = catalog.selectedGroup.value!;
    final item = catalog.selectedItem.value!;
    cart.add(product: product, group: group, item: item, quantity: catalog.quantity.value);
    Get.snackbar(
      'Added to bag',
      '${product.title} · ${group.name} · ${item.sizeLabel}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.ink,
      colorText: AppColors.textOnInk,
      margin: const EdgeInsets.all(AppSpacing.md),
      mainButton: TextButton(
        onPressed: () => Get.toNamed(AppRoutes.cart),
        child: const Text('View bag', style: TextStyle(color: AppColors.gold)),
      ),
    );
  }
}

class _AssuranceRow extends StatelessWidget {
  const _AssuranceRow();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.goldDeep),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
    return Obx(() => Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: [
            item(
              Icons.local_shipping_outlined,
              'Free shipping over '
              '${Formatters.priceTrim(StoreSettings.freeShippingThreshold.value)}',
            ),
            item(Icons.autorenew, '${AppConstants.freeReturnsDays}-day returns'),
            item(Icons.verified_outlined, 'Authenticity guaranteed'),
          ],
        ));
  }
}

class _Accordion extends StatelessWidget {
  const _Accordion(this.description);
  final String description;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: AppColors.line),
      child: Column(
        children: [
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Details & materials', style: Theme.of(context).textTheme.titleMedium),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(description, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Shipping & returns', style: Theme.of(context).textTheme.titleMedium),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Obx(() => Text(
                      'Complimentary carbon-neutral shipping on orders over '
                      '${Formatters.priceTrim(StoreSettings.freeShippingThreshold.value)}. '
                      'Returns accepted within ${AppConstants.freeReturnsDays} days '
                      'in original condition.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
