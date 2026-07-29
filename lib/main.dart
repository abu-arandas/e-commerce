import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/bindings/initial_binding.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'core/utils/app_constants.dart';
import 'core/utils/store_settings.dart';
import 'core/utils/supabase_service.dart';
import 'core/utils/url_strategy/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean, path-based URLs (no `#`) for deep-linkable product/variant pages.
  configureUrlStrategy();

  // Initialise Supabase if credentials were provided via --dart-define; the app
  // otherwise runs against in-memory demo data.
  await SupabaseService.init();

  // Shipping fee / free-shipping threshold are owned by the backend so the
  // figures on screen match the ones `place_order` charges.
  await StoreSettings.load();

  runApp(const VanguardApp());
}

class VanguardApp extends StatelessWidget {
  const VanguardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.home,
      getPages: AppPages.routes,
      defaultTransition: Transition.fadeIn,
      // Our Bootstrap 5 grid handles layout at any window size; text gets a
      // gentle viewport-driven scale instead of the platform's own setting
      // (PRD §6.2 "adjust typography scaling").
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            AppTypography.scaleFor(MediaQuery.sizeOf(context).width),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
