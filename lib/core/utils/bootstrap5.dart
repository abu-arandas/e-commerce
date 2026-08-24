library;

import 'package:flutter/widgets.dart';

/// A faithful, Dart-3 / Wasm-compatible re-implementation of the Bootstrap 5
/// responsive grid (container / row / column) used throughout Vanguard Fashion.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Why this exists instead of the `flutter_bootstrap5` pub package
/// ─────────────────────────────────────────────────────────────────────────
/// The PRD names `flutter_bootstrap5`, but that package (v1.1.1) is pinned to
/// Dart `>=2.17 <3.0.0`, which is irreconcilable with `supabase_flutter` 2.x
/// and modern GetX (both require Dart 3) and with the PRD's Wasm-compilation
/// requirement (§6.1). Rather than ship a project that cannot even `pub get`,
/// the grid is implemented here with the same public API (`FB5Container`,
/// `FB5Row`, `FB5Col`), the same 12-column semantics, the same `col-{bp}-{n}`
/// className grammar, and the exact PRD breakpoints (§6.2).
///
/// Breakpoints (min viewport width, PRD §6.2):
///   xs < 576 · sm ≥ 576 · md ≥ 768 · lg ≥ 992 · xl ≥ 1200 · xxl ≥ 1400

/// The six Bootstrap breakpoints, ordered smallest → largest.
enum Fb5Breakpoint {
  xs(0),
  sm(576),
  md(768),
  lg(992),
  xl(1200),
  xxl(1400);

  const Fb5Breakpoint(this.minWidth);

  /// Inclusive lower bound of the breakpoint band, in logical pixels.
  final double minWidth;

  bool operator >=(Fb5Breakpoint other) => index >= other.index;
  bool operator <=(Fb5Breakpoint other) => index <= other.index;

  /// Whether this band is [other] or wider — the mobile-first "md and up"
  /// test, spelled without operator ambiguity.
  bool atLeast(Fb5Breakpoint other) => index >= other.index;
}

/// Static helpers for resolving breakpoints and responsive values.
abstract final class Fb5 {
  /// Max content widths per breakpoint for a (non-fluid) `.container`,
  /// mirroring Bootstrap's container sizes.
  static const Map<Fb5Breakpoint, double> containerMaxWidth = {
    Fb5Breakpoint.sm: 540,
    Fb5Breakpoint.md: 720,
    Fb5Breakpoint.lg: 960,
    Fb5Breakpoint.xl: 1140,
    Fb5Breakpoint.xxl: 1320,
  };

  /// The breakpoint band a given viewport [width] falls into.
  static Fb5Breakpoint breakpointOf(double width) {
    Fb5Breakpoint result = Fb5Breakpoint.xs;
    for (final bp in Fb5Breakpoint.values) {
      if (width >= bp.minWidth) result = bp;
    }
    return result;
  }

  /// The current viewport breakpoint (uses [MediaQuery], so it is viewport- not
  /// container-relative, matching CSS media-query semantics).
  static Fb5Breakpoint of(BuildContext context) =>
      breakpointOf(MediaQuery.sizeOf(context).width);

  /// Pick a value by breakpoint with Bootstrap's mobile-first cascade: a value
  /// set at a breakpoint applies to that band and every larger one until
  /// overridden. [xs] is the required base.
  static T value<T>(
    BuildContext context, {
    required T xs,
    T? sm,
    T? md,
    T? lg,
    T? xl,
    T? xxl,
  }) {
    final bp = of(context);
    final ladder = <Fb5Breakpoint, T?>{
      Fb5Breakpoint.xs: xs,
      Fb5Breakpoint.sm: sm,
      Fb5Breakpoint.md: md,
      Fb5Breakpoint.lg: lg,
      Fb5Breakpoint.xl: xl,
      Fb5Breakpoint.xxl: xxl,
    };
    T resolved = xs;
    for (final entry in ladder.entries) {
      if (entry.key.index <= bp.index && entry.value != null) {
        resolved = entry.value as T;
      }
    }
    return resolved;
  }

