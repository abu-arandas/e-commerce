import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/bindings/initial_binding.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_constants.dart';
import 'core/utils/store_settings.dart';
import 'core/utils/supabase_service.dart';
import 'core/utils/url_strategy/url_strategy.dart';
import 'views/shared/startup_failure_view.dart';

Future<void> main() async {
  await (runZonedGuarded<Future<void>>(() async {
        WidgetsFlutterBinding.ensureInitialized();
        _configureFlutterErrors();

        // Clean, path-based URLs (no `#`) for deep-linkable product/variant
        // pages.
        configureUrlStrategy();

        var startupFailed = false;
        try {
          // Initialise Supabase if credentials were provided via --dart-define;
          // the app otherwise runs against in-memory demo data.
          await SupabaseService.init();
        } catch (error, stackTrace) {
          startupFailed = true;
          _reportUncaughtError(error, stackTrace);
        }

        if (!startupFailed) {
          // Shipping fee and free-shipping threshold are authoritative on the
          // server. StoreSettings.load keeps compile-time defaults on a
          // recoverable settings read failure.
          await StoreSettings.load();
        }

        runApp(VanguardApp(startupFailed: startupFailed));
      }, _reportUncaughtError) ??
      Future<void>.value());
}

void _configureFlutterErrors() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _reportUncaughtError(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  ErrorWidget.builder = (details) {
    _reportUncaughtError(
      details.exception,
      details.stack ?? StackTrace.current,
    );
    return const ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This section could not be displayed. Please refresh and try again.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };
}

void _reportUncaughtError(Object error, StackTrace stackTrace) {
  // This is the single integration point for a production error reporter such
  // as Sentry. Logging remains useful in development and hosting diagnostics.
  debugPrint('Uncaught application error: $error');
  debugPrintStack(stackTrace: stackTrace);
}

class VanguardApp extends StatelessWidget {
  const VanguardApp({super.key, this.startupFailed = false});

  final bool startupFailed;

  @override
  Widget build(BuildContext context) {
    if (startupFailed) {
      return MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const StartupFailureView(),
      );
    }

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
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1)),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
