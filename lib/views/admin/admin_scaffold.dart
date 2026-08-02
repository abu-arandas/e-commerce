import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/bootstrap5.dart';

class AdminNavItem {
  const AdminNavItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

const _adminNav = [
  AdminNavItem('Dashboard', Icons.insights_outlined, AppRoutes.adminDashboard),
  AdminNavItem('Products', Icons.checkroom_outlined, AppRoutes.adminProducts),
  AdminNavItem('Promotions', Icons.sell_outlined, AppRoutes.adminPromotions),
  AdminNavItem('Orders', Icons.receipt_long_outlined, AppRoutes.adminOrders),
];

/// Ink-themed admin shell with a persistent nav rail on desktop and a drawer on
/// smaller viewports. Gates access to staff roles (PRD §2).
class AdminScaffold extends StatelessWidget {
  const AdminScaffold(
      {super.key, required this.title, required this.child, this.actions});

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return Theme(
      data: AppTheme.dark,
      child: Obx(() {
        if (!auth.isStaff) return const _AccessDenied();
        final desktop = context.isDesktop;
        return Scaffold(
          backgroundColor: AppColors.ink,
          drawer: desktop
              ? null
              : Drawer(
                  backgroundColor: AppColors.inkSoft,
                  child: _NavList(auth: auth)),
          appBar: desktop
              ? null
              : AppBar(
                  title: Text(title,
                      style: AppTypography.wordmark(
                          color: AppColors.textOnInk, size: 20)),
                ),
          body: Row(
            children: [
              if (desktop) SizedBox(width: 248, child: _NavList(auth: auth)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (desktop) _TopBar(title: title, actions: actions),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.actions});
  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A30))),
      ),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final current = Get.currentRoute;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.inkSoft,
        border: Border(right: BorderSide(color: Color(0xFF2A2A30))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Text('VANGUARD',
                      style: AppTypography.wordmark(
                          color: AppColors.textOnInk, size: 20)),
                  const SizedBox(width: 6),
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: AppColors.gold, shape: BoxShape.circle)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text('BACK OFFICE',
                  style: AppTypography.eyebrow(color: AppColors.slate)),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in _adminNav)
              _NavTile(
                  item: item,
                  active: current.startsWith(item.route) &&
                      (item.route != AppRoutes.adminDashboard ||
                          current == item.route)),
            const Spacer(),
            const Divider(color: Color(0xFF2A2A30)),
            Obx(() => ListTile(
                  leading: const Icon(Icons.person_outline,
                      color: AppColors.textMutedOnInk),
                  title: Text(auth.user.value?.displayName ?? 'Staff',
                      style: const TextStyle(color: AppColors.textOnInk)),
                  subtitle: Text(auth.role.label,
                      style: const TextStyle(
                          color: AppColors.textMutedOnInk, fontSize: 11)),
                )),
            ListTile(
              leading: const Icon(Icons.storefront_outlined,
                  color: AppColors.textMutedOnInk),
              title: const Text('View storefront',
                  style: TextStyle(color: AppColors.textMutedOnInk)),
              onTap: () => Get.toNamed(AppRoutes.home),
            ),
            ListTile(
              leading:
                  const Icon(Icons.logout, color: AppColors.textMutedOnInk),
              title: const Text('Sign out',
                  style: TextStyle(color: AppColors.textMutedOnInk)),
              onTap: () async {
                await auth.signOut();
                Get.offAllNamed(AppRoutes.home);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.active});
  final AdminNavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: Material(
        color: active ? AppColors.ink : Colors.transparent,
        borderRadius: const BorderRadius.all(AppSpacing.rSm),
        child: ListTile(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(AppSpacing.rSm)),
          leading: Icon(item.icon,
              color: active ? AppColors.gold : AppColors.textMutedOnInk,
              size: 20),
          title: Text(item.label,
              style: TextStyle(
                  color:
                      active ? AppColors.textOnInk : AppColors.textMutedOnInk,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          onTap: () {
            if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
              Navigator.of(context).maybePop();
            }
            if (Get.currentRoute != item.route) Get.toNamed(item.route);
          },
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.gold),
            const SizedBox(height: AppSpacing.md),
            Text('Staff access required',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            const Text('Sign in with a staff account to view the admin panel.',
                style: TextStyle(color: AppColors.textMutedOnInk)),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => Get.offNamed(AppRoutes.login),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.ink),
              child: const Text('Go to sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
