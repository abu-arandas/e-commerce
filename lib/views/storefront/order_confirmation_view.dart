import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/bootstrap5.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../shared/storefront_scaffold.dart';
import '../shared/ui_kit.dart';

class OrderConfirmationView extends StatelessWidget {
  const OrderConfirmationView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final order = args is Order ? args : null;

    return StorefrontScaffold(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xxl, horizontal: AppSpacing.md),
        child: FB5Container(
          child: order == null
              ? EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No recent order',
                  message: 'Your order details are no longer available.',
                  action: GoldButton(
                      label: 'Back to shop',
                      onPressed: () => Get.toNamed(AppRoutes.shop)),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Thank you for your order',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall),
                                Text('Order ${order.reference}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(color: AppColors.slate)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (order.contactEmail != null)
                        Text(
                            'A confirmation has been sent to ${order.contactEmail}.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: const BorderRadius.all(AppSpacing.rMd),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          children: [
                            for (final line in order.lines) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(line.productTitle,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        Text(
                                            '${line.variantSummary} · Qty ${line.quantity}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                    color: AppColors.slate)),
                                      ],
                                    ),
                                  ),
                                  Text(Formatters.price(line.lineTotal),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ],
                              ),
                              const Divider(),
                            ],
                            _totalRow(context, 'Subtotal',
                                Formatters.price(order.subtotal)),
                            if (order.discountTotal > 0)
                              _totalRow(context, 'Discount',
                                  '-${Formatters.price(order.discountTotal)}'),
                            _totalRow(
                                context,
                                'Shipping',
                                order.shippingTotal == 0
                                    ? 'Free'
                                    : Formatters.price(order.shippingTotal)),
                            const SizedBox(height: AppSpacing.xs),
                            _totalRow(context, 'Total paid',
                                Formatters.price(order.grandTotal),
                                bold: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          GoldButton(
                              label: 'Continue shopping',
                              onPressed: () => Get.toNamed(AppRoutes.shop)),
                          const SizedBox(width: AppSpacing.sm),
                          OutlinedButton(
                              onPressed: () => Get.toNamed(AppRoutes.account),
                              child: const Text('View orders')),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _totalRow(BuildContext context, String label, String value,
      {bool bold = false}) {
    final style = bold
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