  static bool isMobile(BuildContext context) =>
      of(context).index < Fb5Breakpoint.md.index;
  static bool isTablet(BuildContext context) => of(context) == Fb5Breakpoint.md;
  static bool isDesktop(BuildContext context) =>
      of(context).index >= Fb5Breakpoint.lg.index;
}

/// Convenience extension mirroring `BootstrapTheme.of(context)` ergonomics.
extension Fb5ContextX on BuildContext {
  Fb5Breakpoint get breakpoint => Fb5.of(this);
  bool get isMobile => Fb5.isMobile(this);
  bool get isTablet => Fb5.isTablet(this);
  bool get isDesktop => Fb5.isDesktop(this);
}

// Gutter sizes for Bootstrap's `g-*` scale, in logical pixels.
const Map<int, double> _gutterScale = {0: 0, 1: 4, 2: 8, 3: 16, 4: 24, 5: 48};
const double _kDefaultGutter = 24; // Bootstrap default = 1.5rem

final RegExp _colRe = RegExp(r'\bcol-(?:(xs|sm|md|lg|xl|xxl)-)?(\d{1,2})\b');
final RegExp _offsetRe = RegExp(
  r'\boffset-(?:(xs|sm|md|lg|xl|xxl)-)?(\d{1,2})\b',
);
final RegExp _gutterRe = RegExp(r'\bg([xy]?)-(\d)\b');

Fb5Breakpoint _bpFromToken(String? token) {
  switch (token) {
    case 'sm':
      return Fb5Breakpoint.sm;
    case 'md':
      return Fb5Breakpoint.md;
    case 'lg':
      return Fb5Breakpoint.lg;
    case 'xl':
      return Fb5Breakpoint.xl;
    case 'xxl':
      return Fb5Breakpoint.xxl;
    default:
      return Fb5Breakpoint.xs;
  }
}

// Caches for the frequent string-parsing of classNames to improve performance.
final _spanCache = <String, Map<Fb5Breakpoint, int>>{};
final _offsetCache = <String, Map<Fb5Breakpoint, int>>{};

Map<Fb5Breakpoint, int> _parseSpans(String classNames, RegExp re) {
  final Map<String, Map<Fb5Breakpoint, int>>? cache = re == _colRe
      ? _spanCache
      : (re == _offsetRe ? _offsetCache : null);

  if (cache != null && cache.containsKey(classNames)) {
    return cache[classNames]!;
  }

  final result = <Fb5Breakpoint, int>{};
  for (final m in re.allMatches(classNames)) {
    final bp = _bpFromToken(m.group(1));
    final n = int.tryParse(m.group(2) ?? '');
    if (n != null && n >= 1 && n <= 12) result[bp] = n;
  }

  if (cache != null) {
    cache[classNames] = result;
  }

  return result;
}

/// A responsive column. Spans are given either through the [classNames] grammar
/// (`col-12 col-md-6 col-lg-4`) or the explicit [xs]/[sm].../[xxl] parameters,
/// which take precedence. Standalone it simply renders its [child]; inside an
/// [FB5Row] the row measures and sizes it.
class FB5Col extends StatelessWidget {
  const FB5Col({
    super.key,
    required this.child,
    this.classNames = '',
    this.xs,
    this.sm,
    this.md,
    this.lg,
    this.xl,
    this.xxl,
  });

  final Widget child;
  final String classNames;
  final int? xs, sm, md, lg, xl, xxl;

  Map<Fb5Breakpoint, int> get _spanMap {
    final map = _parseSpans(classNames, _colRe);
    void put(Fb5Breakpoint bp, int? v) {
      if (v != null && v >= 1 && v <= 12) map[bp] = v;
    }

    put(Fb5Breakpoint.xs, xs);
    put(Fb5Breakpoint.sm, sm);
    put(Fb5Breakpoint.md, md);
    put(Fb5Breakpoint.lg, lg);
    put(Fb5Breakpoint.xl, xl);
    put(Fb5Breakpoint.xxl, xxl);
    return map;
  }

