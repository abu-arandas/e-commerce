import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/bootstrap5.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../shared/ui_kit.dart';
import 'admin_scaffold.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = Get.find<AdminController>();

    return AdminScaffold(
      title: 'Dashboard',
      actions: [
        OutlinedButton.icon(
          onPressed: admin.refreshAll,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textOnInk,
            side: const BorderSide(color: AppColors.inkLine),
          ),
        ),
      ],
      child: Obx(() {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorBanner(
              message: admin.error.value,
              onDismiss: () => admin.error.value = '',
            ),
            // KPI row.
            FB5Row(
              classNames: 'gx-3 gy-3',
              children: [
                _kpi('Revenue', Formatters.price(admin.grossRevenue), Icons.payments_outlined, AppColors.gold),
                _kpi('Orders', '${admin.totalOrders}', Icons.receipt_long_outlined, AppColors.info),
                _kpi('Pending', '${admin.pendingOrders}', Icons.hourglass_bottom, AppColors.warning),
                _kpi('Avg. order', Formatters.price(admin.averageOrderValue), Icons.trending_up, AppColors.success),
                _kpi('Products', '${admin.activeProducts}/${admin.totalProducts}', Icons.checkroom_outlined, AppColors.mist),
                _kpi('SKUs', '${admin.totalSkus}', Icons.qr_code_2, AppColors.mist),
                _kpi('Live promos', '${admin.activePromotions}', Icons.sell_outlined, AppColors.gold),
                _kpi('Low stock', '${admin.lowStock.length}', Icons.warning_amber_rounded, AppColors.danger),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FB5Row(
              classNames: 'gx-4 gy-4',
              children: [
                FB5Col(classNames: 'col-12 col-lg-7', child: _RecentOrders(admin: admin)),
                FB5Col(classNames: 'col-12 col-lg-5', child: _LowStock(admin: admin)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _RevenueByCategory(admin: admin),
          ],
        );
      }),
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color accent) {
    return FB5Col(
      classNames: 'col-6 col-md-3',
      child: Builder(builder: (context) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.inkSoft,
            borderRadius: const BorderRadius.all(AppSpacing.rMd),
            border: Border.all(color: AppColors.inkLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(height: AppSpacing.sm),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMutedOnInk)),
            ],
          ),
        );
      }),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.inkSoft,
        borderRadius: const BorderRadius.all(AppSpacing.rMd),
        border: Border.all(color: AppColors.inkLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.admin});
  final AdminController admin;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent orders',
      child: Column(
        children: [
          for (final o in admin.recentOrders)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.reference, style: Theme.of(context).textTheme.titleSmall),
                        Text(o.contactEmail ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMutedOnInk)),
                      ],
                    ),
                  ),
                  Expanded(child: _StatusPill(status: o.status)),
                  Expanded(
                    child: Text(Formatters.price(o.grandTotal),
                        textAlign: TextAlign.right, style: Theme.of(context).textTheme.titleSmall),
                  ),
                ],
              ),
            ),
          if (admin.recentOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('No orders yet.', style: TextStyle(color: AppColors.textMutedOnInk)),
            ),
        ],
      ),
    );
  }
}

class _LowStock extends StatelessWidget {
  const _LowStock({required this.admin});
  final AdminController admin;

  @override
  Widget build(BuildContext context) {
    final entries = admin.lowStock.take(8).toList();
    return _Panel(
      title: 'Low-stock alerts',
      child: entries.isEmpty
          ? const Text('All SKUs are healthy.', style: TextStyle(color: AppColors.textMutedOnInk))
          : Column(
              children: [
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: e.isOut ? AppColors.danger : AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${e.productTitle} · ${e.colorName} · ${e.sizeLabel}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium),
                              Text(e.sku,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMutedOnInk)),
                            ],
                          ),
                        ),
                        Text(e.isOut ? 'Out' : '${e.stock} left',
                            style: TextStyle(color: e.isOut ? AppColors.danger : AppColors.warning, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RevenueByCategory extends StatelessWidget {
  const _RevenueByCategory({required this.admin});
  final AdminController admin;

  @override
  Widget build(BuildContext context) {
    final data = admin.revenueByCategory;
    final max = data.values.isEmpty ? 1.0 : data.values.reduce((a, b) => a > b ? a : b);
    return _Panel(
      title: 'Revenue by category',
      child: data.isEmpty
          ? const Text('No sales data yet.', style: TextStyle(color: AppColors.textMutedOnInk))
          : Column(
              children: [
                for (final entry in data.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        SizedBox(width: 96, child: Text(entry.key, style: Theme.of(context).textTheme.bodyMedium)),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (entry.value / max).clamp(0.02, 1).toDouble(),
                              minHeight: 10,
                              backgroundColor: AppColors.ink,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          width: 80,
                          child: Text(Formatters.price(entry.value),
                              textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final OrderStatus status;

  /// (text, fill, border) per status — see [AppColors] for why the translucent
  /// values are constants rather than derived at runtime.
  (Color, Color, Color) get _palette => switch (status) {
        OrderStatus.pending => (
            AppColors.warning,
            AppColors.warningTint,
            AppColors.warningEdge
          ),
        OrderStatus.paid ||
        OrderStatus.processing =>
          (AppColors.info, AppColors.infoTint, AppColors.infoEdge),
        OrderStatus.shipped => (
            AppColors.gold,
            AppColors.goldTint,
            AppColors.goldEdge
          ),
        OrderStatus.delivered => (
            AppColors.success,
            AppColors.successTint,
            AppColors.successEdge
          ),
        OrderStatus.cancelled ||
        OrderStatus.refunded =>
          (AppColors.danger, AppColors.dangerTint, AppColors.dangerEdge),
      };

  @override
  Widget build(BuildContext context) {
    final (text, fill, border) = _palette;
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: const BorderRadius.all(AppSpacing.rSm),
          border: Border.all(color: border),
        ),
        child: Text(status.label,
            style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
