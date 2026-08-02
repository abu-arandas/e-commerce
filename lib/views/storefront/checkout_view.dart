import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/bootstrap5.dart';
import '../shared/storefront_scaffold.dart';
import '../shared/ui_kit.dart';
import 'cart_view.dart';

class CheckoutView extends StatefulWidget {
  const CheckoutView({super.key});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _postal = TextEditingController();
  final _country = TextEditingController(text: 'United States');

  late final CartController cart = Get.find<CartController>();

  @override
  void initState() {
    super.initState();
    final auth = Get.find<AuthController>();
    if (auth.isLoggedIn) {
      _email.text = auth.user.value!.email;
      _name.text = auth.user.value!.fullName ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _email,
      _name,
      _line1,
      _line2,
      _city,
      _region,
      _postal,
      _country
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final order = await cart.placeOrder(
      contactEmail: _email.text.trim(),
      shippingAddress: {
        'full_name': _name.text.trim(),
        'line1': _line1.text.trim(),
        'line2': _line2.text.trim(),
        'city': _city.text.trim(),
        'region': _region.text.trim(),
        'postal_code': _postal.text.trim(),
        'country': _country.text.trim(),
      },
    );
    if (order != null) {
      Get.offNamed(AppRoutes.orderConfirmation, arguments: order);
    } else {
      Get.snackbar(
          'Checkout failed',
          cart.promoError.value.isNotEmpty
              ? cart.promoError.value
              : 'Please try again',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.danger,
          colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StorefrontScaffold(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xl, horizontal: AppSpacing.md),
        child: FB5Container(
          child: Obx(() {
            if (cart.isEmpty) {
              return EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Nothing to check out',
                message: 'Your bag is empty.',
                action: GoldButton(
                    label: 'Shop now',
                    onPressed: () => Get.toNamed(AppRoutes.shop)),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(
                    eyebrow: 'Almost yours', title: 'Checkout'),
                const SizedBox(height: AppSpacing.lg),
                FB5Row(
                  classNames: 'gx-5 gy-4',
                  children: [
                    FB5Col(
                        classNames: 'col-12 col-lg-7', child: _form(context)),
                    FB5Col(
                      classNames: 'col-12 col-lg-5',
                      child: Column(
                        children: [
                          OrderSummaryPanel(cart: cart),
                          const SizedBox(height: AppSpacing.md),
                          Obx(() => GoldButton(
                                label: 'Place order',
                                expand: true,
                                gold: true,
                                loading: cart.isPlacingOrder.value,
                                onPressed: _placeOrder,
                              )),
                          const SizedBox(height: AppSpacing.xs),
                          Text('Demo checkout — no payment is captured.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.mist)),
                        ],
                      ),
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

  Widget _form(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(AppSpacing.rMd),
        border: Border.all(color: AppColors.line),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _field(_email, 'Email address', required: true, email: true),
            const SizedBox(height: AppSpacing.lg),
            Text('Shipping address',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _field(_name, 'Full name', required: true),
            const SizedBox(height: AppSpacing.sm),
            _field(_line1, 'Address line 1', required: true),
            const SizedBox(height: AppSpacing.sm),
            _field(_line2, 'Address line 2 (optional)'),
            const SizedBox(height: AppSpacing.sm),
            FB5Row(
              classNames: 'gx-3 gy-3',
              children: [
                FB5Col(
                    classNames: 'col-12 col-sm-6',
                    child: _field(_city, 'City', required: true)),
                FB5Col(
                    classNames: 'col-6 col-sm-3',
                    child: _field(_region, 'State')),
                FB5Col(
                    classNames: 'col-6 col-sm-3',
                    child: _field(_postal, 'ZIP', required: true)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(_country, 'Country', required: true),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, bool email = false}) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      validator: (v) {
        final value = (v ?? '').trim();
        if (required && value.isEmpty) return 'Required';
        if (email && value.isNotEmpty && !value.contains('@'))
          return 'Enter a valid email';
        return null;
      },
    );
  }
}
