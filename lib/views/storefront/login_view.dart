import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/bootstrap5.dart';
import '../../core/utils/supabase_service.dart';
import '../../models/user_model.dart';
import '../shared/storefront_scaffold.dart';
import '../shared/ui_kit.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _isSignUp = false;

  final AuthController auth = Get.find<AuthController>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = _isSignUp
        ? await auth.signUp(_email.text.trim(), _password.text,
            fullName: _name.text.trim())
        : await auth.signIn(_email.text.trim(), _password.text);
    if (ok) {
      Get.offNamed(auth.isStaff ? AppRoutes.adminDashboard : AppRoutes.account);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StorefrontScaffold(
      showFooter: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xxl, horizontal: AppSpacing.md),
        constraints: const BoxConstraints(minHeight: 560),
        child: FB5Container(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.all(AppSpacing.rLg),
                border: Border.all(color: AppColors.line),
                boxShadow: AppShadows.card,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeading(
                      eyebrow: 'Vanguard',
                      title: _isSignUp ? 'Create account' : 'Welcome back',
                      align: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _name,
                        decoration:
                            const InputDecoration(labelText: 'Full name'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v ?? '').contains('@')
                          ? null
                          : 'Enter a valid email',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) =>
                          (v ?? '').length < 6 ? 'Minimum 6 characters' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Obx(() {
                      if (auth.error.value.isEmpty)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(auth.error.value,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.danger)),
                      );
                    }),
                    Obx(() => GoldButton(
                          label: _isSignUp ? 'Create account' : 'Sign in',
                          expand: true,
                          loading: auth.isLoading.value,
                          onPressed: _submit,
                        )),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(_isSignUp
                          ? 'Have an account? Sign in'
                          : "New here? Create an account"),
                    ),
                    if (!SupabaseService.isReady) ...[
                      const Divider(height: AppSpacing.xl),
                      Text('Explore back-office (demo)',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _demoChip('Catalog', AppRole.catalogManager),
                          _demoChip('Marketing', AppRole.marketingManager),
                          _demoChip('Fulfillment', AppRole.fulfillment),
                          _demoChip('Admin', AppRole.admin),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoChip(String label, AppRole role) => ActionChip(
        label: Text(label),
        avatar: const Icon(Icons.badge_outlined, size: 16),
        onPressed: () {
          auth.previewAs(role);
          Get.offNamed(AppRoutes.adminDashboard);
        },
      );
}
