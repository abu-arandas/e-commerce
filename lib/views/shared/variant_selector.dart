import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/catalog_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/variant_model.dart';
import 'ui_kit.dart';

/// The nested Color → Size selector (PRD §3.1). Selecting a colour instantly
/// refreshes the available sizes, price, and stock for that colour, all driven
/// by reactive [CatalogController] state.
class VariantSelector extends StatelessWidget {
  const VariantSelector({super.key, required this.controller});

  final CatalogController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final product = controller.selected.value;
      if (product == null) return const SizedBox.shrink();
      final groups = product.sortedGroups;
      final selectedGroup = controller.selectedGroup.value;
      final selectedItem = controller.selectedItem.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Colour (Level 1) ----
          Row(
            children: [
              Text(
                'COLOUR',
                style: AppTypography.eyebrow(color: AppColors.slate),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (selectedGroup != null)
                Text(
                  selectedGroup.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final g in groups)
                Tooltip(
                  message: g.name,
                  child: VfSwatch(
                    hex: g.colorHex,
                    size: 30,
                    selected: g.id == selectedGroup?.id,
                    disabled: !g.hasStock,
                    onTap: () => controller.selectGroup(g),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- Size (Level 2) ----
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SIZE',
                style: AppTypography.eyebrow(color: AppColors.slate),
              ),
              InkWell(
                onTap: () => _showSizeGuide(context),
                child: Text(
                  'Size guide',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.goldDeep,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final item in controller.availableSizes)
                _SizeChip(
                  item: item,
                  selected: item.id == selectedItem?.id,
                  onTap: item.inStock
                      ? () => controller.selectSize(item)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (selectedItem != null)
            StockBadge(
              stock: selectedItem.stockQuantity,
              threshold: selectedItem.lowStockThreshold,
            ),
        ],
      );
    });
  }

  void _showSizeGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Size guide', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Garments run true to size. For an oversized fit, size up.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({required this.item, required this.selected, this.onTap});

  final VariantItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final soldOut = !item.inStock;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 52),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line),
          borderRadius: const BorderRadius.all(AppSpacing.rSm),
        ),
        child: Text(
          item.sizeLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: soldOut
                ? AppColors.mist
                : (selected ? AppColors.textOnInk : AppColors.ink),
            decoration: soldOut ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
