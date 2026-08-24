import 'browser_stub.dart'
    if (dart.library.js_interop) 'browser_web.dart'
    as impl;

/// Thin, platform-safe access to the couple of browser APIs the app needs:
/// `localStorage` (cart persistence across refreshes) and `history.replaceState`
/// (keeping the address bar in step with the selected colour variant).
///
/// No-ops off the web, so callers never need a platform check.
abstract final class Browser {
  /// Read a persisted string, or null when absent/unavailable.
  static String? read(String key) => impl.readLocal(key);

  /// Persist a string. Silently ignored when storage is unavailable (private
  /// browsing, blocked cookies, non-web platforms).
  static void write(String key, String value) => impl.writeLocal(key, value);

  static void remove(String key) => impl.removeLocal(key);

  /// Replace the current URL without pushing a history entry or rebuilding the
  /// route — used to reflect variant selection in a shareable link.
  static void replaceUrl(String url) => impl.replaceUrl(url);

  /// Reload the current page so startup initialization can be attempted again.
  /// No-op on non-web platforms.
  static void reload() => impl.reload();
}
