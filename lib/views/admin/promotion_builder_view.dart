import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/uuid.dart';
import '../../models/promotion_model.dart';
import 'admin_scaffold.dart';

/// Promotions engine UI (PRD §3.2): create targeted offers with start/end dates,
/// usage limits, minimum order value, and category targeting.
class PromotionBuilderView extends StatelessWidget {
  const PromotionBuilderView({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = Get.find<AdminController>();

    return AdminScaffold(
      title: 'Promotions',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _openEditor(context, admin, null),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New promotion'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold, foregroundColor: AppColors.ink),
        ),
      ],
      child: Obx(() {
        final promos = admin.promotions;
        if (promos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text('No promotions yet.',
                style: TextStyle(color: AppColors.textMutedOnInk)),
          );
        }
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final p in promos)
              SizedBox(
                width: 340,
                child: _PromoCard(
                  promo: p,
                  onEdit: () => _openEditor(context, admin, p),
                  onDelete: () async {
                    final removed = await admin.deletePromotion(p.id);
                    if (!removed) {
                      Get.snackbar('Delete failed', admin.error.value,
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.danger,
                          colorText: AppColors.textOnInk);
                    }
                  },
                ),
              ),
          ],
        );
      }),
    );
  }

  void _openEditor(
      BuildContext context, AdminController admin, Promotion? promo) {
    showDialog<void>(
      context: context,
      builder: (_) => PromotionEditorDialog(admin: admin, existing: promo),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard(
      {required this.promo, required this.onEdit, required this.onDelete});
  final Promotion promo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.inkSoft,
        borderRadius: const BorderRadius.all(AppSpacing.rMd),
        border: Border.all(
            color: promo.isLive
                ? AppColors.gold.withValues(alpha: 0.4)
                : const Color(0xFF2A2A30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: const BorderRadius.all(AppSpacing.rSm),
                  border: Border.all(color: const Color(0xFF2A2A30)),
                ),
                child: Text(promo.code,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ),
              const Spacer(),
              _liveDot(promo.isLive),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(promo.valueLabel, style: Theme.of(context).textTheme.titleLarge),
          if (promo.description != null)
            Text(promo.description!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMutedOnInk)),
          const SizedBox(height: AppSpacing.sm),
          _meta(
              context,
              'Min order',
              promo.minOrderValue > 0
                  ? Formatters.priceTrim(promo.minOrderValue)
                  : 'None'),
          _meta(
              context,
              'Usage',
              promo.usageLimit == null
                  ? '${promo.usageCount} (∞)'
                  : '${promo.usageCount}/${promo.usageLimit}'),
          if (promo.includedCategories.isNotEmpty)
            _meta(context, 'Only', promo.includedCategories.join(', ')),
          if (promo.validUntil != null)
            _meta(context, 'Ends', Formatters.date(promo.validUntil!)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit')),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.danger,
                  onPressed: onDelete),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Text('$k: ',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textMutedOnInk)),
            Expanded(
                child: Text(v, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );

  Widget _liveDot(bool live) => Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: live ? AppColors.success : AppColors.slate,
                  shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(live ? 'Live' : 'Off',
              style: TextStyle(
                  color: live ? AppColors.success : AppColors.slate,
                  fontSize: 11)),
        ],
      );
}

class PromotionEditorDialog extends StatefulWidget {
  const PromotionEditorDialog({super.key, required this.admin, this.existing});
  final AdminController admin;
  final Promotion? existing;

  @override
  State<PromotionEditorDialog> createState() => _PromotionEditorDialogState();
}

class _PromotionEditorDialogState extends State<PromotionEditorDialog> {
  late TextEditingController _code;
  late TextEditingController _description;
  late TextEditingController _value;
  late TextEditingController _minOrder;
  late TextEditingController _usageLimit;
  DiscountType _type = DiscountType.percentage;
  bool _active = true;
  DateTime? _validUntil;
  final Set<String> _included = {};

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _code = TextEditingController(text: p?.code ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _value =
        TextEditingController(text: (p?.discountValue ?? 0).toStringAsFixed(0));
    _minOrder =
        TextEditingController(text: (p?.minOrderValue ?? 0).toStringAsFixed(0));
    _usageLimit = TextEditingController(text: p?.usageLimit?.toString() ?? '');
    _type = p?.discountType ?? DiscountType.percentage;
    _active = p?.isActive ?? true;
    _validUntil = p?.validUntil;
    _included.addAll(p?.includedCategories ?? const []);
  }

  @override
  void dispose() {
    for (final c in [_code, _description, _value, _minOrder, _usageLimit]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final promo = Promotion(
      id: widget.existing?.id ?? Uuid.v4(),
      code: _code.text.trim().toUpperCase(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      discountType: _type,
      discountValue: double.tryParse(_value.text.trim()) ?? 0,
      minOrderValue: double.tryParse(_minOrder.text.trim()) ?? 0,
      usageLimit: _usageLimit.text.trim().isEmpty
          ? null
          : int.tryParse(_usageLimit.text.trim()),
      usageCount: widget.existing?.usageCount ?? 0,
      isActive: _active,
      includedCategories: _included.toList(),
      validFrom: widget.existing?.validFrom ?? DateTime.now(),
      validUntil: _validUntil,
    );
    widget.admin.savePromotion(promo);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.inkSoft,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                      widget.existing == null
                          ? 'New promotion'
                          : 'Edit promotion',
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
                      TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                            labelText: 'Code (e.g. FALL20)'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                          controller: _description,
                          decoration:
                              const InputDecoration(labelText: 'Description')),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<DiscountType>(
                        initialValue: _type,
                        decoration:
                            const InputDecoration(labelText: 'Discount type'),
                        dropdownColor: AppColors.ink,
                        items: [
                          for (final t in DiscountType.values)
                            DropdownMenuItem(value: t, child: Text(t.label)),
                        ],
                        onChanged: (v) => setState(
                            () => _type = v ?? DiscountType.percentage),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _value,
                              enabled: _type != DiscountType.freeShipping,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _type == DiscountType.percentage
                                    ? 'Percent (%)'
                                    : 'Amount (\$)',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextField(
                              controller: _minOrder,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Min order (\$)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usageLimit,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Usage limit (blank = ∞)'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickEndDate,
                              icon: const Icon(Icons.event, size: 18),
                              label: Text(_validUntil == null
                                  ? 'End date'
                                  : Formatters.date(_validUntil!)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textOnInk,
                                side:
                                    const BorderSide(color: Color(0xFF2A2A30)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Restrict to categories (optional)',
                          style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final c in Categories.all)
                            FilterChip(
                              label: Text(c),
                              selected: _included.contains(c),
                              onSelected: (sel) => setState(() {
                                sel ? _included.add(c) : _included.remove(c);
                              }),
                              selectedColor: AppColors.gold,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _active,
                        activeThumbColor: AppColors.gold,
                        title: const Text('Active'),
                        onChanged: (v) => setState(() => _active = v),
                      ),
                    ],
                  ),
                ),
              ),
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
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }
}
