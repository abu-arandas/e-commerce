import 'package:flutter_web_plugins/url_strategy.dart';

/// Removes the `#` from web URLs (path URL strategy).
void configureUrlStrategy() => usePathUrlStrategy();
