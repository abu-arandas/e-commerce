import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/core/utils/bootstrap5.dart';

/// The grid is a local reimplementation of Bootstrap 5, so the PRD's column
/// counts per breakpoint rest entirely on it. bootstrap5_test covers the
/// breakpoint maths; this renders real rows and measures what comes out.
void main() {
  /// Sets the real test surface. It defaults to 800x600, which silently clamps
  /// any wider layout — a row asked to fill 1200px would only ever get 800, so
  /// every breakpoint above md would measure as md. Reset is registered inside
  /// the test, since setSurfaceSize may only be called from within one.
  Future<void> surface(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  /// Lays out [classNames] columns at [width] and returns each column's width.
  Future<List<double>> widthsAt(
    WidgetTester tester,
    double width,
    String classNames, {
    int count = 4,
    String rowClasses = 'gx-0',
  }) async {
    await surface(tester, width);
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(size: Size(width, 900)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: width,
          child: FB5Row(
            classNames: rowClasses,
            children: [
              for (var i = 0; i < count; i++)
                FB5Col(
                  classNames: classNames,
                  child: SizedBox(key: ValueKey('c$i'), height: 10),
                ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return [
      for (var i = 0; i < count; i++)
        tester.getSize(find.byKey(ValueKey('c$i'))).width,
    ];
  }

  group('the PRD product-grid ladder', () {
    // col-12 col-md-6 col-lg-4 col-xl-3 — 1 / 2 / 3 / 4 columns.
    const productCol = 'col-12 col-md-6 col-lg-4 col-xl-3';

    testWidgets('xs and sm stack to a single column', (tester) async {
      for (final w in [420.0, 700.0]) {
        final widths = await widthsAt(tester, w, productCol);
        for (final cw in widths) {
          expect(cw, closeTo(w, 1), reason: 'full width at ${w}px');
        }
      }
    });

    testWidgets('md gives two columns', (tester) async {
      final widths = await widthsAt(tester, 800, productCol);
      for (final cw in widths) {
        expect(cw, closeTo(400, 1));
      }
    });

    testWidgets('lg gives three columns', (tester) async {
      final widths = await widthsAt(tester, 1000, productCol);
      for (final cw in widths) {
        expect(cw, closeTo(1000 / 3, 1));
      }
    });

    testWidgets('xl and xxl give four columns', (tester) async {
      for (final w in [1300.0, 1500.0]) {
        final widths = await widthsAt(tester, w, productCol);
        for (final cw in widths) {
          expect(cw, closeTo(w / 4, 1), reason: '4 columns at ${w}px');
        }
      }
    });
  });

  group('grid mechanics', () {
    testWidgets('the split product page is 7/5 at lg', (tester) async {
      await surface(tester, 1200);
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(size: Size(1200, 900)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 1200,
            child: FB5Row(
              classNames: 'gx-0',
              children: [
                FB5Col(
                    classNames: 'col-12 col-lg-7',
                    child: SizedBox(key: ValueKey('gallery'), height: 10)),
                FB5Col(
                    classNames: 'col-12 col-lg-5',
                    child: SizedBox(key: ValueKey('details'), height: 10)),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(const ValueKey('gallery'))).width,
          closeTo(1200 * 7 / 12, 1));
      expect(tester.getSize(find.byKey(const ValueKey('details'))).width,
          closeTo(1200 * 5 / 12, 1));
    });

    testWidgets('a span cascades up from the nearest defined band',
        (tester) async {
      // Only md is declared, so lg and xl inherit it rather than resetting.
      final atMd = await widthsAt(tester, 800, 'col-12 col-md-6');
      final atLg = await widthsAt(tester, 1000, 'col-12 col-md-6');
      expect(atMd.first, closeTo(400, 1));
      expect(atLg.first, closeTo(500, 1), reason: 'md-6 still applies at lg');
    });

    testWidgets('gutters narrow the column, not the row', (tester) async {
      final tight = await widthsAt(tester, 1200, 'col-12 col-lg-4',
          count: 3, rowClasses: 'gx-0');
      final spaced = await widthsAt(tester, 1200, 'col-12 col-lg-4',
          count: 3, rowClasses: 'gx-4');

      expect(tight.first, closeTo(400, 1));
      // gx-4 is 24px, split half either side of each column.
      expect(spaced.first, closeTo(400 - 24, 1));
    });

    testWidgets('an offset pushes the column across', (tester) async {
      await surface(tester, 1200);
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(size: Size(1200, 900)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 1200,
            child: FB5Row(
              classNames: 'gx-0',
              children: [
                FB5Col(
                    classNames: 'col-4 offset-4',
                    child: SizedBox(key: ValueKey('centred'), height: 10)),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final left = tester.getTopLeft(find.byKey(const ValueKey('centred'))).dx;
      expect(left, closeTo(400, 1), reason: 'offset-4 = 4/12 of 1200');
    });
  });
}
