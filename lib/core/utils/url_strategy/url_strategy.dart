import 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart'
    as impl;

/// Enables clean, path-based URLs on web (no `#`) so nested variants can be
/// deep-linked (PRD §6.3). No-op off-web.
void configureUrlStrategy() => impl.configureUrlStrategy();