  /// Column span (1–12) at [bp], cascading down from the nearest defined band.
  int resolveSpan(Fb5Breakpoint bp) {
    final map = _spanMap;
    for (var i = bp.index; i >= 0; i--) {
      final candidate = Fb5Breakpoint.values[i];
      if (map.containsKey(candidate)) return map[candidate]!;
    }
    return 12; // default: full width / stacked
  }

  /// Leading offset span at [bp], if any.
  int resolveOffset(Fb5Breakpoint bp) {
    final map = _parseSpans(classNames, _offsetRe);
    for (var i = bp.index; i >= 0; i--) {
      final candidate = Fb5Breakpoint.values[i];
      if (map.containsKey(candidate)) return map[candidate]!;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) => child;
}

/// A 12-column grid row. Lays out [FB5Col] children according to their resolved
/// spans/offsets at the current viewport breakpoint, wrapping to new lines when
/// spans exceed 12 (Bootstrap behaviour). Gutters follow the `g-*` / `gx-*` /
/// `gy-*` classes, defaulting to 24 px.
class FB5Row extends StatelessWidget {
  const FB5Row({
    super.key,
    required this.children,
    this.classNames = '',
    this.alignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
  });

  final List<Widget> children;
  final String classNames;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAxisAlignment;

  (double hGutter, double vGutter) _gutters() {
    double h = _kDefaultGutter, v = _kDefaultGutter;
    for (final m in _gutterRe.allMatches(classNames)) {
      final axis = m.group(1);
      final n = int.tryParse(m.group(2) ?? '');
      final px = _gutterScale[n];
      if (px == null) continue;
      if (axis == 'x') {
        h = px;
      } else if (axis == 'y') {
        v = px;
      } else {
        h = px;
        v = px;
      }
    }
    return (h, v);
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.breakpoint;
    final (hGutter, vGutter) = _gutters();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final unit = available / 12.0;

        final laidOut = <Widget>[];
        for (final child in children) {
          int span = 12;
          int offset = 0;
          if (child is FB5Col) {
            span = child.resolveSpan(bp);
            offset = child.resolveOffset(bp);
          }
          // Subtract a hair to avoid float rounding pushing a full 12-row onto
          // a second line.
          final width = (unit * span) - 0.01;

          if (offset > 0) {
            laidOut.add(SizedBox(width: unit * offset));
          }
          laidOut.add(
            SizedBox(
              width: width.clamp(0, available),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hGutter / 2),
                child: child,
              ),
            ),
          );
        }

        return Wrap(
          spacing: 0,
          runSpacing: vGutter,
          alignment: alignment,
          crossAxisAlignment: crossAxisAlignment,
          children: laidOut,
        );
      },
    );
  }
}

/// A responsive container. By default it centres content and caps its width per
/// breakpoint (Bootstrap `.container`); pass [fluid] for a full-bleed
/// `.container-fluid`. [padding] defaults to Bootstrap's 12 px side gutters.
class FB5Container extends StatelessWidget {
  const FB5Container({
    super.key,
    required this.child,
    this.fluid = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.alignment = Alignment.topCenter,
  });

  /// A full-bleed container (`.container-fluid`).
  const FB5Container.fluid({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.alignment = Alignment.topCenter,
  }) : fluid = true;

  final Widget child;
  final bool fluid;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final bp = context.breakpoint;
    final maxWidth = fluid
        ? double.infinity
        : (Fb5.containerMaxWidth[bp] ?? double.infinity);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Rebuilds when the viewport breakpoint changes — handy for swapping whole
/// layouts (e.g. hamburger vs. inline nav) rather than resizing columns.
class Fb5BreakpointBuilder extends StatelessWidget {
  const Fb5BreakpointBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, Fb5Breakpoint breakpoint) builder;

  @override
  Widget build(BuildContext context) => builder(context, context.breakpoint);
}
