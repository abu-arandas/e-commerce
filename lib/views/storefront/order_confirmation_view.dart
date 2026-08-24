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
          vertical: AppSpacing.xxl,
          horizontal: AppSpacing.md,
        ),
        child: FB5Container(
          child: order == null
              ? EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No recent order',
                  message: 'Your order details are no longer available.',
                  action: GoldButton(
                    label: 'Back to shop',
                    onPressed: () => Get.toNamed(AppRoutes.shop),
                  ),
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
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thank you for your order',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.displaySmall,
                                ),
                                Text(
                                  'Order ${order.reference}',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: AppColors.slate),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (order.contactEmail != null)
                        Text(
                          'A confirmation has been sent to ${order.contactEmail}.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      _OrderProgressTracker(status: order.status),
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
                                        Text(
                                          line.productTitle,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        Text(
                                          '${line.variantSummary} · Qty ${line.quantity}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.slate,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    Formatters.price(line.lineTotal),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const Divider(),
                            ],
                            _totalRow(
                              context,
                              'Subtotal',
                              Formatters.price(order.subtotal),
                            ),
                            if (order.discountTotal > 0)
                              _totalRow(
                                context,
                                'Discount',
                                '-${Formatters.price(order.discountTotal)}',
                              ),
                            _totalRow(
                              context,
                              'Shipping',
                              order.shippingTotal == 0
                                  ? 'Free'
                                  : Formatters.price(order.shippingTotal),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _totalRow(
                              context,
                              'Total paid',
                              Formatters.price(order.grandTotal),
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          GoldButton(
                            label: 'Continue shopping',
                            onPressed: () => Get.toNamed(AppRoutes.shop),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Get.toNamed(AppRoutes.account),
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                            ),
                            label: const Text('View order history'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _totalRow(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
  }) {
    final style = bold
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Where an order sits on the four-step storefront timeline. `pending` and
/// `paid` both read as "placed" to a shopper; a cancelled or refunded order has
/// left the pipeline and shows no progress beyond placement.
///
/// Top-level so it can be asserted directly — the tracker used to hardcode 0,
/// which meant a delivered order still displayed "Order Placed".
int orderProgressStep(OrderStatus status) => switch (status) {
  OrderStatus.pending || OrderStatus.paid => 0,
  OrderStatus.processing => 1,
  OrderStatus.shipped => 2,
  OrderStatus.delivered => 3,
  OrderStatus.cancelled || OrderStatus.refunded => 0,
};

class _OrderProgressTracker extends StatelessWidget {
  const _OrderProgressTracker({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    const steps = ['Order Placed', 'Processing', 'Shipped', 'Delivered'];
    final activeStep = orderProgressStep(status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: const BorderRadius.all(AppSpacing.rSm),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: i <= activeStep
                      ? AppColors.gold
                      : AppColors.line,
                  child: Icon(
                    i <= activeStep ? Icons.check : Icons.circle,
                    size: 14,
                    color: i <= activeStep ? AppColors.ink : AppColors.slate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == activeStep
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: i <= activeStep ? AppColors.ink : AppColors.slate,
                  ),
                ),
              ],
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: i < activeStep ? AppColors.gold : AppColors.line,
                  margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
