import 'seo_stub.dart' if (dart.library.js_interop) 'seo_web.dart' as impl;

/// Injects per-route SEO metadata into the host document so crawlers that
/// execute JS (and social scrapers) receive product-specific titles and
/// descriptions (PRD §6.3). No-op on non-web targets.
abstract final class SeoService {
  static void update({
    required String title,
    String? description,
    String? canonicalPath,
  }) =>
      impl.applySeo(
        title: title,
        description: description,
        canonicalPath: canonicalPath,
      );
}
