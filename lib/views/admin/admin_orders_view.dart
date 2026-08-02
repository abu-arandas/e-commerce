import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import 'admin_scaffold.dart';

/// Fulfillment grid (PRD §3.2 "Order & Inventory Sync"): review orders, expand
/// line items, and advance status through the pipeline.
class AdminOrdersView extends StatelessWidget {
  const AdminOrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = Get.find<AdminController>();

    return AdminScaffold(
      title: 'Orders',
      actions: [
        OutlinedButton.icon(
          onPressed: admin.refreshAll,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textOnInk,
            side: const BorderSide(color: Color(0xFF2A2A30)),
          ),
        ),
      ],
      child: Obx(() {
        final orders = admin.orders;
        if (orders.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text('No orders yet.',
                style: TextStyle(color: AppColors.textMutedOnInk)),
          );
        }
        return Column(
          children: [
            for (final o in orders) _OrderTile(order: o, admin: admin),
          ],
        );
      }),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.admin});
  final Order order;
  final AdminController admin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.inkSoft,
        borderRadius: const BorderRadius.all(AppSpacing.rMd),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          title: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.reference,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(order.contactEmail ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMutedOnInk)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                    order.createdAt != null
                        ? Formatters.date(order.createdAt!)
                        : '—',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMutedOnInk)),
              ),
              Expanded(
                flex: 2,
                child: Text('${order.itemCount} item(s)',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              Expanded(
                flex: 2,
                child: Text(Formatters.price(order.grandTotal),
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              _StatusDropdown(order: order, admin: admin),
            ],
          ),
          children: [
            const Divider(color: Color(0xFF2A2A30)),
            for (final line in order.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                          '${line.productTitle} · ${line.variantSummary}',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Expanded(
                        flex: 2,
                        child: Text(line.sku,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.textMutedOnInk))),
                    Expanded(
                        child: Text('×${line.quantity}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium)),
                    Expanded(
                        child: Text(Formatters.price(line.lineTotal),
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
            const Divider(color: Color(0xFF2A2A30)),
            Row(
              children: [
                if (order.promoCode != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: Chip(
                      label: Text(order.promoCode!),
                      backgroundColor: AppColors.ink,
                      labelStyle: const TextStyle(color: AppColors.gold),
                    ),
                  ),
                if (order.trackingNumber != null)
                  Text('Tracking: ${order.trackingNumber}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textMutedOnInk)),
                const Spacer(),
                Text(
                    'Subtotal ${Formatters.price(order.subtotal)}  ·  '
                    'Disc ${Formatters.price(order.discountTotal)}  ·  '
                    'Ship ${order.shippingTotal == 0 ? 'Free' : Formatters.price(order.shippingTotal)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMutedOnInk)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.order, required this.admin});
  final Order order;
  final AdminController admin;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<OrderStatus>(
        value: order.status,
        dropdownColor: AppColors.ink,
        borderRadius: const BorderRadius.all(AppSpacing.rSm),
        style: const TextStyle(color: AppColors.textOnInk, fontSize: 13),
        items: [
          for (final s in OrderStatus.values)
            DropdownMenuItem(value: s, child: Text(s.label)),
        ],
        onChanged: (s) {
          if (s != null && s != order.status) admin.updateOrderStatus(order, s);
        },
      ),
    );
  }
}
