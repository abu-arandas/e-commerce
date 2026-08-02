import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/bindings/initial_binding.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_constants.dart';
import 'core/utils/supabase_service.dart';
import 'core/utils/url_strategy/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean, path-based URLs (no `#`) for deep-linkable product/variant pages.
  configureUrlStrategy();

  // Initialise Supabase if credentials were provided via --dart-define; the app
  // otherwise runs against in-memory demo data.
  await SupabaseService.init();

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
      // Media-query driven responsiveness (our Bootstrap 5 grid) works at any
      // window size; disable Flutter's default text scaling clamp for web.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.0)),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
