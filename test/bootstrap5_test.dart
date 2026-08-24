import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/core/utils/bootstrap5.dart';

/// The grid is a re-implementation of Bootstrap 5's, so its breakpoints and
/// `col-{bp}-{n}` cascade need to behave exactly as the CSS would (PRD §6.2).
void main() {
  group('breakpoint resolution', () {
    test('maps viewport widths to the PRD bands', () {
      expect(Fb5.breakpointOf(320), Fb5Breakpoint.xs);
      expect(Fb5.breakpointOf(575.9), Fb5Breakpoint.xs);
      expect(Fb5.breakpointOf(576), Fb5Breakpoint.sm);
      expect(Fb5.breakpointOf(768), Fb5Breakpoint.md);
      expect(Fb5.breakpointOf(992), Fb5Breakpoint.lg);
      expect(Fb5.breakpointOf(1200), Fb5Breakpoint.xl);
      expect(Fb5.breakpointOf(1400), Fb5Breakpoint.xxl);
      expect(Fb5.breakpointOf(4000), Fb5Breakpoint.xxl);
    });

    test('atLeast compares band order', () {
      expect(Fb5Breakpoint.lg.atLeast(Fb5Breakpoint.md), isTrue);
      expect(Fb5Breakpoint.lg.atLeast(Fb5Breakpoint.lg), isTrue);
      expect(Fb5Breakpoint.sm.atLeast(Fb5Breakpoint.lg), isFalse);
    });

    testWidgets('classifies device bands from the viewport', (tester) async {
      Future<void> at(double width, void Function(BuildContext) check) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 900)),
            child: Builder(
              builder: (context) {
                check(context);
                return const SizedBox();
              },
            ),
          ),
        );
      }

      await at(400, (c) {
        expect(Fb5.isMobile(c), isTrue);
        expect(Fb5.isTablet(c), isFalse);
        expect(Fb5.isDesktop(c), isFalse);
        expect(c.isMobile, isTrue); // extension mirrors the static helper
      });
      await at(800, (c) {
        expect(Fb5.isMobile(c), isFalse);
        expect(Fb5.isTablet(c), isTrue);
        expect(c.breakpoint, Fb5Breakpoint.md);
      });
      await at(1300, (c) {
        expect(Fb5.isDesktop(c), isTrue);
        expect(c.isDesktop, isTrue);
      });
    });
  });

  group('responsive value cascade', () {
    /// Bootstrap's mobile-first rule: a value set at a band applies to that
    /// band and every larger one until something overrides it.
    testWidgets('resolves the nearest declared value at or below the band', (
      tester,
    ) async {
      Future<String> resolveAt(double width) async {
        late String resolved;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 900)),
            child: Builder(
              builder: (context) {
                resolved = Fb5.value<String>(
                  context,
                  xs: 'xs',
                  md: 'md',
                  xl: 'xl',
                );
                return const SizedBox();
              },
            ),
          ),
        );
        return resolved;
      }

      expect(await resolveAt(400), 'xs');
      expect(await resolveAt(600), 'xs'); // sm undeclared -> inherits xs
      expect(await resolveAt(800), 'md');
      expect(await resolveAt(1000), 'md'); // lg undeclared -> inherits md
      expect(await resolveAt(1250), 'xl');
      expect(await resolveAt(1500), 'xl'); // xxl undeclared -> inherits xl
    });
  });

  group('column spans', () {
    const col = FB5Col(
      classNames: 'col-12 col-md-6 col-lg-4 col-xl-3',
      child: SizedBox(),
    );

    test('resolves the span declared at each band', () {
      expect(col.resolveSpan(Fb5Breakpoint.xs), 12);
      expect(col.resolveSpan(Fb5Breakpoint.md), 6);
      expect(col.resolveSpan(Fb5Breakpoint.lg), 4);
      expect(col.resolveSpan(Fb5Breakpoint.xl), 3);
    });

    test('cascades upward from the nearest declared band', () {
      // sm has no declaration, so it inherits xs; xxl inherits xl.
      expect(col.resolveSpan(Fb5Breakpoint.sm), 12);
      expect(col.resolveSpan(Fb5Breakpoint.xxl), 3);
    });

    test('defaults to full width when nothing is declared', () {
      const bare = FB5Col(child: SizedBox());
      expect(bare.resolveSpan(Fb5Breakpoint.lg), 12);
    });

    test('explicit parameters win over class names', () {
      const explicit = FB5Col(classNames: 'col-md-6', md: 4, child: SizedBox());
      expect(explicit.resolveSpan(Fb5Breakpoint.md), 4);
    });

    test('ignores out-of-range spans', () {
      const bogus = FB5Col(classNames: 'col-99 col-md-0', child: SizedBox());
      expect(bogus.resolveSpan(Fb5Breakpoint.md), 12);
    });

    test('parses offsets independently of spans', () {
      const offset = FB5Col(classNames: 'col-6 offset-md-3', child: SizedBox());
      expect(offset.resolveOffset(Fb5Breakpoint.md), 3);
      expect(offset.resolveOffset(Fb5Breakpoint.xs), 0);
      expect(offset.resolveSpan(Fb5Breakpoint.md), 6);
    });
  });

  group('layout', () {
    /// Renders a row at a given viewport width and reports each column's width.
    Future<List<double>> widthsAt(WidgetTester tester, double viewport) async {
      tester.view.physicalSize = Size(viewport, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(viewport, 900)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: FB5Row(
              classNames: 'gx-0 gy-0',
              children: [
                for (var i = 0; i < 4; i++)
                  FB5Col(
                    classNames: 'col-12 col-md-6 col-lg-4 col-xl-3',
                    child: SizedBox(height: 10, key: ValueKey('c$i')),
                  ),
              ],
            ),
          ),
        ),
      );

      return [
        for (var i = 0; i < 4; i++)
          tester.getSize(find.byKey(ValueKey('c$i'))).width,
      ];
    }

    testWidgets('stacks to one column on xs', (tester) async {
      final widths = await widthsAt(tester, 400);
      for (final w in widths) {
        expect(w, closeTo(400, 1));
      }
    });

    testWidgets('is two columns at md', (tester) async {
      final widths = await widthsAt(tester, 800);
      for (final w in widths) {
        expect(w, closeTo(400, 1));
      }
    });

    testWidgets('is three columns at lg', (tester) async {
      final widths = await widthsAt(tester, 1000);
      for (final w in widths) {
        expect(w, closeTo(1000 / 3, 1));
      }
    });

    testWidgets('is four columns at xl', (tester) async {
      final widths = await widthsAt(tester, 1280);
      for (final w in widths) {
        expect(w, closeTo(320, 1));
      }
    });
  });
}
