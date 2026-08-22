import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vanguard_fashion/controllers/catalog_controller.dart';
import 'package:vanguard_fashion/core/utils/demo_data.dart';
import 'package:vanguard_fashion/views/shared/variant_selector.dart';

/// The nested Colour -> Size selector is the centre of the product page:
/// choosing a colour has to swap in that colour's sizes, price and stock.
/// Everything else in the suite tests the controller behind it; these render it.
void main() {
  late CatalogController catalog;

  setUp(() async {
    Get.testMode = true;
    catalog = CatalogController();
    catalog.products.assignAll(DemoData.products());
    Get.put<CatalogController>(catalog);
    await catalog.loadProduct('cashmere-turtleneck');
  });

  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: VariantSelector(controller: catalog),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the selected colour and its sizes', (tester) async {
    await pump(tester);

    // Midnight Blue is first, and its sizes are S/M/L/XL.
    expect(find.text('Midnight Blue'), findsOneWidget);
    for (final size in ['S', 'M', 'L', 'XL']) {
      expect(find.text(size), findsOneWidget, reason: 'size $size');
    }
  });

  testWidgets('choosing a colour swaps in that colour\'s sizes', (tester) async {
    await pump(tester);

    // Oatmeal carries only M and L.
    final oatmeal = catalog.selected.value!.groupBySlug('oatmeal')!;
    catalog.selectGroup(oatmeal);
    await tester.pumpAndSettle();

    expect(find.text('Oatmeal'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('S'), findsNothing, reason: 'S belongs to another colour');
    expect(find.text('XL'), findsNothing);
  });

  testWidgets('tapping a size selects it', (tester) async {
    await pump(tester);

    await tester.tap(find.text('L'));
    await tester.pumpAndSettle();

    expect(catalog.selectedItem.value!.sizeLabel, 'L');
  });

  testWidgets('a sold-out size is struck through and not selectable',
      (tester) async {
    await pump(tester);

    // Midnight Blue XL is sold out in the demo catalogue.
    final xl = tester.widget<Text>(find.text('XL'));
    expect(xl.style?.decoration, TextDecoration.lineThrough);

    final before = catalog.selectedItem.value!.sizeLabel;
    await tester.tap(find.text('XL'));
    await tester.pumpAndSettle();

    expect(catalog.selectedItem.value!.sizeLabel, before,
        reason: 'tapping a sold-out size must not change the selection');
  });

  testWidgets('the stock badge follows the selected size', (tester) async {
    await pump(tester);

    // Midnight Blue L has 3 left, which is at or below the low-stock threshold.
    final large = catalog.availableSizes.firstWhere((i) => i.sizeLabel == 'L');
    catalog.selectSize(large);
    await tester.pumpAndSettle();

    expect(find.text('Only 3 left'), findsOneWidget);
  });
}
