import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/browser/browser.dart';

/// Rendered when a required service cannot be initialized before the storefront
/// starts. The screen deliberately avoids backend-dependent controllers so it
/// remains available during partial outages and invalid configuration.
class StartupFailureView extends StatelessWidget {
  const StartupFailureView({this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 56,
                    color: AppColors.goldDeep,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Store temporarily unavailable',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'We could not connect to the store services. Your cart is '
                    'safe on this device. Please retry in a moment.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.slate),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: onRetry ?? Browser.reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
