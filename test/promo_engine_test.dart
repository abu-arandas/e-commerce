import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/core/utils/demo_data.dart';
import 'package:vanguard_fashion/models/promotion_model.dart';

/// The demo-mode promotions engine must stay in lock-step with
/// `validate_promotion` in `supabase/migrations/0004_hardening.sql` — the same
/// basket has to produce the same discount in demo mode and against Postgres.
///
/// The figures asserted here are the ones the SQL tests assert too.
void main() {
  const knitwear = PromoLine(category: 'Knitwear', lineTotal: 245);
  const trousers = PromoLine(category: 'Trousers', lineTotal: 189);

  group('category targeting', () {
    test('discounts only the targeted lines, not the whole bag', () {
      // KNIT25 is 25% off Knitwear. Bag is 245 + 189 = 434.
      // 25% of the knitwear line is 61.25; 25% of the bag would be 108.50.
      final result = DemoData.validatePromo('KNIT25', [knitwear, trousers]);

      expect(result.valid, isTrue);
      expect(result.discountAmount, closeTo(61.25, 0.001));
    });

    test('an untargeted promotion still applies to the whole bag', () {
      final result = DemoData.validatePromo('FALL20', [knitwear, trousers]);

      expect(result.valid, isTrue);
      expect(result.discountAmount, closeTo(86.80, 0.001));
    });

    test('is rejected when the bag holds nothing eligible', () {
      final result = DemoData.validatePromo('KNIT25', [trousers]);

      expect(result.valid, isFalse);
      expect(result.reason, 'No eligible items in cart');
    });
  });

  group('eligibility rules', () {
    test('rejects an unknown code', () {
      expect(DemoData.validatePromo('NOPE', [knitwear]).valid, isFalse);
      expect(DemoData.validatePromo('NOPE', [knitwear]).reason, 'Code not found');
    });

    test('enforces the minimum order against the whole bag', () {
      final result = DemoData.validatePromo(
          'FALL20', const [PromoLine(category: 'Knitwear', lineTotal: 100)]);

      expect(result.valid, isFalse);
      expect(result.reason, contains('minimum order'));
    });

    test('matches codes case-insensitively', () {
      expect(DemoData.validatePromo('fall20', [knitwear, trousers]).valid, isTrue);
    });

    test('free shipping sets the flag rather than a discount', () {
      final result = DemoData.validatePromo('FREESHIP', [knitwear]);

      expect(result.valid, isTrue);
      expect(result.freeShipping, isTrue);
      expect(result.discountAmount, 0);
    });
  });

  group('discount arithmetic', () {
    test('a fixed amount never exceeds the eligible base', () {
      final result = DemoData.validatePromo(
          'WELCOME15', const [PromoLine(category: 'Knitwear', lineTotal: 80)]);

      expect(result.discountAmount, closeTo(15, 0.001));
      expect(result.discountAmount, lessThanOrEqualTo(80));
    });

    test('rounds to two decimal places', () {
      // 33.33% of nothing in particular — just check we never emit a long tail.
      final result = DemoData.validatePromo(
          'FALL20', const [PromoLine(category: 'Knitwear', lineTotal: 333.33)]);

      final cents = (result.discountAmount * 100).round();
      expect(result.discountAmount * 100, closeTo(cents, 0.0001));
    });

    test('discount never exceeds the bag', () {
      for (final code in ['FALL20', 'WELCOME15', 'KNIT25']) {
        final result = DemoData.validatePromo('FALL20', [knitwear, trousers]);
        if (result.valid) {
          expect(result.discountAmount, lessThanOrEqualTo(434),
              reason: 'code $code');
        }
      }
    });
  });
}
