import 'dart:js_interop';

/// Web implementations built on `dart:js_interop`, which compiles under both
/// dart2js and dart2wasm (unlike the legacy `dart:html`).
///
/// Every call is guarded: `localStorage` throws outright in some privacy modes,
/// and that must never take down the cart.

String? readLocal(String key) {
  try {
    return _localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void writeLocal(String key, String value) {
  try {
    _localStorage.setItem(key, value);
  } catch (_) {
    // Storage full or blocked — persistence is best-effort.
  }
}

void removeLocal(String key) {
  try {
    _localStorage.removeItem(key);
  } catch (_) {
    // Ignored, as above.
  }
}

void replaceUrl(String url) {
  try {
    _history.replaceState(null, '', url);
  } catch (_) {
    // Cross-origin or sandboxed frame — the URL simply stays as it was.
  }
}

// ---- Minimal typed interop bindings (no package:web dependency) ----

@JS('localStorage')
external _Storage get _localStorage;

@JS('history')
external _History get _history;

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

extension type _History._(JSObject _) implements JSObject {
  external void replaceState(JSAny? data, String title, String url);
}
