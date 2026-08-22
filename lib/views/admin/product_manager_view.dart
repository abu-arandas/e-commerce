import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/uuid.dart';
import '../../models/product_model.dart';
import '../../models/variant_model.dart';
import 'admin_scaffold.dart';

/// Catalog CMS (PRD §3.2 "Complex Catalog Entry"): list products, toggle
/// visibility, and edit parent products with nested colour groups and bulk-
/// generated size variants.
class ProductManagerView extends StatelessWidget {
  const ProductManagerView({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = Get.find<AdminController>();

    return AdminScaffold(
      title: 'Products',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _openEditor(context, admin, null),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New product'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold, foregroundColor: AppColors.ink),
        ),
      ],
      child: Obx(() {
        final products = admin.products;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.inkSoft,
            borderRadius: const BorderRadius.all(AppSpacing.rMd),
            border: Border.all(color: const Color(0xFF2A2A30)),
          ),
          child: Column(
            children: [
              const _HeaderRow(),
              for (final p in products)
                _ProductRow(
                  product: p,
                  onToggle: () => admin.toggleProductActive(p),
                  onEdit: () => _openEditor(context, admin, p),
                  onDelete: () => _confirmDelete(context, admin, p),
                ),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text('No products yet.',
                      style: TextStyle(color: AppColors.textMutedOnInk)),
                ),
            ],
          ),
        );
      }),
    );
  }

  void _openEditor(
      BuildContext context, AdminController admin, Product? product) {
    showDialog<void>(
      context: context,
      builder: (_) => ProductEditorDialog(admin: admin, existing: product),
    );
  }

  void _confirmDelete(BuildContext context, AdminController admin, Product p) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.inkSoft,
        title: const Text('Delete product?'),
        content: Text('“${p.title}” and all its variants will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              // Awaited, so a failed delete is reported instead of becoming an
              // unhandled async error behind a dialog that already closed.
              final removed = await admin.deleteProduct(p.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (!removed) {
                Get.snackbar('Delete failed', admin.error.value,
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.danger,
                    colorText: AppColors.textOnInk);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: AppColors.textMutedOnInk);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A30))),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('PRODUCT', style: style)),
          Expanded(flex: 2, child: Text('CATEGORY', style: style)),
          Expanded(flex: 2, child: Text('PRICE', style: style)),
          Expanded(flex: 2, child: Text('STOCK', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          SizedBox(width: 96, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF23232A))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.title,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                    '${product.groups.length} colour(s) · ${product.allItems.length} SKU(s)',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.textMutedOnInk)),
              ],
            ),
          ),
          Expanded(
              flex: 2,
              child: Text(product.category ?? '—',
                  style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
              flex: 2,
              child: Text(Formatters.priceTrim(product.fromPrice),
                  style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
            flex: 2,
            child: Text('${product.totalStock}',
                style: TextStyle(
                    color: product.totalStock <= AppConstants.lowStockThreshold
                        ? AppColors.warning
                        : AppColors.textOnInk)),
          ),
          Expanded(
            flex: 2,
            child: Switch(
              value: product.isActive,
              activeThumbColor: AppColors.gold,
              onChanged: (_) => onToggle(),
            ),
          ),
          SizedBox(
            width: 96,
            child: Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onEdit,
                    tooltip: 'Edit'),
                IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.danger,
                    onPressed: onDelete,
                    tooltip: 'Delete'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editor dialog
// ---------------------------------------------------------------------------

class ProductEditorDialog extends StatefulWidget {
  const ProductEditorDialog({super.key, required this.admin, this.existing});
  final AdminController admin;
  final Product? existing;

  @override
  State<ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<ProductEditorDialog> {
  late TextEditingController _title;
  late TextEditingController _slug;
  late TextEditingController _category;
  late TextEditingController _price;
  late TextEditingController _description;
  late List<VariantGroup> _groups;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _title = TextEditingController(text: p?.title ?? '');
    _slug = TextEditingController(text: p?.slug ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _price =
        TextEditingController(text: (p?.basePrice ?? 0).toStringAsFixed(2));
    _description = TextEditingController(text: p?.description ?? '');
    _groups = [...?p?.groups];
  }

  @override
  void dispose() {
    for (final c in [_title, _slug, _category, _price, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  String _slugify(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  Future<void> _save() async {
    final base = double.tryParse(_price.text.trim()) ?? 0;
    final slug =
        _slug.text.trim().isEmpty ? _slugify(_title.text) : _slug.text.trim();
    final product = Product(
      // Postgres keys these by uuid; a 'new-1723...' id is rejected outright
      // with `invalid input syntax for type uuid`.
      id: widget.existing?.id ?? Uuid.v4(),
      slug: slug,
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      basePrice: base,
      isActive: widget.existing?.isActive ?? true,
      isFeatured: widget.existing?.isFeatured ?? false,
      groups: _groups,
    );
    // Awaited, not fired and forgotten. save_product() reports permission,
    // constraint and payload failures by throwing; closing the editor on top
    // of an unawaited call turned that into an unhandled async error while the
    // dialog claimed the product -- and its whole variant tree -- was saved.
    try {
      await widget.admin.saveProduct(product);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save "${product.title}": $e')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _addGroup() async {
    final result = await showDialog<VariantGroup>(
      context: context,
      builder: (_) => const _ColorGroupDialog(),
    );
    if (result != null) setState(() => _groups.add(result));
  }

  Future<void> _generateVariants(int groupIndex) async {
    final group = _groups[groupIndex];
    final result = await showDialog<_BulkResult>(
      context: context,
      builder: (_) => const _BulkVariantDialog(),
    );
    if (result == null) return;
    final items = widget.admin.generateVariants(
      groupId: group.id,
      skuPrefix: result.skuPrefix,
      sizes: result.sizes,
      stockPerSize: result.stock,
      priceOverride: result.priceOverride,
    );
    setState(() => _groups[groupIndex] = group.copyWith(items: items));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.inkSoft,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(widget.existing == null ? 'New product' : 'Edit product',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _text(_title, 'Title'),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(child: _text(_category, 'Category')),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                              child: _text(_price, 'Base price', number: true)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _text(_slug, 'URL slug (optional)'),
                      const SizedBox(height: AppSpacing.sm),
                      _text(_description, 'Description', maxLines: 3),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Text('Colour groups & variants',
                              style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addGroup,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add colour'),
                          ),
                        ],
                      ),
                      for (var i = 0; i < _groups.length; i++) _groupCard(i),
                      if (_groups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                              'No colour groups yet. Add a colour, then bulk-generate sizes.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textMutedOnInk)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.ink),
                    child: const Text('Save product'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupCard(int i) {
    final g = _groups[i];
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: const BorderRadius.all(AppSpacing.rSm),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: _hexColor(g.colorHex),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2A2A30)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(g.name, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton(
                  onPressed: () => _generateVariants(i),
                  child: const Text('Generate sizes')),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.danger,
                onPressed: () => setState(() => _groups.removeAt(i)),
              ),
            ],
          ),
          if (g.items.isNotEmpty)
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final item in g.sortedItems)
                  Chip(
                    label: Text('${item.sizeLabel} · ${item.stockQuantity}'),
                    backgroundColor: AppColors.inkSoft,
                    labelStyle: const TextStyle(
                        color: AppColors.textOnInk, fontSize: 12),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _text(TextEditingController c, String label,
      {bool number = false, int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    );
  }

  Color _hexColor(String? hex) {
    final h = hex?.replaceFirst('#', '');
    if (h == null || h.length != 6) return AppColors.mist;
    final v = int.tryParse('FF$h', radix: 16);
    return v == null ? AppColors.mist : Color(v);
  }
}

class _ColorGroupDialog extends StatefulWidget {
  const _ColorGroupDialog();

  @override
  State<_ColorGroupDialog> createState() => _ColorGroupDialogState();
}

class _ColorGroupDialogState extends State<_ColorGroupDialog> {
  final _name = TextEditingController();
  final _hex = TextEditingController(text: '#000000');

  @override
  void dispose() {
    _name.dispose();
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.inkSoft,
      title: const Text('Add colour'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Colour name')),
          const SizedBox(height: AppSpacing.sm),
          TextField(
              controller: _hex,
              decoration:
                  const InputDecoration(labelText: 'Hex (e.g. #1E2A44)')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              VariantGroup(
                id: Uuid.v4(),
                productId: '',
                name: _name.text.trim(),
                colorHex: _hex.text.trim(),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _BulkResult {
  const _BulkResult(this.skuPrefix, this.sizes, this.stock, this.priceOverride);
  final String skuPrefix;
  final List<String> sizes;
  final int stock;
  final double? priceOverride;
}

class _BulkVariantDialog extends StatefulWidget {
  const _BulkVariantDialog();

  @override
  State<_BulkVariantDialog> createState() => _BulkVariantDialogState();
}

class _BulkVariantDialogState extends State<_BulkVariantDialog> {
  final _prefix = TextEditingController();
  final _sizes = TextEditingController(text: 'XS, S, M, L, XL');
  final _stock = TextEditingController(text: '10');
  final _price = TextEditingController();

  @override
  void dispose() {
    for (final c in [_prefix, _sizes, _stock, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.inkSoft,
      title: const Text('Bulk-generate sizes'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _prefix,
              decoration: const InputDecoration(
                  labelText: 'SKU prefix (e.g. CASH-TURT-BLU)')),
          const SizedBox(height: AppSpacing.sm),
          TextField(
              controller: _sizes,
              decoration:
                  const InputDecoration(labelText: 'Sizes (comma separated)')),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Stock / size'))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Price override'))),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final sizes = _sizes.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            Navigator.pop(
              context,
              _BulkResult(
                _prefix.text.trim().isEmpty ? 'SKU' : _prefix.text.trim(),
                sizes,
                int.tryParse(_stock.text.trim()) ?? 0,
                double.tryParse(_price.text.trim()),
              ),
            );
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
