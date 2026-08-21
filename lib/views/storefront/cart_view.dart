import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/cart_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/bootstrap5.dart';
import '../../core/utils/env.dart';
import '../../core/utils/formatters.dart';
import '../../models/cart_item_model.dart';
import '../shared/storefront_scaffold.dart';
import '../shared/ui_kit.dart';

class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return StorefrontScaffold(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.md),
        child: FB5Container(
          child: Obx(() {
            if (cart.isEmpty) {
              return EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Your bag is empty',
                message: 'Discover the collection and add your favourites.',
                action: GoldButton(label: 'Shop now', onPressed: () => Get.toNamed(AppRoutes.shop)),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(eyebrow: 'Your selection', title: 'Shopping bag'),
                const SizedBox(height: AppSpacing.lg),
                FB5Row(
                  classNames: 'gx-5 gy-4',
                  children: [
                    FB5Col(
                      classNames: 'col-12 col-lg-8',
                      child: Column(
                        children: [
                          for (final line in cart.items)
                            _CartLine(line: line, cart: cart),
                        ],
                      ),
                    ),
                    FB5Col(
                      classNames: 'col-12 col-lg-4',
                      child: _OrderSummary(cart: cart, showCheckout: true),
                    ),
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

class _CartLine extends StatelessWidget {
  const _CartLine({required this.line, required this.cart});
  final CartItem line;
  final CartController cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(AppSpacing.rMd),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(AppSpacing.rSm),
            child: SizedBox(width: 84, height: 108, child: VfImage(url: line.imageUrl)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(line.productTitle, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => cart.removeItem(line.key),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
                Text('${line.colorName} · Size ${line.sizeLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate)),
                Text(line.sku, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.mist)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    QuantityStepper(
                      value: line.quantity,
                      max: line.maxStock,
                      onDecrement: () => cart.decrement(line.key),
                      onIncrement: () => cart.increment(line.key),
                    ),
                    const Spacer(),
                    Text(Formatters.price(line.lineTotal),
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reactive order summary with promo code entry — reused on cart and checkout.
class _OrderSummary extends StatefulWidget {
  const _OrderSummary({required this.cart, this.showCheckout = false});
  final CartController cart;
  final bool showCheckout;

  @override
  State<_OrderSummary> createState() => _OrderSummaryState();
}

class _OrderSummaryState extends State<_OrderSummary> {
  final TextEditingController _promo = TextEditingController();

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(AppSpacing.rMd),
        border: Border.all(color: AppColors.line),
      ),
      child: Obx(() {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order summary', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),

            // Free-shipping progress.
            if (cart.amountToFreeShipping > 0) ...[
              Text('Add ${Formatters.price(cart.amountToFreeShipping)} for free shipping',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.goldDeep)),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (cart.subtotal / Env.freeShippingThreshold).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceAlt,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            _row(context, 'Subtotal', Formatters.price(cart.subtotal)),
            if (cart.discount > 0)
              _row(context, 'Discount${cart.appliedCode.value != null ? ' (${cart.appliedCode.value})' : ''}',
                  '-${Formatters.price(cart.discount)}', highlight: true),
            _row(context, 'Shipping', cart.shipping == 0 ? 'Free' : Formatters.price(cart.shipping)),
            const Divider(height: AppSpacing.lg),
            _row(context, 'Total', Formatters.price(cart.grandTotal), bold: true),
            const SizedBox(height: AppSpacing.md),

            // Promo code.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promo,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'Promo code', isDense: true),
                    onSubmitted: (v) => cart.applyPromo(v),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                OutlinedButton(
                  onPressed: cart.isApplyingPromo.value ? null : () => cart.applyPromo(_promo.text),
                  child: cart.isApplyingPromo.value
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Apply'),
                ),
              ],
            ),
            if (cart.appliedPromo.value?.valid == true)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(cart.appliedPromo.value?.description ?? 'Promo applied',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.success)),
                    ),
                    InkWell(
                      onTap: cart.clearPromo,
                      child: Text('Remove',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.slate)),
                    ),
                  ],
                ),
              )
            else if (cart.promoError.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(cart.promoError.value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
              ),

            if (widget.showCheckout) ...[
              const SizedBox(height: AppSpacing.lg),
              GoldButton(
                label: 'Proceed to checkout',
                expand: true,
                onPressed: () => Get.toNamed(AppRoutes.checkout),
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: TextButton(
                  onPressed: () => Get.toNamed(AppRoutes.shop),
                  child: const Text('Continue shopping'),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false, bool highlight = false}) {
    final style = bold
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: highlight ? AppColors.success : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

/// Public wrapper so checkout can reuse the same summary panel.
class OrderSummaryPanel extends StatelessWidget {
  const OrderSummaryPanel({super.key, required this.cart, this.showCheckout = false});
  final CartController cart;
  final bool showCheckout;

  @override
  Widget build(BuildContext context) => _OrderSummary(cart: cart, showCheckout: showCheckout);
}
