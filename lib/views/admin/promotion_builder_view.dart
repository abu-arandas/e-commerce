import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/uuid.dart';
import '../../models/promotion_model.dart';
import '../shared/ui_kit.dart';
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
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.ink),
        ),
      ],
      child: Obx(() {
        final promos = admin.promotions;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorBanner(
              message: admin.error.value,
              onDismiss: () => admin.error.value = '',
            ),
            if (promos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text('No promotions yet.',
                    style: TextStyle(color: AppColors.textMutedOnInk)),
              )
            else
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final p in promos)
                    SizedBox(
                      width: 340,
                      child: _PromoCard(
                        promo: p,
                        onEdit: () => _openEditor(context, admin, p),
                        onDelete: () => _confirmDelete(context, admin, p),
                      ),
                    ),
                ],
              ),
          ],
        );
      }),
    );
  }

  void _openEditor(BuildContext context, AdminController admin, Promotion? promo) {
    showDialog<void>(
      context: context,
      builder: (_) => PromotionEditorDialog(admin: admin, existing: promo),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AdminController admin, Promotion p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.inkSoft,
        title: Text('Delete ${p.code}?'),
        content: const Text(
            'Shoppers will no longer be able to redeem this code. Orders that '
            'already used it keep their discount.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await admin.deletePromotion(p.id);
    }
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo, required this.onEdit, required this.onDelete});
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
            color: promo.isLive ? AppColors.goldEdgeSoft : AppColors.inkLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: const BorderRadius.all(AppSpacing.rSm),
                  border: Border.all(color: AppColors.inkLine),
                ),
                child: Text(promo.code, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
              const Spacer(),
              _liveDot(promo.isLive),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(promo.valueLabel, style: Theme.of(context).textTheme.titleLarge),
          if (promo.description != null)
            Text(promo.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMutedOnInk)),
          const SizedBox(height: AppSpacing.sm),
          _meta(context, 'Min order', promo.minOrderValue > 0 ? Formatters.priceTrim(promo.minOrderValue) : 'None'),
          _meta(context, 'Usage', promo.usageLimit == null ? '${promo.usageCount} (∞)' : '${promo.usageCount}/${promo.usageLimit}'),
          if (promo.includedCategories.isNotEmpty)
            _meta(context, 'Only', promo.includedCategories.join(', ')),
          if (promo.validUntil != null)
            _meta(context, 'Ends', Formatters.date(promo.validUntil!)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
              const Spacer(),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18), color: AppColors.danger, onPressed: onDelete),
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
            Text('$k: ', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMutedOnInk)),
            Expanded(child: Text(v, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );

  Widget _liveDot(bool live) => Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: live ? AppColors.success : AppColors.slate, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(live ? 'Live' : 'Off', style: TextStyle(color: live ? AppColors.success : AppColors.slate, fontSize: 11)),
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
  DateTime? _validFrom;
  DateTime? _validUntil;
  final Set<String> _included = {};
  final Set<String> _excluded = {};
  String _formError = '';

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _code = TextEditingController(text: p?.code ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _value = TextEditingController(text: (p?.discountValue ?? 0).toStringAsFixed(0));
    _minOrder = TextEditingController(text: (p?.minOrderValue ?? 0).toStringAsFixed(0));
    _usageLimit = TextEditingController(text: p?.usageLimit?.toString() ?? '');
    _type = p?.discountType ?? DiscountType.percentage;
    _active = p?.isActive ?? true;
    _validFrom = p?.validFrom;
    _validUntil = p?.validUntil;
    _included.addAll(p?.includedCategories ?? const []);
    _excluded.addAll(p?.excludedCategories ?? const []);
  }

  @override
  void dispose() {
    for (final c in [_code, _description, _value, _minOrder, _usageLimit]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    final code = _code.text.trim();
    if (code.isEmpty) return 'A promo code is required.';
    if (code.contains(RegExp(r'\s'))) {
      return 'Promo codes cannot contain spaces.';
    }
    final value = double.tryParse(_value.text.trim());
    if (_type != DiscountType.freeShipping) {
      if (value == null || value <= 0) {
        return 'Enter a discount amount greater than zero.';
      }
      if (_type == DiscountType.percentage && value > 100) {
        return 'A percentage discount cannot exceed 100%.';
      }
    }
    if (double.tryParse(_minOrder.text.trim()) == null &&
        _minOrder.text.trim().isNotEmpty) {
      return 'Minimum order must be a number.';
    }
    final overlap = _included.intersection(_excluded);
    if (overlap.isNotEmpty) {
      return '${overlap.join(', ')} cannot be both included and excluded.';
    }
    if (_validFrom != null &&
        _validUntil != null &&
        !_validUntil!.isAfter(_validFrom!)) {
      return 'The end date must fall after the start date.';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _formError = problem);
      return;
    }
    setState(() => _formError = '');

    final promo = Promotion(
      // A real UUID: `promotions.id` is a uuid column, so a generated string
      // like "promo-1712…" would be rejected by Postgres on insert.
      id: widget.existing?.id ?? Uuid.v4(),
      code: _code.text.trim().toUpperCase(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      discountType: _type,
      discountValue: _type == DiscountType.freeShipping
          ? 0
          : double.parse(_value.text.trim()),
      minOrderValue: double.tryParse(_minOrder.text.trim()) ?? 0,
      usageLimit: _usageLimit.text.trim().isEmpty ? null : int.tryParse(_usageLimit.text.trim()),
      usageCount: widget.existing?.usageCount ?? 0,
      isActive: _active,
      includedCategories: _included.toList(),
      excludedCategories: _excluded.toList(),
      validFrom: _validFrom ?? widget.existing?.validFrom ?? DateTime.now(),
      validUntil: _validUntil,
    );

    final saved = await widget.admin.savePromotion(promo);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _formError = widget.admin.error.value);
    }
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
                  Text(widget.existing == null ? 'New promotion' : 'Edit promotion',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
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
                        decoration: const InputDecoration(labelText: 'Code (e.g. FALL20)'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description')),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<DiscountType>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Discount type'),
                        dropdownColor: AppColors.ink,
                        items: [
                          for (final t in DiscountType.values)
                            DropdownMenuItem(value: t, child: Text(t.label)),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? DiscountType.percentage),
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
                                labelText: _type == DiscountType.percentage ? 'Percent (%)' : 'Amount (\$)',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextField(
                              controller: _minOrder,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Min order (\$)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _usageLimit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Usage limit (blank = ∞)'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _dateButton(
                              label: _validFrom == null
                                  ? 'Start date (now)'
                                  : 'From ${Formatters.date(_validFrom!)}',
                              onPressed: () => _pickDate(
                                initial: _validFrom,
                                onPicked: (d) => setState(() => _validFrom = d),
                              ),
                              onClear: _validFrom == null
                                  ? null
                                  : () => setState(() => _validFrom = null),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _dateButton(
                              label: _validUntil == null
                                  ? 'End date'
                                  : 'Until ${Formatters.date(_validUntil!)}',
                              onPressed: () => _pickDate(
                                initial: _validUntil,
                                fallback: DateTime.now().add(const Duration(days: 30)),
                                onPicked: (d) => setState(() => _validUntil = d),
                              ),
                              onClear: _validUntil == null
                                  ? null
                                  : () => setState(() => _validUntil = null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Apply only to these categories (optional)',
                          style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'The discount is calculated on the matching lines only, '
                        'not the whole bag.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMutedOnInk),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _categoryChips(_included),
                      const SizedBox(height: AppSpacing.md),
                      Text('Exclude these categories (optional)',
                          style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'A bag containing any of these cannot use the code at all.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMutedOnInk),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _categoryChips(_excluded),
                      const SizedBox(height: AppSpacing.sm),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _active,
                        title: const Text('Active'),
                        onChanged: (v) => setState(() => _active = v),
                      ),
                      ErrorBanner(message: _formError),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: AppSpacing.sm),
                  Obx(() => ElevatedButton(
                        onPressed: widget.admin.isSaving.value ? null : _save,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.ink),
                        child: widget.admin.isSaving.value
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.ink),
                              )
                            : const Text('Save'),
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Multi-select category chips shared by the include and exclude lists.
  Widget _categoryChips(Set<String> selection) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final c in Categories.all)
            FilterChip(
              label: Text(c),
              selected: selection.contains(c),
              onSelected: (sel) => setState(() {
                if (sel) {
                  selection.add(c);
                } else {
                  selection.remove(c);
                }
              }),
              selectedColor: AppColors.gold,
            ),
        ],
      );

  Widget _dateButton({
    required String label,
    required VoidCallback onPressed,
    VoidCallback? onClear,
  }) =>
      OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(onClear == null ? Icons.event : Icons.event_available, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.xxs),
                  child: Icon(Icons.close, size: 14),
                ),
              ),
          ],
        ),
      );

  Future<void> _pickDate({
    DateTime? initial,
    DateTime? fallback,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    // Promotions can legitimately have started in the past, so the picker has
    // to reach back beyond today.
    final first = now.subtract(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? fallback ?? now,
      firstDate: first,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) onPicked(picked);
  }
}
