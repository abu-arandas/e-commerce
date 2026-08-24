import 'dart:js_interop';

/// Web implementation of SEO metadata injection using `dart:js_interop`, which
/// is compatible with both dart2js and dart2wasm (unlike the legacy
/// `dart:html`). Sets the document title plus the `description`, `og:title`,
/// `og:description`, and canonical link elements.
void applySeo({
  required String title,
  String? description,
  String? canonicalPath,
}) {
  _document.title = title;

  _setMetaByName('description', description);
  _setMetaByProperty('og:title', title);
  _setMetaByProperty('og:description', description);

  if (canonicalPath != null) {
    _setCanonical(canonicalPath);
  }
}

void _setMetaByName(String name, String? content) {
  if (content == null || content.isEmpty) return;
  final el =
      _document.querySelector('meta[name="$name"]') ??
      _appendHead('meta', {'name': name});
  el?.setAttribute('content', content);
}

void _setMetaByProperty(String property, String? content) {
  if (content == null || content.isEmpty) return;
  final el =
      _document.querySelector('meta[property="$property"]') ??
      _appendHead('meta', {'property': property});
  el?.setAttribute('content', content);
}

void _setCanonical(String path) {
  final href = path.startsWith('http')
      ? path
      : '${_location.origin}${path.startsWith('/') ? '' : '/'}$path';
  final el =
      _document.querySelector('link[rel="canonical"]') ??
      _appendHead('link', {'rel': 'canonical'});
  el?.setAttribute('href', href);
}

_Element? _appendHead(String tag, Map<String, String> attrs) {
  final el = _document.createElement(tag);
  attrs.forEach((key, value) => el.setAttribute(key, value));
  _document.head?.appendChild(el);
  return el;
}

// ---- Minimal typed interop bindings (no package:web dependency) ----

@JS('document')
external _Document get _document;

@JS('location')
external _Location get _location;

extension type _Document._(JSObject _) implements JSObject {
  external set title(String value);
  external _Element? querySelector(String selectors);
  external _Element createElement(String tag);
  external _Element? get head;
}

extension type _Element._(JSObject _) implements JSObject {
  external void setAttribute(String name, String value);
  external _Element appendChild(_Element node);
}

extension type _Location._(JSObject _) implements JSObject {
  external String get origin;
}
